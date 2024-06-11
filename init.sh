#!/bin/bash

# Function to install packages with total progress
install_packages() {
    local packages=("$@")
    local total=${#packages[@]}
    local i=0

    # Iterate through each package and install it
    for package in "${packages[@]}"; do
        echo "Installing $package ($((i+1))/$total)..."
        sudo pacman -S --noconfirm $package
        i=$((i+1))
    done
}

# Update the system
echo "Updating the system..."
sudo pacman -Syu --noconfirm

# List of necessary packages
packages=("sway" "seatd" "python-pip" "chromium" "openssh" "nginx" "nemo")

# Install packages with progress
install_packages "${packages[@]}"

# Enable and start seatd service
echo "Enabling and starting seatd service..."
sudo systemctl enable seatd
sudo systemctl start seatd

# Enable and start SSH service
echo "Enabling and starting SSH service..."
sudo systemctl enable sshd
sudo systemctl start sshd

# Enable and start Nginx service
echo "Enabling and starting Nginx service..."
sudo systemctl enable nginx
sudo systemctl start nginx

# Create a new user 'fsadmin' with password 'admin'
echo "Creating user 'fsadmin'..."
sudo useradd -m -G seat fsadmin
echo "fsadmin:admin" | sudo chpasswd

# Create a directory for Sway configuration
echo "Creating Sway configuration directory..."
sudo -u fsadmin mkdir -p /home/fsadmin/.config/sway

# Copy the external Sway config file to the user's config directory
echo "Copying Sway config file..."
sudo cp sway_config /home/fsadmin/.config/sway/config
sudo chown fsadmin:fsadmin /home/fsadmin/.config/sway/config

# Set up autologin for the user 'fsadmin'
echo "Setting up autologin for fsadmin..."
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin fsadmin --noclear %I \$TERM
EOF

# Enable sway to start on login
echo "Enabling Sway to start on login..."
cat <<EOF | sudo -u fsadmin tee /home/fsadmin/.bash_profile
if [ -z "\$WAYLAND_DISPLAY" ] && [ "\$XDG_VTNR" = 1 ]; then
	exec sway
fi
EOF

echo "Setup complete. Please reboot the system."
