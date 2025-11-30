#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (sudo)."
  exit
fi

echo ">>> Installing dependencies for VMware..."
apt install build-essential gcc make linux-headers-$(uname -r) libaio1 -y

# VMware Installation
VMWARE_FILE="VMware-Workstation-Full-25H2-24995812.x86_64.bundle"
if [ -f "$VMWARE_FILE" ]; then
    echo ">>> Installing VMware Workstation ($VMWARE_FILE)..."
    chmod +x "$VMWARE_FILE"
    ./"$VMWARE_FILE" --console --required --eulas-agreed
    vmware-modconfig --console --install-all
else
    echo ">>> WARNING: File $VMWARE_FILE not found in current directory."
    echo ">>> VMware installation will be skipped."
fi
