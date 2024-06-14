#!/bin/bash
read_packages() {
    local packages_file="$1"
    if [[ -f "$packages_file" ]]; then
        install_packages "$packages_file"
    else
        print_message "$RED" "Packages file not found: $packages_file"
        exit 1
    fi
}

# Read services from JSON file
read_services() {
    local services_file="$1"
    if [[ -f "$services_file" ]]; then
        services=($(jq -r '.services[]' "$services_file"))
    else
        print_message "$RED" "Services file not found: $services_file"
        exit 1
    fi
}