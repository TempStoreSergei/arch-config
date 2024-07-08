

# Directory and file paths
network_dir="/etc/systemd/network"
wlan_file="${network_dir}/wlan.network"
config_file="${network_dir}/wlan0.network"
config_source="conf/network.conf"

# Function to configure the network
configure_network() {
    # Ensure the network directory exists
    if [ ! -d "$network_dir" ]; then
        info_msg "Directory $network_dir does not exist. Creating it."
        mkdir -p "$network_dir"
        if [ $? -eq 0 ]; then
            success_msg "Successfully created $network_dir."
        else
            error_msg "Failed to create $network_dir."
            exit 1
        fi
    fi

    # Remove wlan.network if it exists
    if [ -f "$wlan_file" ]; then
        info_msg "File $wlan_file exists. Deleting it."
        rm "$wlan_file"
        if [ $? -eq 0 ]; then
            success_msg "Successfully deleted $wlan_file."
        else
            error_msg "Failed to delete $wlan_file."
            exit 1
        fi
    else
        info_msg "File $wlan_file does not exist. No need to delete."
    fi

    # Check if the configuration source file exists
    if [ ! -f "$config_source" ]; then
        error_msg "Configuration file $config_source does not exist. Exiting."
        exit 1
    fi

    # Create the wlan0.network file from the configuration source
    cat "$config_source" > "$config_file"

    if [ $? -eq 0 ]; then
        success_msg "Successfully created $config_file."
    else
        error_msg "Failed to create $config_file."
        exit 1
    fi
}
