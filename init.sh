#!/bin/bash

# Source the functions script
source functions.sh

# Update the system
info_msg "Updating the system..."
if ! sudo pacman -Syu --noconfirm; then
    error_msg "Failed to update the system"
    exit 1
fi

# List of necessary packages
packages=("sway" "seatd" "python-pip" "chromium" "openssh" "nginx" "nemo" "foot" "wl-clipboard" "wget")

# Install packages with progress
install_packages "${packages[@]}"

# Enable and start necessary services
enable_service "seatd"
enable_service "sshd"
enable_service "nginx"

# Check if user 'fsadmin' already exists, else create it
if id "fsadmin" &>/dev/null; then
    info_msg "User 'fsadmin' already exists."
else
    info_msg "Creating user 'fsadmin'..."
    if ! sudo useradd -m -G seat fsadmin || ! echo "fsadmin:admin" | sudo chpasswd; then
        error_msg "Failed to create user 'fsadmin'."
        exit 1
    fi
fi

# Add fsadmin to the seat group if not already added
if ! groups fsadmin | grep -q '\bseat\b'; then
    info_msg "Adding user 'fsadmin' to seat group..."
    if ! sudo usermod -aG seat fsadmin; then
        error_msg "Failed to add user 'fsadmin' to seat group."
        exit 1
    fi
else
    info_msg "User 'fsadmin' is already added to seat group."
fi

# Create a directory for Sway configuration
info_msg "Creating Sway configuration directory..."
if ! sudo -u fsadmin mkdir -p /home/fsadmin/.config/sway; then
    error_msg "Failed to create Sway configuration directory."
    exit 1
fi

# Copy the external Sway config file to the user's config directory
info_msg "Copying Sway config file..."
if ! sudo cp sway_config /home/fsadmin/.config/sway/config || ! sudo chown fsadmin:fsadmin /home/fsadmin/.config/sway/config; then
    error_msg "Failed to copy Sway config file."
    exit 1
fi

# Set up autologin for the user 'fsadmin'
info_msg "Setting up autologin for fsadmin..."
if ! sudo mkdir -p /etc/systemd/system/getty@tty1.service.d; then
    error_msg "Failed to create autologin configuration directory."
    exit 1
fi

echo "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin fsadmin --noclear %I \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null

# Enable Sway to start on login
info_msg "Enabling Sway to start on login..."
echo "if [ -z \"\$WAYLAND_DISPLAY\" ] && [ \"\$XDG_VTNR\" = 1 ]; then
    exec sway
fi" | sudo -u fsadmin tee /home/fsadmin/.bash_profile > /dev/null

# Download and configure Cloak
info_msg "Downloading and configuring Cloak..."
if ! chmod +x Cloak2-Installer.sh || ! sudo ./Cloak2-Installer.sh; then
    error_msg "Failed to configure Cloak."
    exit 1
fi

# Reboot system prompt
success_msg "Setup complete. Please reboot the system."
