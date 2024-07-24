#!/bin/bash

# Function to install packages with total progress
install_packages() {
    local packages_file="$1"
    local packages=($(jq -r '.packages[]' "$packages_file"))
    local total=${#packages[@]}
    local installed_packages=()
    local i=0

    for package in "${packages[@]}"; do
        # Check if package is already installed
        if pacman -Q "$package" &>/dev/null; then
            print_message "$YELLOW" "[$((i+1))/$total] $package is already installed."
        else
            print_message "$YELLOW" "[$((i+1))/$total] Installing $package..."
            if ! sudo pacman -S --noconfirm "$package"; then
                print_message "$RED" "Failed to install $package"
                exit 1
            fi
            installed_packages+=("$package")
        fi
        i=$((i+1))
    done
    

    if [[ ${#installed_packages[@]} -gt 0 ]]; then
        print_message "$GREEN" "Packages installed successfully: ${installed_packages[*]}"
    else
        print_message "$GREEN" "All required packages are already installed."
    fi
}

# Function to enable and start a service
enable_service() {
    local service="$1"
    local already_enabled=false

    if sudo systemctl is-enabled --quiet "$service"; then
        print_message "$YELLOW" "$service service is already enabled."
        already_enabled=true
    else
        print_message "$YELLOW" "Enabling and starting $service service..."
        if ! sudo systemctl enable "$service" && sudo systemctl start "$service"; then
            print_message "$RED" "Failed to enable/start $service service."
            exit 1
        fi
    fi

    if [ "$already_enabled" = false ]; then
        print_message "$GREEN" "$service service enabled and started successfully."
    fi
}

# Function to configure pacman for optimal performance
configure_pacman() {
    clear
    echo "Configuring Pacman for optimal performance..."
    echo

    # Enable colored output and parallel downloads in pacman
    sudo sed -i 's/#Color/Color/' /etc/pacman.conf
    sudo sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    # Update mirrorlist using reflector for the fastest mirrors
    echo "Updating mirrorlist with the fastest mirrors..."
    sudo reflector --country 'United States' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

    # Display the updated mirrorlist
    cat /etc/pacman.d/mirrorlist
    sleep 2
}

# Function to update the system
update_system() {
    if ! sudo pacman -Syu --noconfirm &>/dev/null; then
        error_msg "Failed to update the system"
        exit 1
    fi
    success_msg "System updated successfully."
}