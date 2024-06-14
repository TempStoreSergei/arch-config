#!/bin/bash

setup_cloak_server() {
    info_msg "Downloading Cloak server executable..."
    if ! wget https://github.com/cbeuw/Cloak/releases/download/v2.7.0/ck-server-linux-amd64-v2.7.0 -O ck-server; then
        error_msg "Failed to download Cloak server executable."
        exit 1
    fi

    info_msg "Making the file executable..."
    if ! chmod +x ck-server; then
        error_msg "Failed to make the file executable."
        exit 1
    fi

    info_msg "Moving the file to /usr/bin..."
    if ! sudo mv ck-server /usr/bin/ck-server; then
        error_msg "Failed to move the file to /usr/bin."
        exit 1
    fi

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
    sudo cp cloak-server.service /etc/systemd/system/cloak-server.service

    info_msg "Reloading systemd..."
    sudo systemctl daemon-reload || {
        error_msg "Failed to reload systemd."
        exit 1
    }
}

setup_openvpn_server() {
    info_msg "Setting up OpenVPN server..."

    # Ensure proper permissions for OpenVPN directories and files
    sudo mkdir -p /etc/openvpn/server
    sudo chmod 755 /etc/openvpn/server
    sudo mkdir -p /etc/openvpn/client
    sudo chmod 755 /etc/openvpn/client

    # Ensure proper permissions for log directory
    sudo mkdir -p /var/log/openvpn
    sudo chmod 755 /var/log/openvpn

    # Ensure proper permissions for runtime directory
    sudo mkdir -p /run/openvpn-server
    sudo chmod 755 /run/openvpn-server

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
    sudo cp openvpn-server.conf /etc/openvpn/server/server.conf

    info_msg "Creating client configuration file template..."
    sudo cp openvpn-client.conf /etc/openvpn/client/client.conf

    info_msg "Generating TLS key for extra security..."
    if ! sudo openvpn --genkey --secret /etc/openvpn/ta.key; then
        error_msg "Failed to generate TLS key."
        exit 1
    fi
    sudo chmod 600 /etc/openvpn/ta.key

    info_msg "Enabling IP forwarding..."
    echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward
    if [ ! -f /etc/sysctl.d/99-sysctl.conf ]; then
        info_msg "/etc/sysctl.d/99-sysctl.conf does not exist, creating it..."
        sudo tee /etc/sysctl.d/99-sysctl.conf > /dev/null <<EOF
# Kernel sysctl configuration file for Linux
net.ipv4.ip_forward=1
EOF
    else
        sudo sed -i '/^# Kernel sysctl configuration file for Linux$/a net.ipv4.ip_forward=1' /etc/sysctl.d/99-sysctl.conf
    fi
}