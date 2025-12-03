#!/bin/bash
# Script to mount a CIFS share using a credentials file.
# This script must be run as root.

# --- Configuration: Define the target user who will use the storage ---
TARGET_USER="prajenisw"

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
CREDS_FILE="/home/${TARGET_USER}/.smbcreds"
SMB_SHARE="//u777777.your-storagebox.de/backup"
SMB_USERNAME="u777777"
SMB_PASSWORD="PASSWORD_STORAGE"

# --- Get the target user's UID and GID ---
echo "0. Getting UID and GID for user: $TARGET_USER"

# Validate if user exists
if ! id "$TARGET_USER" &>/dev/null; then
    echo "Error: User '$TARGET_USER' does not exist. Exiting."
    exit 1
fi

TARGET_UID=$(id -u "$TARGET_USER")
TARGET_GID=$(id -g "$TARGET_USER")

echo "   User: $TARGET_USER | UID: $TARGET_UID | GID: $TARGET_GID"

# 1. Create the mount point directory if it doesn't exist
echo "1. Creating mount point directory: $MOUNT_POINT"
mkdir -p "$MOUNT_POINT"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create mount point directory $MOUNT_POINT. Exiting."
    exit 1
fi

# Set ownership of mount point to target user
chown "${TARGET_USER}:${TARGET_USER}" "$MOUNT_POINT"

# 2. Create the credentials file
echo "2. Creating credentials file: $CREDS_FILE"
cat > "$CREDS_FILE" << EOF
username=$SMB_USERNAME
password=$SMB_PASSWORD
EOF

if [ $? -ne 0 ]; then
    echo "Error: Failed to write to credentials file $CREDS_FILE. Exiting."
    exit 1
fi

# 3. Set secure permissions for the credentials file
echo "3. Setting secure permissions for credentials file: $CREDS_FILE"
chmod 600 "$CREDS_FILE"
chown "${TARGET_USER}:${TARGET_USER}" "$CREDS_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Failed to set permissions on $CREDS_FILE. Exiting."
    rm -f "$CREDS_FILE"
    exit 1
fi

# 4. Unmount if already mounted (to apply new settings)
if mountpoint -q "$MOUNT_POINT"; then
    echo "4. Unmounting existing mount at $MOUNT_POINT"
    umount "$MOUNT_POINT"
fi

# 5. Mount the CIFS share with correct permissions
echo "5. Mounting CIFS share: $SMB_SHARE to $MOUNT_POINT"
echo "   Using UID=$TARGET_UID, GID=$TARGET_GID"

mount -t cifs "$SMB_SHARE" "$MOUNT_POINT" \
    -o credentials="$CREDS_FILE",\
uid=$TARGET_UID,\
gid=$TARGET_GID,\
file_mode=0664,\
dir_mode=0775,\
noperm,\
vers=3.0,\
iocharset=utf8

# Check if mount was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to mount CIFS share."
    echo "Possible causes:"
    echo "  - Network connectivity issues"
    echo "  - Wrong credentials"
    echo "  - SMB/CIFS version incompatibility (try changing vers=3.0 to vers=2.1 or vers=1.0)"
    echo "  - Missing cifs-utils package (install with: apt install cifs-utils)"
    rm -f "$CREDS_FILE"
    exit 1
else
    echo ""
    echo "=========================================="
    echo "CIFS share mounted successfully!"
    echo "=========================================="
    echo "Mount point: $MOUNT_POINT"
    echo "Owner: $TARGET_USER (UID: $TARGET_UID, GID: $TARGET_GID)"
    echo ""
    echo "The user '$TARGET_USER' can now:"
    echo "  - Read files"
    echo "  - Write files"
    echo "  - Create folders"
    echo "  - Delete files"
    echo ""
fi

# 6. Verify mount and show permissions
echo "6. Verifying mount:"
ls -la "$MOUNT_POINT"
echo ""
df -h "$MOUNT_POINT"

echo ""
echo "Script execution finished."
