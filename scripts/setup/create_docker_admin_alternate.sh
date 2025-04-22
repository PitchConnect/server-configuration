#!/bin/bash
# Alternate username docker-admin user creation script for macOS
# This script creates a docker administrator with a different username to avoid conflicts
# Usage: sudo ./create_docker_admin_alternate.sh [ssh_key_file]
# If ssh_key_file is not provided, no SSH key will be added

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration - using a different username to avoid conflicts
USERNAME="dockeradmin"  # Changed from docker-admin to dockeradmin (no hyphen)
FULLNAME="Docker Administrator"
USER_ID=502  # Using a different UID to avoid conflicts
GROUP_ID=20  # staff group (standard for macOS users)
ADMIN_GROUP_ID=80  # admin group
HOME_DIR="/Users/$USERNAME"
SHELL="/bin/bash"
ENABLE_AUTO_LOGIN=false  # Set to true to enable automatic login

# Check if script is run with sudo
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run this script with sudo privileges${NC}"
  exit 1
fi

# Check for SSH key file parameter
SSH_KEY_FILE=""
if [ $# -ge 1 ]; then
  SSH_KEY_FILE="$1"
  if [ ! -f "$SSH_KEY_FILE" ]; then
    echo -e "${RED}SSH key file not found: $SSH_KEY_FILE${NC}"
    exit 1
  fi
fi

echo -e "${GREEN}Starting alternate docker admin user setup...${NC}"

# Check if user already exists
if dscl . -read /Users/$USERNAME &> /dev/null; then
  echo -e "${YELLOW}User $USERNAME already exists. Attempting to remove...${NC}"
  
  # Kill any processes owned by the user
  echo -e "${YELLOW}Killing any processes owned by $USERNAME...${NC}"
  pkill -u $(id -u $USERNAME 2>/dev/null || echo "0") 2>/dev/null || true
  
  # Remove from all groups
  echo -e "${YELLOW}Removing $USERNAME from all groups...${NC}"
  for GROUP in $(dscl . -list /Groups | grep -v '^_'); do
    dseditgroup -o edit -d $USERNAME -t user $GROUP 2>/dev/null || true
  done
  
  # Backup home directory if it exists
  if [ -d "$HOME_DIR" ]; then
    BACKUP_DIR="${HOME_DIR}_backup_$(date +%Y%m%d%H%M%S)"
    echo -e "${YELLOW}Backing up home directory to $BACKUP_DIR...${NC}"
    mv "$HOME_DIR" "$BACKUP_DIR" 2>/dev/null || true
  fi
  
  # Delete the user
  echo -e "${YELLOW}Deleting user...${NC}"
  dscl . -delete /Users/$USERNAME 2>/dev/null || true
  
  # Check if user was successfully removed
  if dscl . -read /Users/$USERNAME &>/dev/null; then
    echo -e "${RED}Failed to remove existing user $USERNAME. Aborting.${NC}"
    exit 1
  else
    echo -e "${GREEN}User $USERNAME successfully removed.${NC}"
  fi
else
  echo -e "${GREEN}User $USERNAME does not exist. Proceeding with creation.${NC}"
fi

# Create the user with proper attributes
echo -e "${GREEN}Creating user $USERNAME...${NC}"

# Basic user attributes
dscl . -create /Users/$USERNAME
dscl . -create /Users/$USERNAME UserShell $SHELL
dscl . -create /Users/$USERNAME RealName "$FULLNAME"
dscl . -create /Users/$USERNAME UniqueID $USER_ID
dscl . -create /Users/$USERNAME PrimaryGroupID $GROUP_ID
dscl . -create /Users/$USERNAME NFSHomeDirectory $HOME_DIR

# Additional attributes for proper login window integration
dscl . -create /Users/$USERNAME IsHidden 0
dscl . -create /Users/$USERNAME Picture "/Library/User Pictures/Animals/Eagle.png"

# Authentication attributes
dscl . -create /Users/$USERNAME AuthenticationAuthority ";ShadowHash;HASHLIST:<SALTED-SHA512>"
dscl . -create /Users/$USERNAME PasswordPolicyOptions '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>failedLoginCount</key>
	<integer>0</integer>
	<key>failedLoginTimestamp</key>
	<date>2001-01-01T00:00:00Z</date>
	<key>lastLoginTimestamp</key>
	<date>2001-01-01T00:00:00Z</date>
	<key>newPasswordRequired</key>
	<false/>
</dict>
</plist>
'

# Generate a random password
RANDOM_PASSWORD=$(openssl rand -base64 12)
dscl . -passwd /Users/$USERNAME "$RANDOM_PASSWORD"

# Add to admin group
dseditgroup -o edit -a "$USERNAME" -t user admin

# Create home directory with proper template
mkdir -p "$HOME_DIR"

# Copy user template files
if [ -d "/System/Library/User Template/English.lproj" ]; then
  cp -R "/System/Library/User Template/English.lproj/"* "$HOME_DIR/"
fi

# Create login keychain
mkdir -p "$HOME_DIR/Library/Keychains"

# Set proper ownership
chown -R $USERNAME:staff "$HOME_DIR"

echo -e "${GREEN}User $USERNAME created successfully${NC}"
echo -e "${YELLOW}Temporary password: $RANDOM_PASSWORD${NC}"
echo -e "${YELLOW}Please save this password securely!${NC}"

# Set up SSH directory
echo -e "${GREEN}Setting up SSH directory...${NC}"
mkdir -p $HOME_DIR/.ssh
touch $HOME_DIR/.ssh/authorized_keys
chmod 700 $HOME_DIR/.ssh
chmod 600 $HOME_DIR/.ssh/authorized_keys
chown -R $USERNAME:staff $HOME_DIR/.ssh

# Add SSH key if provided
if [ -n "$SSH_KEY_FILE" ]; then
  echo -e "${GREEN}Adding SSH key from $SSH_KEY_FILE...${NC}"
  cat "$SSH_KEY_FILE" > $HOME_DIR/.ssh/authorized_keys
  chown $USERNAME:staff $HOME_DIR/.ssh/authorized_keys
  echo -e "${GREEN}SSH key added successfully.${NC}"
else
  echo -e "${YELLOW}No SSH key file provided. Skipping SSH key setup.${NC}"
fi

# Configure automatic login if enabled
if [ "$ENABLE_AUTO_LOGIN" = true ]; then
  echo -e "${GREEN}Enabling automatic login for $USERNAME...${NC}"
  defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser -string "$USERNAME"
  
  # Create the kcpassword file for automatic login
  if [ -n "$RANDOM_PASSWORD" ]; then
    # Convert password to kcpassword format (simplified version)
    KCPASSWORD=$(echo -n "$RANDOM_PASSWORD" | xxd -p | tr -d '\n')
    echo -e "${YELLOW}Setting up automatic login credentials...${NC}"
    # This is a simplified approach - in production you'd want a more secure method
    echo "$KCPASSWORD" | xxd -r -p > /etc/kcpassword
    chmod 600 /etc/kcpassword
  else
    echo -e "${YELLOW}Note: You'll need to complete the automatic login setup in System Preferences${NC}"
  fi
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
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF
chown $USERNAME:staff $HOME_DIR/Library/LaunchAgents/com.docker.docker.plist

# Ensure user appears in login window - critical fixes
echo -e "${GREEN}Applying critical fixes for login window visibility...${NC}"

# Remove from any hidden users list
defaults delete /Library/Preferences/com.apple.loginwindow HiddenUsersList 2>/dev/null || true
defaults write /Library/Preferences/com.apple.loginwindow HiddenUsersList -array

# Enable show all users option
defaults write /Library/Preferences/com.apple.loginwindow SHOWOTHERUSERS_MANAGED -bool TRUE

# Set login window type to list of users
defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool FALSE

# Rebuild directory services cache
echo -e "${GREEN}Rebuilding directory services cache...${NC}"
dscacheutil -flushcache

# Restart directory services
echo -e "${GREEN}Restarting directory services...${NC}"
killall opendirectoryd 2>/dev/null || true

echo -e "${GREEN}Docker admin user setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Log in as $USERNAME and change the temporary password"
echo -e "2. Install Docker Desktop for Apple Silicon"
echo -e "3. Configure Docker resources and preferences"
echo -e "4. Test Docker functionality"
echo -e "${GREEN}The user should now appear in the login window after reboot.${NC}"

exit 0
