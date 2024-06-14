
#!/bin/bash

setup_sway_config() {
    local config_dir="/home/fsadmin/.config/sway"
    local config_file="$config_dir/config"

    info_msg "Creating Sway configuration directory..."
    if ! sudo -u fsadmin mkdir -p "$config_dir"; then
        error_msg "Failed to create Sway configuration directory."
        exit 1
    fi
    success_msg "Sway configuration directory created successfully."

    info_msg "Copying Sway config file..."
    if ! sudo cp sway_config "$config_file" || ! sudo chown fsadmin:fsadmin "$config_file"; then
        error_msg "Failed to copy Sway config file."
        exit 1
    fi
    success_msg "Sway config file copied successfully."
}