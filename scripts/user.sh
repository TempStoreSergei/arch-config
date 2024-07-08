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

    # Ensure the target directory exists
    if ! sudo mkdir -p /etc/systemd/system/getty@tty1.service.d; then
        error_msg "Failed to create directory for autologin."
        exit 1
    fi

    # Replace placeholder in the template and copy it to the target location
    if ! sed "s/{USERNAME}/$USERNAME/g" conf/override.conf | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf > /dev/null; then
        error_msg "Failed to setup autologin."
        exit 1
    fi

    success_msg "Autologin setup for $USERNAME successfully."
}

copy_bash_profile() {
    local user_home
    user_home=$(eval echo "~$USERNAME")

    info_msg "Copying .bash_profile for $USERNAME..."

    if [ -z "$user_home" ] || [ ! -d "$user_home" ]; then
        error_msg "Home directory for $USERNAME not found."
        exit 1
    fi

    local source_bash_profile="conf/bash_profile.conf"
    local target_bash_profile="$user_home/.bash_profile"

    if ! sudo cp "$source_bash_profile" "$target_bash_profile"; then
        error_msg "Failed to copy .bash_profile for $USERNAME."
        exit 1
    fi

    success_msg ".bash_profile copied for $USERNAME successfully."
}