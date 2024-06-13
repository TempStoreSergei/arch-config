#!/bin/bash

# Source the functions script
source functions.sh

# Function to update the system
update_system() {
    info_msg "Updating the system..."
    if ! sudo pacman -Syu --noconfirm; then
        error_msg "Failed to update the system"
        exit 1
    fi
}

# Function to install packages
install_packages() {
    local packages=("sway" "seatd" "python-pip" "chromium" "openssh" "nginx" "nemo" "foot" "wl-clipboard" "wget" "openvpn" "easy-rsa")
    for package in "${packages[@]}"; do
        if ! sudo pacman -S --noconfirm "$package"; then
            error_msg "Failed to install $package"
            exit 1
        fi
    done
}

# Function to enable and start services
enable_and_start_services() {
    local services=("seatd" "sshd" "nginx" "openvpn-server@server" "cloak-server")
    for service in "${services[@]}"; do
        if ! sudo systemctl enable "$service"; then
            error_msg "Failed to enable $service"
            exit 1
        fi
        if ! sudo systemctl start "$service"; then
            error_msg "Failed to start $service"
            exit 1
        fi
    done
}

# Function to create user if it doesn't exist and add to the seat group
setup_user() {
    if id "fsadmin" &>/dev/null; then
        info_msg "User 'fsadmin' already exists."
    else
        info_msg "Creating user 'fsadmin'..."
        if ! sudo useradd -m -G seat fsadmin || ! echo "fsadmin:admin" | sudo chpasswd; then
            error_msg "Failed to create user 'fsadmin'."
            exit 1
        fi
    fi

    if ! groups fsadmin | grep -q '\bseat\b'; then
        info_msg "Adding user 'fsadmin' to seat group..."
        if ! sudo usermod -aG seat fsadmin; then
            error_msg "Failed to add user 'fsadmin' to seat group."
            exit 1
        fi
    else
        info_msg "User 'fsadmin' is already added to seat group."
    fi
}

# Function to setup Sway configuration
setup_sway_config() {
    info_msg "Creating Sway configuration directory..."
    if ! sudo -u fsadmin mkdir -p /home/fsadmin/.config/sway; then
        error_msg "Failed to create Sway configuration directory."
        exit 1
    fi

    info_msg "Copying Sway config file..."
    if ! sudo cp sway_config /home/fsadmin/.config/sway/config || ! sudo chown fsadmin:fsadmin /home/fsadmin/.config/sway/config; then
        error_msg "Failed to copy Sway config file."
        exit 1
    fi
}

# Function to setup autologin
setup_autologin() {
    info_msg "Setting up autologin for fsadmin..."
    if ! sudo mkdir -p /etc/systemd/system/getty@tty1.service.d; then
        error_msg "Failed to create autologin configuration directory."
        exit 1
    fi

    echo "[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin fsadmin --noclear %I \$TERM" | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null

    info_msg "Enabling Sway to start on login..."
    echo "if [ -z \"\$WAYLAND_DISPLAY\" ] && [ \"\$XDG_VTNR\" = 1 ]; then
        exec sway
    fi" | sudo -u fsadmin tee /home/fsadmin/.bash_profile > /dev/null
}

# Function to download and setup Cloak server
setup_cloak_server() {
    info_msg "Downloading Cloak server executable..."
    if ! wget https://github.com/cbeuw/Cloak/releases/download/v2.7.0/ck-server-linux-amd64-v2.7.0 -O ck-server; then
        error_msg "Failed to download Cloak server executable."
        exit 1
    fi

    info_msg "Making the file executable..."
    chmod +x ck-server || {
        error_msg "Failed to make the file executable."
        exit 1
    }

    info_msg "Moving the file to /usr/bin..."
    sudo mv ck-server /usr/bin/ck-server || {
        error_msg "Failed to move the file to /usr/bin."
        exit 1
    }

    info_msg "Generating public and private keys..."
    local key_output
    key_output=$(/usr/bin/ck-server -key)
    local public_key private_key
    public_key=$(echo "$key_output" | grep "Your PUBLIC key is:" | awk '{print $5}')
    private_key=$(echo "$key_output" | grep "Your PRIVATE key is:" | awk '{print $8}')
    info_msg "Public Key: $public_key"
    info_msg "Private Key: $private_key"

    info_msg "Generating user and admin UIDs..."
    local user_uid admin_uid
    user_uid=$(/usr/bin/ck-server -uid | awk '{print $4}')
    admin_uid=$(/usr/bin/ck-server -uid | awk '{print $4}')
    info_msg "User UID: $user_uid"
    info_msg "Admin UID: $admin_uid"

    info_msg "Creating configuration directory..."
    if ! sudo mkdir -p /etc/cloak; then
        error_msg "Failed to create configuration directory."
        exit 1
    fi

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
    "$user_uid"
  ],
  "RedirAddr": "dzen.ru",
  "PrivateKey": "$private_key",
  "AdminUID": "$admin_uid",
  "DatabasePath": "userinfo.db"
}
EOF

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

    info_msg "Reloading systemd..."
    sudo systemctl daemon-reload || {
        error_msg "Failed to reload systemd."
        exit 1
    }
}

# Function to setup OpenVPN server
setup_openvpn_server() {
    info_msg "Setting up OpenVPN server..."
    
    # Fix permissions for OpenVPN files and directories
    sudo chown -R kiosk:kiosk /etc/openvpn/server
    sudo chmod -R 700 /etc/openvpn/server
    sudo chown -R kiosk:kiosk /etc/openvpn/client
    sudo chmod -R 700 /etc/openvpn/client
    sudo mkdir -p /var/log/openvpn
    sudo chown kiosk:kiosk /var/log/openvpn   # Change ownership to kiosk
    sudo chmod 777 /var/log/openvpn
    sudo mkdir -p /run/openvpn-server
    sudo chown kiosk:kiosk /run/openvpn-server 

    info_msg "Initializing the PKI and building the CA..."
    cd /etc/easy-rsa || exit 1
    sudo rm -rf /etc/easy-rsa/pki
    sudo easyrsa init-pki
    echo -e "yes\n" | sudo easyrsa build-ca nopass

    info_msg "Generating server certificate and key..."
    sudo easyrsa gen-req server nopass
    echo -e "yes\n" | sudo easyrsa sign-req server server

    info_msg "Generating Diffie-Hellman parameters..."
    sudo easyrsa gen-dh

    info_msg "Generating client certificate and key..."
    sudo easyrsa gen-req client nopass
    echo -e "yes\n" | sudo easyrsa sign-req client client

    info_msg "Copying keys and certificates to OpenVPN directory..."
    sudo cp pki/private/server.key /etc/openvpn/server/
    sudo cp pki/issued/server.crt /etc/openvpn/server/
    sudo cp pki/ca.crt /etc/openvpn/server/
    sudo cp pki/dh.pem /etc/openvpn/server/
    sudo cp pki/private/client.key /etc/openvpn/client/
    sudo cp pki/issued/client.crt /etc/openvpn/client/
    sudo cp pki/ca.crt /etc/openvpn/client/

    info_msg "Creating server configuration file..."
    sudo tee /etc/openvpn/server/server.conf > /dev/null <<EOF
port 1194
proto udp
dev tun
ca /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key /etc/openvpn/server/server.key
dh /etc/openvpn/server/dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth /etc/openvpn/ta.key 0
cipher AES-256-CBC
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3
EOF

    info_msg "Creating client configuration file template..."
    sudo tee /etc/openvpn/client/client.conf > /dev/null <<EOF
client
dev tun
proto udp
remote 127.0.0.1 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
ca ca.crt
cert client.crt
key client.key
tls-auth ta.key 1
cipher AES-256-CBC
verb 3
EOF

    info_msg "Generating TLS key for extra security..."
    sudo openvpn --genkey --secret /etc/openvpn/ta.key

    info_msg "Updating OpenVPN configuration..."
    sudo sed -i 's/^local .*/local 127.0.0.1/' /etc/openvpn/server/server.conf
    sudo sed -i '/^dev tun/!s/^dev .*/dev tun/' /etc/openvpn/server/server.conf
}

# Main script execution
update_system
install_packages
setup_user
setup_sway_config
setup_autologin
setup_cloak_server
setup_openvpn_server
enable_and_start_services

# Ensure ports 80 and 443 are open
info_msg "Ensuring ports 80 and 443 are open..."
sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT

# Reboot system prompt
success_msg "Setup complete. Please reboot the system."
