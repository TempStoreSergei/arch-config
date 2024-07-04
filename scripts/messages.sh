#!/bin/bash

# Function to display messages with color
print_message() {
    local color="$1"
    shift
    echo -e "${color}$@${NC}"
}

# Function to display error messages in red
error_msg() {
    print_message "$RED" "Error: $1" >&2
}

# Function to display informational messages in yellow
info_msg() {
    print_message "$YELLOW" "$1"
}

# Function to display success messages in green
success_msg() {
    print_message "$GREEN" "$1"
}
