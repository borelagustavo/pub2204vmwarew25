#!/bin/bash

# ==============================================================================
# XRDP Performance Optimization Script for Ubuntu 22.04/24.04
# ==============================================================================

# 1. Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Please utilize 'sudo'."
  exit 1
fi

echo "Starting XRDP performance optimization..."

# ==============================================================================
# Step 1: Configure the TCP send buffer size in /etc/xrdp/xrdp.ini
# ==============================================================================
XRDP_INI="/etc/xrdp/xrdp.ini"

if [ -f "$XRDP_INI" ]; then
    echo "Found configuration file: $XRDP_INI"
    
    # Create a backup of the original file
    echo "Creating backup at ${XRDP_INI}.bak..."
    cp "$XRDP_INI" "${XRDP_INI}.bak"

    echo "Updating tcp_send_buffer_bytes..."
    # This sed command looks for 'tcp_send_buffer_bytes' (commented with # or ; or uncommented)
    # and replaces the whole line with the optimization value.
    sed -i 's/^[#;]*\s*tcp_send_buffer_bytes=.*/tcp_send_buffer_bytes=4194304/' "$XRDP_INI"
    
    echo "xrdp.ini updated successfully."
else
    echo "Error: $XRDP_INI not found. Is XRDP installed?"
    exit 1
fi

# ==============================================================================
# Step 2: Configure the kernel network buffer size
# ==============================================================================
SYSCTL_XRDP="/etc/sysctl.d/xrdp.conf"

echo "Configuring kernel network buffer size..."
echo "Creating/Overwriting $SYSCTL_XRDP..."

# Write the configuration to the new file
echo "net.core.wmem_max = 8388608" > "$SYSCTL_XRDP"

echo "Applying new system control settings..."
sysctl -p "$SYSCTL_XRDP"

# ==============================================================================
# Step 3: Restart Services
# ==============================================================================
echo "Restarting XRDP service to apply changes..."
systemctl restart xrdp

echo "================================================================="
echo "Optimization complete! Please reconnect to your RDP session."
echo "================================================================="
