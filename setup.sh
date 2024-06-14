#!/bin/bash

# Source the functions script
source scripts/messages.sh
source scripts/utils.sh
source scripts/os.sh

# Path to JSON files
packages_file="json/packages.json"
services_file="json/services.json"

# Update system
update_system

# Read and install packages
read_packages "$packages_file"

# Read services
read_services "$services_file"

# Enable and start services
all_already_enabled=true
for service in "${services[@]}"; do
    if ! enable_service "$service"; then
        all_already_enabled=false
    fi
done

if [ "$all_already_enabled" = true ]; then
    print_message "$GREEN" "All services are already enabled."
else
    print_message "$GREEN" "All services started successfully."
fi