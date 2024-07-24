#!/bin/bash

setup_sway_config() {
    # Define variables for configuration directory and file paths
    local config_dir_sway="/home/$USERNAME/.config/sway"
    local config_dir_waybar="/home/$USERNAME/.config/waybar"
    local config_file_sway="$config_dir_sway/config"
    local config_file_waybar="$config_dir_waybar/config"
    local user="$USERNAME"

    # Create Sway configuration directory
    # Use sudo to run the mkdir command as the specified user
    info_msg "Creating Sway configuration directory..."
    if ! sudo -u "$user" mkdir -p "$config_dir_sway"; then
        error_msg "Failed to create Sway configuration directory."
        exit 1
    fi
    success_msg "Sway configuration directory created successfully."

    # Create Sway configuration directory
    # Use sudo to run the mkdir command as the specified user
    info_msg "Creating Waybar configuration directory..."
    if ! sudo -u "$user" mkdir -p "$config_dir_waybar"; then
        error_msg "Failed to create Waybar configuration directory."
        exit 1
    fi
    success_msg "Waybar configuration directory created successfully."

    # Copy Sway configuration file to the new directory
    # Use sudo install to copy and set permissions in one step
    info_msg "Copying Sway config file..."
    if ! sudo install -o "$user" -g "$user" -m 644 conf/sway.conf "$config_file_sway"; then
        error_msg "Failed to copy Sway config file."
        exit 1
    fi
    success_msg "Sway config file copied successfully."

    # Copy Sway configuration file to the new directory
    # Use sudo install to copy and set permissions in one step
    info_msg "Copying Waybar config file..."
    if ! sudo install -o "$user" -g "$user" -m 644 conf/waybar.conf "$config_file_waybar"; then
        error_msg "Failed to copy Waybar config file."
        exit 1
    fi
    success_msg "Waybar config file copied successfully."
}