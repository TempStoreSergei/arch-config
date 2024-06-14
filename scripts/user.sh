#!/bin/bash

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


# Function to setup autologin
setup_autologin() {
    info_msg "Setting up autologin for fsadmin..."
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    sudo cp getty@tty1.service.d/override.conf /etc/systemd/system/getty@tty1.service.d/override.conf

    info_msg "Enabling Sway to start on login..."
    sudo -u fsadmin cp bash_profile /home/fsadmin/.bash_profile
}
