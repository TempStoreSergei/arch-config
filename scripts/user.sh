#!/bin/bash

# Function to create user if it doesn't exist and add to the seat group
setup_user() {
    local username="fsadmin"
    
    if id "$username" &>/dev/null; then
        info_msg "User '$username' already exists."
    else
        info_msg "Creating user '$username'..."
        if ! sudo useradd -m -G seat "$username" || ! echo "$username:admin" | sudo chpasswd; then
            error_msg "Failed to create user '$username'."
            exit 1
        fi
        success_msg "User '$username' created successfully."
    fi

    if ! groups "$username" | grep -q '\bseat\b'; then
        info_msg "Adding user '$username' to seat group..."
        if ! sudo usermod -aG seat "$username"; then
            error_msg "Failed to add user '$username' to seat group."
            exit 1
        fi
        success_msg "User '$username' added to seat group successfully."
    else
        info_msg "User '$username' is already added to seat group."
    fi
}

# Function to setup autologin
setup_autologin() {
    local username="fsadmin"
    
    info_msg "Setting up autologin for $username..."
    if ! sudo mkdir -p /etc/systemd/system/getty@tty1.service.d ||
       ! sudo cp conf/override.conf /etc/systemd/system/getty@tty1.service.d/override.conf; then
        error_msg "Failed to setup autologin."
        exit 1
    fi
    success_msg "Autologin setup for $username successfully."

    info_msg "Enabling Sway to start on login..."
    if ! sudo -u "$username" cp conf/bash_profile.conf /home/"$username"/.bash_profile; then
        error_msg "Failed to enable Sway on login for $username."
        exit 1
    fi
    success_msg "Sway enabled on login for $username successfully."
}