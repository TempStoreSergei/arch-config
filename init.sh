#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to display error messages in red
error_msg() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Function to display informational messages in yellow
info_msg() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to display success messages in green
success_msg() {
    echo -e "${GREEN}$1${NC}"
}

# Function to install packages with total progress
install_packages() {
    local packages=("$@")
    local total=${#packages[@]}
    local i=0

    # Iterate through each package and install it
    for package in "${packages[@]}"; do
        info_msg "Installing $package ($((i+1))/$total)..."
        sudo pacman -S --noconfirm $package || {
            error_msg "Failed to install $package"
            exit 1
        }
        i=$((i+1))
    done
}

# Update the system
info_msg "Updating the system..."
sudo pacman -Syu --noconfirm || {
    error_msg "Failed to update the system"
    exit 1
}

# List of necessary packages
packages=("sway" "seatd" "python-pip" "chromium" "openssh" "nginx" "nemo" "foot" "unclutter")

# Install packages with progress
install_packages "${packages[@]}"

# Check if seatd service is already enabled
if sudo systemctl is-enabled --quiet seatd; then
    info_msg "seatd service is already enabled."
else
    # Enable and start seatd service
    info_msg "Enabling and starting seatd service..."
    sudo systemctl enable seatd && sudo systemctl start seatd || {
        error_msg "Failed to enable/start seatd service."
        exit 1
    }
fi

# Check if sshd service is already enabled
if sudo systemctl is-enabled --quiet sshd; then
    info_msg "SSH service is already enabled."
else
    # Enable and start SSH service
    info_msg "Enabling and starting SSH service..."
    sudo systemctl enable sshd && sudo systemctl start sshd || {
        error_msg "Failed to enable/start SSH service."
        exit 1
    }
fi

# Check if nginx service is already enabled
if sudo systemctl is-enabled --quiet nginx; then
    info_msg "Nginx service is already enabled."
else
    # Enable and start Nginx service
    info_msg "Enabling and starting Nginx service..."
    sudo systemctl enable nginx && sudo systemctl start nginx || {
        error_msg "Failed to enable/start Nginx service."
        exit 1
    }
fi

# Check if user 'fsadmin' already exists
if id "fsadmin" &>/dev/null; then
    info_msg "User 'fsadmin' already exists."
else
    # Create a new user 'fsadmin' with password 'admin'
    info_msg "Creating user 'fsadmin'..."
    sudo useradd -m -G seat fsadmin && echo "fsadmin:admin" | sudo chpasswd || {
        error_msg "Failed to create user 'fsadmin'."
        exit 1
    }
fi

# Check if fsadmin is already added to seat group
if groups fsadmin | grep -q '\bseat\b'; then
    info_msg "User 'fsadmin' is already added to seat group."
else
    # Add fsadmin to the seat group
    info_msg "Adding user 'fsadmin' to seat group..."
    sudo usermod -aG seat fsadmin || {
        error_msg "Failed to add user 'fsadmin' to seat group."
        exit 1
    }
fi

# Create a directory for Sway configuration
info_msg "Creating Sway configuration directory..."
sudo -u fsadmin mkdir -p /home/fsadmin/.config/sway || {
    error_msg "Failed to create Sway configuration directory."
    exit 1
}

# Copy the external Sway config file to the user's config directory
info_msg "Copying Sway config file..."
sudo cp sway_config /home/fsadmin/.config/sway/config && sudo chown fsadmin:fsadmin /home/fsadmin/.config/sway/config || {
    error_msg "Failed to copy Sway config file."
    exit 1
}

# Set up autologin for the user 'fsadmin'
info_msg "Setting up autologin for fsadmin..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d || {
    error_msg "Failed to create autologin configuration directory."
    exit 1
}
echo "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin fsadmin --noclear %I \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null

# Enable Sway to start on login
info_msg "Enabling Sway to start on login..."
echo "if [ -z \"\$WAYLAND_DISPLAY\" ] && [ \"\$XDG_VTNR\" = 1 ]; then
    exec sway
fi" | sudo -u fsadmin tee /home/fsadmin/.bash_profile > /dev/null

# Configure unclutter to hide mouse cursor when inactive
info_msg "Configuring unclutter to hide mouse cursor..."
echo "exec_always --no-startup-id unclutter -idle 0.5" | sudo -u fsadmin tee -a /home/fsadmin/.config/sway/config > /dev/null

success_msg "Setup complete. Please reboot the system."
