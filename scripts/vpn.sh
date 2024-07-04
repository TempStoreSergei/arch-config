#!/bin/bash

# Function to ensure proper permissions for directories
ensure_permissions() {
    local directories=("/etc/openvpn/server" "/etc/openvpn/client" "/var/log/openvpn" "/run/openvpn-server")

    for dir in "${directories[@]}"; do
        if ! sudo mkdir -p "$dir" &>/dev/null || ! sudo chmod 755 "$dir" &>/dev/null; then
            error_msg "Failed to set permissions for $dir."
            exit 1
        fi
    done
    success_msg "Permissions set successfully for OpenVPN directories."
}

# Function to initialize PKI and build CA
init_pki_and_ca() {
    info_msg "Initializing the PKI and building the CA..."
    cd /etc/easy-rsa || { error_msg "Failed to change directory."; exit 1; }
    sudo rm -rf /etc/easy-rsa/pki &>/dev/null
    if ! sudo easyrsa init-pki &>/dev/null; then
        error_msg "Failed to initialize PKI."
        exit 1
    fi
    echo -e "server\n" | sudo easyrsa build-ca nopass &>/dev/null || { error_msg "Failed to build CA."; exit 1; }
    success_msg "PKI initialized and CA built successfully."
}

# Function to generate server certificate and key
generate_server_cert() {
    info_msg "Generating server certificate and key..."
    if ! sudo easyrsa --batch gen-req server nopass &>/dev/null; then
        error_msg "Failed to generate server certificate and key."
        exit 1
    fi
    echo -e "yes\n" | sudo easyrsa --batch sign-req server server &>/dev/null || { error_msg "Failed to sign server certificate."; exit 1; }
    success_msg "Server certificate and key generated successfully."
}
# Function to generate Diffie-Hellman parameters
generate_dh_params() {
    info_msg "Generating Diffie-Hellman parameters..."
    if ! sudo easyrsa gen-dh &>/dev/null; then
        error_msg "Failed to generate Diffie-Hellman parameters."
        exit 1
    fi
    success_msg "Diffie-Hellman parameters generated successfully."
}

# Function to generate client certificate and key
generate_client_cert() {
    info_msg "Generating client certificate and key..."
    if ! sudo easyrsa --batch gen-req client nopass &>/dev/null; then
        error_msg "Failed to generate client certificate and key."
        exit 1
    fi
    echo -e "yes\n" | sudo easyrsa --batch sign-req client client &>/dev/null || { error_msg "Failed to sign client certificate."; exit 1; }
    success_msg "Client certificate and key generated successfully."
}

# Function to copy keys and certificates to OpenVPN directory
copy_keys_and_certs() {
    info_msg "Copying keys and certificates to OpenVPN directory..."
    local openvpn_dir="/etc/openvpn/server"
    if ! sudo cp pki/private/server.key "$openvpn_dir/" ||
       ! sudo cp pki/issued/server.crt "$openvpn_dir/" ||
       ! sudo cp pki/ca.crt "$openvpn_dir/" ||
       ! sudo cp pki/dh.pem "$openvpn_dir/" ||
       ! sudo cp pki/private/client.key "/etc/openvpn/client/" ||
       ! sudo cp pki/issued/client.crt "/etc/openvpn/client/" ||
       ! sudo cp pki/ca.crt "/etc/openvpn/client/"; then
        error_msg "Failed to copy keys and certificates."
        exit 1
    fi
    success_msg "Keys and certificates copied successfully."
}

# Function to create server configuration file
create_server_config() {
    cd - &>/dev/null
    info_msg "Creating server configuration file..."
    if ! sudo cp conf/openvpn-server.conf "/etc/openvpn/server/server.conf"; then
        error_msg "Failed to create server configuration file."
        exit 1
    fi
    success_msg "Server configuration file created successfully."
}

# Function to create client configuration file template
create_client_config_template() {
    info_msg "Creating client configuration file template..."
    if ! sudo cp conf/openvpn-client.conf "/etc/openvpn/client/client.conf"; then
        error_msg "Failed to create client configuration file template."
        exit 1
    fi
    success_msg "Client configuration file template created successfully."
}

# Function to generate TLS key for extra security
generate_tls_key() {
    info_msg "Generating TLS key for extra security..."
    if ! sudo openvpn --genkey --secret /etc/openvpn/ta.key &>/dev/null; then
        error_msg "Failed to generate TLS key."
        exit 1
    fi
    sudo chmod 600 /etc/openvpn/ta.key
    success_msg "TLS key generated successfully."
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
}

