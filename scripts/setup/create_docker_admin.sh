#!/bin/bash
# Script to create a docker-admin user on macOS
# This script should be run with sudo privileges

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
USERNAME="docker-admin"
FULLNAME="Docker Admin"
USER_ID=1001
GROUP_ID=80 # admin group
HOME_DIR="/Users/$USERNAME"
SHELL="/bin/bash"

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo privileges${NC}"
  exit 1
fi

echo -e "${YELLOW}Creating docker-admin user...${NC}"

# Check if user already exists
if dscl . -read /Users/$USERNAME &> /dev/null; then
  echo -e "${YELLOW}User $USERNAME already exists. Skipping user creation.${NC}"
else
  # Create the user
  echo -e "${GREEN}Creating user $USERNAME...${NC}"
  dscl . -create /Users/$USERNAME
  dscl . -create /Users/$USERNAME UserShell $SHELL
  dscl . -create /Users/$USERNAME RealName "$FULLNAME"
  dscl . -create /Users/$USERNAME UniqueID $USER_ID
  dscl . -create /Users/$USERNAME PrimaryGroupID $GROUP_ID
  dscl . -create /Users/$USERNAME NFSHomeDirectory $HOME_DIR
  
  # Generate a random password
  RANDOM_PASSWORD=$(openssl rand -base64 12)
  dscl . -passwd /Users/$USERNAME "$RANDOM_PASSWORD"
  
  # Add to admin group
  dscl . -append /Groups/admin GroupMembership $USERNAME
  
  # Create home directory
  mkdir -p $HOME_DIR
  chown -R $USERNAME:admin $HOME_DIR
  
  echo -e "${GREEN}User $USERNAME created successfully${NC}"
  echo -e "${YELLOW}Temporary password: $RANDOM_PASSWORD${NC}"
  echo -e "${YELLOW}Please change this password immediately after first login${NC}"
fi

# Set up SSH directory
echo -e "${GREEN}Setting up SSH directory...${NC}"
mkdir -p $HOME_DIR/.ssh
touch $HOME_DIR/.ssh/authorized_keys
chmod 700 $HOME_DIR/.ssh
chmod 600 $HOME_DIR/.ssh/authorized_keys
chown -R $USERNAME:admin $HOME_DIR/.ssh

# Prompt for SSH public keys
echo -e "${YELLOW}Please enter SSH public keys (one per line, press Ctrl+D when done):${NC}"
cat > $HOME_DIR/.ssh/authorized_keys
chown $USERNAME:admin $HOME_DIR/.ssh/authorized_keys

# Configure automatic login
echo -e "${YELLOW}Do you want to enable automatic login for $USERNAME? (y/n)${NC}"
read -r AUTO_LOGIN
if [[ $AUTO_LOGIN =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}Enabling automatic login for $USERNAME...${NC}"
  defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "$USERNAME"
  # Note: This requires additional steps to store the password securely
  # which is beyond the scope of this script
  echo -e "${YELLOW}Note: You'll need to complete the automatic login setup in System Preferences${NC}"
fi

# Configure Docker to start on boot
echo -e "${GREEN}Setting up Docker to start on boot...${NC}"
mkdir -p $HOME_DIR/Library/LaunchAgents
cat > $HOME_DIR/Library/LaunchAgents/com.docker.docker.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.docker.docker</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Docker.app/Contents/MacOS/Docker</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
chown $USERNAME:admin $HOME_DIR/Library/LaunchAgents/com.docker.docker.plist

echo -e "${GREEN}Docker-admin user setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Log in as $USERNAME and change the temporary password"
echo -e "2. Install Docker Desktop for Apple Silicon"
echo -e "3. Configure Docker resources and preferences"
echo -e "4. Test Docker functionality"

exit 0
