#!/bin/bash
# Script to create a docker-admin user on macOS with proper login window integration
# This script should be run with sudo privileges
# This version is fully SSH-friendly with no Ctrl+D requirements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configuration
USERNAME="docker-admin"
FULLNAME="Docker Admin"
USER_ID=501  # Using 501 or higher ensures visibility in login window
GROUP_ID=20  # staff group (standard for macOS users)
ADMIN_GROUP_ID=80  # admin group
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
  echo -e "${YELLOW}User $USERNAME already exists. Checking configuration...${NC}"
  
  # Ensure user has proper attributes for login window visibility
  dscl . -create /Users/$USERNAME IsHidden 0
  dscl . -create /Users/$USERNAME UserShell $SHELL
  
  # Ensure user is in admin group
  if ! dsmemberutil checkmembership -U "$USERNAME" -G admin &> /dev/null; then
    echo -e "${YELLOW}Adding $USERNAME to admin group...${NC}"
    dseditgroup -o edit -a "$USERNAME" -t user admin
  fi
else
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
  echo -e "${YELLOW}Please change this password immediately after first login${NC}"
fi

# Set up SSH directory
echo -e "${GREEN}Setting up SSH directory...${NC}"
mkdir -p $HOME_DIR/.ssh
touch $HOME_DIR/.ssh/authorized_keys
chmod 700 $HOME_DIR/.ssh
chmod 600 $HOME_DIR/.ssh/authorized_keys
chown -R $USERNAME:staff $HOME_DIR/.ssh

# SSH-friendly approach for adding SSH keys
echo -e "${YELLOW}Please enter SSH public keys (one per line, type 'DONE' when finished):${NC}"

> $HOME_DIR/.ssh/authorized_keys  # Clear the file first

while true; do
  read -r line
  if [[ "$line" == "DONE" ]]; then
    break
  fi
  if [[ -n "$line" ]]; then  # Only add non-empty lines
    echo "$line" >> $HOME_DIR/.ssh/authorized_keys
  fi
done

chown $USERNAME:staff $HOME_DIR/.ssh/authorized_keys
echo -e "${GREEN}SSH keys added successfully.${NC}"

# SSH-friendly approach for automatic login configuration
echo -e "${YELLOW}Do you want to enable automatic login for $USERNAME? (y/n)${NC}"
read -r AUTO_LOGIN

if [[ $AUTO_LOGIN =~ ^[Yy]$ ]]; then
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

# Ensure user appears in login window
echo -e "${GREEN}Ensuring user appears in login window...${NC}"
defaults write /Library/Preferences/com.apple.loginwindow HiddenUsersList -array
defaults write /Library/Preferences/com.apple.loginwindow SHOWOTHERUSERS_MANAGED -bool TRUE

# Rebuild directory services cache
echo -e "${GREEN}Rebuilding directory services cache...${NC}"
dscacheutil -flushcache

echo -e "${GREEN}Docker-admin user setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo -e "1. Log in as $USERNAME and change the temporary password"
echo -e "2. Install Docker Desktop for Apple Silicon"
echo -e "3. Configure Docker resources and preferences"
echo -e "4. Test Docker functionality"

exit 0
