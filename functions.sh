#!/bin/bash

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to display error messages in red
error_msg() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Function to display informational messages in yellow
info_msg() {
    echo -e "${YELLOW}$1${NC}"
}

# Function to display success messages in green
success_msg() {
    echo -e "${GREEN}$1${NC}"
}

# Function to install packages with total progress
install_packages() {
    local packages=("$@")
    local total=${#packages[@]}
    local i=0

    for package in "${packages[@]}"; do
        info_msg "Installing $package ($((i+1))/$total)..."
        if ! sudo pacman -S --noconfirm "$package"; then
            error_msg "Failed to install $package"
            exit 1
        fi
        i=$((i+1))
    done
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
    fi
}
