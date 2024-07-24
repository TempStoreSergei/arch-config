# Function to install packages with total progress
install_packages() {
    local packages_file="$1"
    local packages=($(jq -r '.packages[]' "$packages_file"))
    local total=${#packages[@]}
    local installed_packages=()
    local i=0

    for package in "${packages[@]}"; do
        if pacman -Q "$package" &>/dev/null; then
            info_msg "[$((i+1))/$total] $package is already installed."
        else
            info_msg "[$((i+1))/$total] Installing $package..."
            if ! sudo pacman -S --noconfirm "$package"; then
                error_msg "Failed to install $package"
                exit 1
            fi
            installed_packages+=("$package")
        fi
        i=$((i+1))
    done

    if [[ ${#installed_packages[@]} -gt 0 ]]; then
        success_msg "Packages installed successfully: ${installed_packages[*]}"
    else
        success_msg "All required packages are already installed."
    fi
}

# Function to enable and start a service
enable_service() {
    local service="$1"
    if sudo systemctl is-enabled --quiet "$service"; then
        info_msg "$service service is already enabled."
    else
        info_msg "Enabling and starting $service service..."
        if ! sudo systemctl enable "$service" && sudo systemctl start "$service"; then
            error_msg "Failed to enable/start $service service."
            exit 1
        fi
        success_msg "$service service enabled and started successfully."
    fi
}

# Function to configure pacman for optimal performance
configure_pacman() {
    clear
    info_msg "Configuring Pacman for optimal performance..."

    sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
    sudo sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

    info_msg "Updating mirrorlist with the fastest mirrors..."
    sudo reflector --country 'United States' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist

    cat /etc/pacman.d/mirrorlist
    sleep 2
}

# Function to update the system
update_system() {
    if ! sudo pacman -Syu --noconfirm; then
        error_msg "Failed to update the system"
        exit 1
    fi
    success_msg "System updated successfully."
}