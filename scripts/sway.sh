#!/bin/bash

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