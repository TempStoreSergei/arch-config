#!/bin/sh

# Function to get used memory
get_used_memory() {
    # Run the `free` command and extract used memory
    used_memory=$(free -h | awk '/^Mem:/{print $3}')

    # Check if the command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Unable to retrieve memory information."
        exit 1
    fi

    # Print the used memory
    echo "$used_memory"
}

# Call the function and print used memory
get_used_memory