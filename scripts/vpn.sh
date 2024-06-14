#!/bin/bash

# Function to ensure proper permissions for directories
ensure_permissions() {
    local directories=("/etc/openvpn/server" "/etc/openvpn/client" "/var/log/openvpn" "/run/openvpn-server")

    for dir in "${directories[@]}"; do
        if ! sudo mkdir -p "$dir" || ! sudo chmod 755 "$dir"; then
            error_msg "Failed to set permissions for $dir."
            exit 1
        fi
    done
    success_msg "Permissions set successfully for OpenVPN directories."
}

# Function to initialize PKI and build CA
init_pki_and_ca() {
    info_msg "Initializing the PKI and building the CA..."
    cd /etc/easy-rsa || exit 1
    sudo rm -rf /etc/easy-rsa/pki
    sudo easyrsa init-pki
    echo -e "yes\n" | sudo easyrsa build-ca nopass
    success_msg "PKI initialized and CA built successfully."
}

# Function to generate server certificate and key
generate_server_cert() {
    info_msg "Generating server certificate and key..."
    sudo easyrsa gen-req server nopass
    echo -e "yes\n" | sudo easyrsa sign-req server server
    success_msg "Server certificate and key generated successfully."
}

# Function to generate Diffie-Hellman parameters
generate_dh_params() {
    info_msg "Generating Diffie-Hellman parameters..."
    sudo easyrsa gen-dh
    success_msg "Diffie-Hellman parameters generated successfully."
}

# Function to generate client certificate and key
generate_client_cert() {
    info_msg "Generating client certificate and key..."
    sudo easyrsa gen-req client nopass
    echo -e "yes\n" | sudo easyrsa sign-req client client
    success_msg "Client certificate and key generated successfully."
}

# Function to copy keys and certificates to OpenVPN directory
copy_keys_and_certs() {
    info_msg "Copying keys and certificates to OpenVPN directory..."
    local openvpn_dir="/etc/openvpn/server"
    sudo cp pki/private/server.key "$openvpn_dir/"
    sudo cp pki/issued/server.crt "$openvpn_dir/"
    sudo cp pki/ca.crt "$openvpn_dir/"
    sudo cp pki/dh.pem "$openvpn_dir/"
    sudo cp pki/private/client.key "/etc/openvpn/client/"
    sudo cp pki/issued/client.crt "/etc/openvpn/client/"
    sudo cp pki/ca.crt "/etc/openvpn/client/"
    success_msg "Keys and certificates copied successfully."
}

# Function to create server configuration file
create_server_config() {
    info_msg "Creating server configuration file..."
    sudo cp conf/openvpn-server.conf "/etc/openvpn/server/server.conf"
    success_msg "Server configuration file created successfully."
}

# Function to create client configuration file template
create_client_config_template() {
    info_msg "Creating client configuration file template..."
    sudo cp conf/openvpn-client.conf "/etc/openvpn/client/client.conf"
    success_msg "Client configuration file template created successfully."
}

# Function to generate TLS key for extra security
generate_tls_key() {
    info_msg "Generating TLS key for extra security..."
    if ! sudo openvpn --genkey --secret /etc/openvpn/ta.key; then
        error_msg "Failed to generate TLS key."
        exit 1
    fi
    sudo chmod 600 /etc/openvpn/ta.key
    success_msg "TLS key generated successfully."
}

# Function to enable IP forwarding
enable_ip_forwarding() {
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
    success_msg "IP forwarding enabled successfully."
}

# Function to setup OpenVPN server
setup_openvpn_server() {
    ensure_permissions
    init_pki_and_ca
    generate_server_cert
    generate_dh_params
    generate_client_cert
    copy_keys_and_certs
    create_server_config
    create_client_config_template
    generate_tls_key
    enable_ip_forwarding
}
