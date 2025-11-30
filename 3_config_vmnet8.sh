#!/bin/bash

echo "============================================"
echo "  VMware vmnet8 (NAT) configuration"
echo "============================================"
echo ""

# --- PART 1: Stopping services ---
echo "[1/5] Stopping VMware services..."
sudo systemctl stop vmware
sudo /usr/bin/vmware-networks --stop
sleep 2

# --- PART 2: Backup of the original file ---
echo "[2/5] Creating a backup of dhcpd.conf..."
sudo cp /etc/vmware/vmnet8/dhcpd/dhcpd.conf /etc/vmware/vmnet8/dhcpd/dhcpd.conf.bak.$(date +%Y%m%d%H%M%S)

# --- Part 3: Configuring DHCP ---
echo "[3/5] Applying new DHCP configuration..."
sudo cat <<'EOF' > /etc/vmware/vmnet8/dhcpd/dhcpd.conf
# Configuration file for ISC 2.0 vmnet-dhcpd operating on vmnet8.
# Modified via configuration script

allow unknown-clients;
default-lease-time 1800;                # 30 minutes
max-lease-time 7200;                    # 2 hours

subnet 172.16.0.0 netmask 255.255.255.0 {
        range 172.16.0.230 172.16.0.250;
        option broadcast-address 172.16.0.255;
        option domain-name-servers 172.16.0.100;
        option domain-name localdomain;
        default-lease-time 1800;
        max-lease-time 7200;
        option netbios-name-servers 172.16.0.2;
        option routers 172.16.0.2;
}

host vmnet8 {
        hardware ethernet 00:50:56:C0:00:08;
        fixed-address 172.16.0.1;
        option domain-name-servers 0.0.0.0;
        option domain-name "";
        option routers 0.0.0.0;
}
EOF

# --- PART 4: Creating a persistence service for a secondary IP address ---
echo "[4/5] Creating a service for a secondary IP (Storage)..."

# Script that adds the IP address
sudo cat <<'EOF' > /usr/local/bin/vmnet8-storage-ip.sh
#!/bin/bash
# Waiting for the vmnet8 interface to exist
for i in {1..60}; do
    if ip link show vmnet8 > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Wait for VMware to finish configuring
sleep 5

# Add the secondary IP address if it doesn't exist
if ! ip addr show vmnet8 | grep -q "10.0.130.250"; then
    ip addr add 10.0.130.250/24 dev vmnet8
fi
EOF

sudo chmod +x /usr/local/bin/vmnet8-storage-ip.sh

# Serviço Systemd
sudo cat <<'EOF' > /etc/systemd/system/vmnet8-storage-ip.service
[Unit]
Description=Add Storage IP to vmnet8
After=vmware.service
Requires=vmware.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vmnet8-storage-ip.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Ativar o serviço
sudo systemctl daemon-reload
sudo systemctl enable vmnet8-storage-ip.service

# --- PART 5: Getting Started ---
echo "[5/5] Starting services..."
sudo /usr/bin/vmware-networks --start
sudo systemctl start vmware
sleep 3
sudo systemctl start vmnet8-storage-ip.service

# --- RESULT ---
echo ""
echo "============================================"
echo "           CONFIGURATION COMPLETED"
echo "============================================"
echo ""
echo "--- DHCP configuration applied ---"
echo "Range: 172.16.0.230 - 172.16.0.250"
echo "DNS: 172.16.0.100"
echo ""
echo "--- Interface vmnet8 ---"
ip addr show vmnet8
echo ""
echo "--- Service Status ---"
sudo /usr/bin/vmware-networks --status
