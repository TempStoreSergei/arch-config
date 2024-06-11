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
        sudo pacman -S --noconfirm $package &>/dev/null || {
            error_msg "Failed to install $package"
            exit 1
        }
        i=$((i+1))
    done
}

# Update the system
info_msg "Updating the system..."
sudo pacman -Syu --noconfirm &>/dev/null || {
    error_msg "Failed to update the system"
    exit 1
}

# List of necessary packages
packages=("sway" "seatd" "python-pip" "chromium" "openssh" "nginx" "nemo" "foot" "wl-clipboard")

# Install packages with progress
install_packages "${packages[@]}"

# Install NetworkManager
if ! pacman -Q networkmanager &>/dev/null; then
    info_msg "Installing NetworkManager..."
    sudo pacman -S --noconfirm networkmanager &>/dev/null || {
        error_msg "Failed to install NetworkManager"
        exit 1
    }
fi

# Start NetworkManager service
info_msg "Starting NetworkManager service..."
sudo systemctl start NetworkManager &>/dev/null || {
    error_msg "Failed to start NetworkManager service"
    exit 1
}

# Enable NetworkManager service to start at boot
info_msg "Enabling NetworkManager service to start at boot..."
sudo systemctl enable NetworkManager &>/dev/null || {
    error_msg "Failed to enable NetworkManager service"
    exit 1
}

# Install dependencies for nm-tray
info_msg "Installing dependencies for nm-tray..."
sudo pacman -S --noconfirm base-devel git &>/dev/null || {
    error_msg "Failed to install dependencies for nm-tray"
    exit 1
}

# Clone nm-tray from AUR
info_msg "Cloning nm-tray from AUR..."
git clone https://aur.archlinux.org/nm-tray.git /tmp/nm-tray &>/dev/null || {
    error_msg "Failed to clone nm-tray from AUR"
    exit 1
}

# Build and install nm-tray
info_msg "Building and installing nm-tray..."
cd /tmp/nm-tray
makepkg -si --noconfirm &>/dev/null || {
    error_msg "Failed to build and install nm-tray"
    exit 1
}
cd ~
rm -rf /tmp/nm-tray

# Create a directory for Sway configuration if not exists
sudo -u fsadmin mkdir -p /home/fsadmin/.config/sway &>/dev/null

# Copy the external Sway config file to the user's config directory
info_msg "Copying Sway config file..."
sudo cp sway_config /home/fsadmin/.config/sway/config && sudo chown fsadmin:fsadmin /home/fsadmin/.config/sway/config &>/dev/null || {
    error_msg "Failed to copy Sway config file."
    exit 1
}

# Set up autologin for the user 'fsadmin'
info_msg "Setting up autologin for fsadmin..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d &>/dev/null || {
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

success_msg "Setup complete. Please reboot the system."
