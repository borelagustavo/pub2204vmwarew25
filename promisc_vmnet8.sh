#!/bin/bash

# 1. Check if the script is running with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Please use sudo."
  exit 1
fi

SERVICE_FILE="/etc/systemd/system/fix-vmnet8.service"

echo "Started configuration for VMnet8 Promiscuous Mode..."

# 2. Create the systemd service file
echo "Creating service file at $SERVICE_FILE..."

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Fix VMware VMnet8 Promiscuous Mode
Requires=vmware-networks.service
After=vmware-networks.service

[Service]
Type=oneshot
ExecStart=/usr/bin/chmod a+rw /dev/vmnet8
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 3. Reload systemd to recognize the new file
echo "Reloading systemd daemon..."
systemctl daemon-reload

# 4. Enable the service to run on boot
echo "Enabling fix-vmnet8.service..."
systemctl enable fix-vmnet8.service

# 5. Start the service immediately to apply the fix now
echo "Starting fix-vmnet8.service..."
systemctl start fix-vmnet8.service

# 6. specific check for the user
if [ -c "/dev/vmnet8" ] && [ -w "/dev/vmnet8" ]; then
    echo "SUCCESS: /dev/vmnet8 is now writable (Promiscuous mode enabled)."
else
    echo "WARNING: There might be an issue. Please ensure VMware is running."
fi
