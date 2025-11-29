#!/bin/bash

# --- PART 1: DHCP Configuration (dhcpd.conf) ---
echo "[1/4] Setting up DHCP..."

# Temporarily suspending services
systemctl stop vmware
/usr/bin/vmware-networks --stop

# Write the dhcpd.conf file
cat <<EOF > /etc/vmware/vmnet8/dhcpd/dhcpd.conf
allow unknown-clients;
default-lease-time 1800;                # 30 minutes
max-lease-time 7200;                    # 2 hours

subnet 172.16.0.0 netmask 255.255.255.0 {
    range 172.16.0.230 172.16.0.250;         # Range DHCP
    option broadcast-address 172.16.0.255;
    option domain-name-servers 172.16.0.100; # DNS SERVER
    option domain-name localdomain;
    default-lease-time 1800;
    max-lease-time 7200;
    option netbios-name-servers 172.16.0.2;
    option routers 172.16.0.2;               # Gateway VMnet8
}

host vmnet8 {
    hardware ethernet 00:50:56:C0:00:08;
    fixed-address 172.16.0.1;
    option domain-name-servers 0.0.0.0;
    option domain-name "";
    option routers 0.0.0.0;
}
EOF

# --- PART 2: NAT Configuration (nat.conf) ---
echo "[2/4] Setting up NAT..."

# Make a backup of the original nat.conf file
cp /etc/vmware/vmnet8/nat/nat.conf /etc/vmware/vmnet8/nat/nat.conf.bak

# Rewrite the nat.conf file
cat <<EOF > /etc/vmware/vmnet8/nat/nat.conf
# VMware NAT configuration file
[host]
useMacosVmnetVirtApi = 0
# NAT gateway address
ip = 172.16.0.2
netmask = 255.255.255.0
device = /dev/vmnet8
activeFTP = 1
allowAnyOUI = 1
# VMnet host IP address
hostIp = 172.16.0.1
resetConnectionOnLinkDown = 1
resetConnectionOnDestLocalHost = 1
natIp6Enable = 0
natIp6Prefix = fd15:4ba5:5a2b:1008::/64

[tcp]
timeWaitTimeout = 30

[udp]
timeout = 60

[netbios]
nbnsTimeout = 2
nbnsRetries = 3
nbdsTimeout = 3

[incomingtcp]
# Add port forwarding information here if needed in the future

[incomingudp]
EOF

# --- PART 3: Creating a Script for a Secondary IP Address ---
echo "[3/4] Creating a persistence script for Storage IP..."

cat <<EOF > /usr/local/bin/vmnet8-add-ip.sh
#!/bin/bash
# Script to add a secondary IP address to vmnet8
# Waiting for the interface to exist
count=0
while ! ip link show vmnet8 > /dev/null 2>&1; do
  sleep 1
  count=\$((count+1))
  if [ \$count -ge 60 ]; then exit 1; fi # Desiste após 60s
done

# Wait a little longer to ensure VMware has finished configuring the primary IP address
sleep 5

# Add the IP address if it doesn't exist
if ! ip addr show vmnet8 | grep -q "10.0.130.250"; then
    ip addr add 10.0.130.250/24 dev vmnet8
fi
EOF

chmod +x /usr/local/bin/vmnet8-add-ip.sh

# --- PART 4: Creating a Systemd Service for Persistence ---
echo "[4/4] Creating a Systemd service for automatic boot..."

cat <<EOF > /etc/systemd/system/vmnet8-storage-ip.service
[Unit]
Description=Add Storage IP to vmnet8
After=vmware.service vmware-networks.service network.target
Requires=vmware.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vmnet8-add-ip.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Reload Daemon, Enable on Boot, and Start Everything
systemctl daemon-reload
systemctl enable vmnet8-storage-ip.service

# Restart VMware and apply the secondary IP now
/usr/bin/vmware-networks --start
systemctl start vmware
systemctl start vmnet8-storage-ip.service

echo "Full Setup"
echo "Current status of the vmnet8 interface:"
ip addr show vmnet8
