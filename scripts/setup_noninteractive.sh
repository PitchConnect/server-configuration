#!/bin/bash
# Non-interactive server setup script
# This version doesn't require any user input and is suitable for SSH sessions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}Starting server setup...${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker is not installed. Please install Docker Desktop for Mac first.${NC}"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop.${NC}"
    exit 1
fi

# Create required directories
echo -e "${YELLOW}Creating required directories...${NC}"
mkdir -p "$REPO_ROOT/traefik/data/acme"
mkdir -p "$REPO_ROOT/traefik/logs"

# Copy environment file if it doesn't exist
if [ ! -f "$REPO_ROOT/config/.env" ]; then
    echo -e "${YELLOW}Creating .env file from template...${NC}"
    cp "$REPO_ROOT/config/.env.example" "$REPO_ROOT/config/.env"
    echo -e "${YELLOW}Created .env file from template. You may want to edit it later at: $REPO_ROOT/config/.env${NC}"
    # No interactive prompt - continue automatically
else
    echo -e "${GREEN}.env file already exists.${NC}"
fi

# Source the environment file
set -a
source "$REPO_ROOT/config/.env"
set +a

# Create Docker network if it doesn't exist
if ! docker network inspect traefik-public &> /dev/null; then
    echo -e "${YELLOW}Creating traefik-public network...${NC}"
    docker network create traefik-public
else
    echo -e "${GREEN}traefik-public network already exists.${NC}"
fi

# Generate secure password for Traefik dashboard
if grep -q "change_this_password" "$REPO_ROOT/config/.env"; then
    echo -e "${YELLOW}Generating secure password for Traefik dashboard...${NC}"
    SECURE_PASSWORD=$(openssl rand -base64 12)
    HASHED_PASSWORD=$(docker run --rm httpd:alpine htpasswd -nbB admin "$SECURE_PASSWORD" | cut -d ":" -f 2)
    
    # Update .env file
    sed -i '' "s/DASHBOARD_PASSWORD=change_this_password/DASHBOARD_PASSWORD=$SECURE_PASSWORD/" "$REPO_ROOT/config/.env"
    
    # Update middleware.yml file
    ESCAPED_PASSWORD=$(echo "$HASHED_PASSWORD" | sed 's/\$/\\$/g')
    sed -i '' "s|admin:\$apr1\$ruca84Hq\$mbjdMZBAG.KWn7vfN/SNK/|admin:$ESCAPED_PASSWORD|" "$REPO_ROOT/traefik/config/dynamic/middleware.yml"
    
    echo -e "${GREEN}Generated password: $SECURE_PASSWORD${NC}"
    echo -e "${YELLOW}Please save this password securely!${NC}"
fi

# Update email in Traefik configuration
if grep -q "your-email@example.com" "$REPO_ROOT/traefik/config/traefik.yml"; then
    echo -e "${YELLOW}Updating email in Traefik configuration...${NC}"
    sed -i '' "s/your-email@example.com/$ACME_EMAIL/" "$REPO_ROOT/traefik/config/traefik.yml"
fi

# Start Traefik
echo -e "${YELLOW}Starting Traefik...${NC}"
cd "$REPO_ROOT" && docker-compose -f docker-compose/traefik.yml up -d

echo -e "${GREEN}Server setup complete!${NC}"
echo -e "${YELLOW}Traefik dashboard is available at: https://$TRAEFIK_DASHBOARD_HOST${NC}"
echo -e "${YELLOW}Username: admin${NC}"
echo -e "${YELLOW}Password: $DASHBOARD_PASSWORD${NC}"

exit 0
