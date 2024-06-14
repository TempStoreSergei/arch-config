
#!/bin/bash

# Function to install packages with total progress
install_packages() {
    local packages_file="$1"
    local packages=($(jq -r '.packages[]' "$packages_file"))
    local total=${#packages[@]}
    local i=0

    print_message "$YELLOW" "Installing packages:"

    for package in "${packages[@]}"; do
        print_message "$YELLOW" "[$((i+1))/$total] Installing $package..."
        if ! sudo pacman -S --noconfirm "$package"; then
            print_message "$RED" "Failed to install $package"
            exit 1
        fi
        i=$((i+1))
    done

    print_message "$GREEN" "Packages installed successfully."
}

# Function to enable and start a service
enable_service() {
    local service="$1"
    if sudo systemctl is-enabled --quiet "$service"; then
        print_message "$YELLOW" "$service service is already enabled."
    else
        print_message "$YELLOW" "Enabling and starting $service service..."
        if ! sudo systemctl enable "$service" && sudo systemctl start "$service"; then
            print_message "$RED" "Failed to enable/start $service service."
            exit 1
        fi
    fi
    print_message "$GREEN" "$service service enabled and started successfully."
}

# Function to update the system
update_system() {
    print_message "$YELLOW" "Updating the system..."
    if ! sudo pacman -Syu --noconfirm; then
        print_message "$RED" "Failed to update the system"
        exit 1
    fi
    print_message "$GREEN" "System updated successfully."
}