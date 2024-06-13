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

# Download Cloak server executable
info_msg "Downloading Cloak server executable..."
wget https://github.com/cbeuw/Cloak/releases/download/v2.7.0/ck-server-linux-amd64-v2.7.0 -O ck-server || {
    error_msg "Failed to download Cloak server executable."
    exit 1
}

# Make the file executable
info_msg "Making the file executable..."
chmod +x ck-server || {
    error_msg "Failed to make the file executable."
    exit 1
}

# Move the file to /usr/bin
info_msg "Moving the file to /usr/bin..."
sudo mv ck-server /usr/bin/ck-server || {
    error_msg "Failed to move the file to /usr/bin."
    exit 1
}

# Generate public and private keys
info_msg "Generating public and private keys..."
KEY_OUTPUT=$(/usr/bin/ck-server -key)
PUBLIC_KEY=$(echo "$KEY_OUTPUT" | grep "Your PUBLIC key is:" | awk '{print $5}')
PRIVATE_KEY=$(echo "$KEY_OUTPUT" | grep "Your PRIVATE key is:" | awk '{print $8}')
info_msg "Public Key: $PUBLIC_KEY"
info_msg "Private Key: $PRIVATE_KEY"

# Generate user and admin UIDs
info_msg "Generating user UID..."
USER_UID=$(/usr/bin/ck-server -uid | awk '{print $4}')
info_msg "User UID: $USER_UID"

info_msg "Generating admin UID..."
ADMIN_UID=$(/usr/bin/ck-server -uid | awk '{print $4}')
info_msg "Admin UID: $ADMIN_UID"

# Create configuration directory
info_msg "Creating configuration directory..."
sudo mkdir -p /etc/cloak || {
    error_msg "Failed to create configuration directory."
    exit 1
}

# Create the configuration file
info_msg "Creating the configuration file..."
sudo tee /etc/cloak/ckserver.json > /dev/null <<EOF
{
  "ProxyBook": {
    "openvpn": [
      "udp",
      "127.0.0.1:51000"
    ]
  },
  "BindAddr": [
    ":443",
    ":80"
  ],
  "BypassUID": [
    "$USER_UID"
  ],
  "RedirAddr": "dzen.ru",
  "PrivateKey": "$PRIVATE_KEY",
  "AdminUID": "$ADMIN_UID",
  "DatabasePath": "userinfo.db"
}
EOF

# Create systemd service file
info_msg "Creating systemd service file..."
sudo tee /etc/systemd/system/cloak-server.service > /dev/null <<EOF
[Unit]
Description=cloak-server
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Environment=CONFIG="/etc/cloak/ckserver.json"
ExecStart=/usr/bin/ck-server -c "\$CONFIG"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
info_msg "Reloading systemd, enabling and starting the Cloak service..."
sudo systemctl daemon-reload || {
    error_msg "Failed to reload systemd."
    exit 1
}

sudo systemctl enable cloak-server.service || {
    error_msg "Failed to enable Cloak service."
    exit 1
}

sudo systemctl start cloak-server.service || {
    error_msg "Failed to start Cloak service."
    exit 1
}

# Ensure ports 80 and 443 are open
info_msg "Ensuring ports 80 and 443 are open..."
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT

# Update OpenVPN configuration
info_msg "Updating OpenVPN configuration..."
sudo sed -i 's/^local .*/local 127.0.0.1/' /etc/openvpn/server.conf
sudo sed -i '/^dev tun/!s/^dev .*/dev tun/' /etc/openvpn/server.conf

# Reboot system prompt
success_msg "Setup complete. Please reboot the system."
