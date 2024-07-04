#!/bin/bash

setup_user() {
    if id "$USERNAME" &>/dev/null; then
        info_msg "User '$USERNAME' already exists."
    else
        info_msg "Creating user '$USERNAME'..."
        if sudo useradd -m -s /bin/bash "$USERNAME"; then
            if echo "$USERNAME:$PASSWORD" | sudo chpasswd; then
                success_msg "User '$USERNAME' created successfully."
            else
                error_msg "Failed to set password for user '$USERNAME'."
                exit 1
            fi
        else
            error_msg "Failed to create user '$USERNAME'."
            exit 1
        fi
    fi
}

# Function to setup autologin
setup_autologin() {
    info_msg "Setting up autologin for $USERNAME..."
    if ! sudo mkdir -p /etc/systemd/system/getty@tty1.service.d ||
       ! sudo cp conf/override.conf /etc/systemd/system/getty@tty1.service.d/override.conf; then
        error_msg "Failed to setup autologin."
        exit 1
    fi
    success_msg "Autologin setup for $USERNAME successfully."
}