#!/bin/bash

# Script to mount a CIFS share using a credentials file.
# This script must be run as root.

# --- Validation: Check if the script is run as root ---
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root."
   echo "Please execute it using 'sudo ./your_script_name.sh' or as the root user."
   exit 1
fi
# --------------------------------------------------------

echo "Starting CIFS mount process..."

# Define variables for better readability and easier modification
MOUNT_POINT="/mnt/storage"
CREDS_FILE="/home/prajenisw/.smbcreds"
SMB_SHARE="//u777777.your-storagebox.de/backup"
SMB_USERNAME="u777777"
SMB_PASSWORD="PASSWORD_STORAGE"

# 1. Create the mount point directory if it doesn't exist
echo "1. Creating mount point directory: $MOUNT_POINT"
mkdir -p "$MOUNT_POINT"

# Check if mkdir was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to create mount point directory $MOUNT_POINT. Exiting."
    exit 1
fi

# 2. Create the credentials file
echo "2. Creating credentials file: $CREDS_FILE"
echo "username=$SMB_USERNAME" > "$CREDS_FILE"
echo "password=$SMB_PASSWORD" >> "$CREDS_FILE"

# Check if echo was successful (for the first write)
if [ $? -ne 0 ]; then
    echo "Error: Failed to write to credentials file $CREDS_FILE. Exiting."
    exit 1
fi

# 3. Set secure permissions for the credentials file
echo "3. Setting secure permissions for credentials file: $CREDS_FILE"
chmod 600 "$CREDS_FILE"

# Check if chmod was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to set permissions on $CREDS_FILE. Exiting."
    rm -f "$CREDS_FILE" # Clean up partially created file
    exit 1
fi

# 4. Mount the CIFS share
echo "4. Mounting CIFS share: $SMB_SHARE to $MOUNT_POINT"

# Get current user's UID and GID for the mount options
# Note: When run as root, id -u and id -g will return 0 unless specified for another user.
# If you want the mount to be owned by 'prajenisw' specifically,
# you would need to get their UID/GID:
# ORIGINAL_UID=$(id -u prajenisw)
# ORIGINAL_GID=$(id -g prajenisw)
# For simplicity, keeping uid=$(id -u), gid=$(id -g) which will be root's by default under sudo.
# If 'prajenisw' needs ownership, ensure 'prajenisw' is the user actually running the script via sudo.
# Or, explicitly get prajenisw's UID/GID regardless of who runs the script:
# UID_PRAJENISW=$(id -u prajenisw 2>/dev/null)
# GID_PRAJENISW=$(id -g prajenisw 2>/dev/null)
# if [ -z "$UID_PRAJENISW" ] || [ -z "$GID_PRAJENISW" ]; then
#    echo "Error: User 'prajenisw' not found. Cannot determine UID/GID for mount options."
#    rm -f "$CREDS_FILE" # Clean up
#    exit 1
# fi
# mount -t cifs -o credentials="$CREDS_FILE",uid=$UID_PRAJENISW,gid=$GID_PRAJENISW "$SMB_SHARE" "$MOUNT_POINT"

# Using the original command's UID and GID logic (will resolve to root's UID/GID if run by root)
mount -t cifs -o credentials="$CREDS_FILE",uid=$(id -u),gid=$(id -g) "$SMB_SHARE" "$MOUNT_POINT"

# Check if mount was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to mount CIFS share. Please check share path, credentials, and network connectivity."
    rm -f "$CREDS_FILE" # Clean up credentials file on failure
    exit 1
else
    echo "CIFS share mounted successfully to $MOUNT_POINT."
fi

# Optional: You might want to remove the credentials file after successful mount
# for added security, but this would prevent remounting without recreating it.
# If the mount is temporary and not intended for fstab, removing might be acceptable.
# For persistent mounts, this file is typically kept.
# rm -f "$CREDS_FILE"
# echo "Credentials file $CREDS_FILE removed (optional step)."

echo "Script execution finished."
