#!/bin/bash

# Check if the script is being run as root.
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (sudo)."
  exit
fi

echo ">>> Starting system update..."
apt update 
apt dist-upgrade -y

echo ">>> Installing XFCE4 and Xorg components..."
apt install xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils -y

echo ">>> Installing and configuring XRDP..."
apt install xrdp -y
systemctl enable xrdp
adduser xrdp ssl-cert

# Configura o startwm.sh para usar o XFCE
echo ">>> Setting up the desktop environment for XRDP..."
cat <<EOF | tee /etc/xrdp/startwm.sh
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
. /etc/X11/Xsession
exec /usr/bin/startxfce4
EOF

chmod +x /etc/xrdp/startwm.sh
systemctl restart xrdp

# Resolves Colord/Polkit permission issues
echo ">>> Applying Polkit correction for Color Manager..."
cat <<EOF | tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

systemctl restart xrdp

# Changes the encryption level in xrdp.ini
echo ">>> Changing crypt_level to 'low'..."
if grep -q "crypt_level=" /etc/xrdp/xrdp.ini; then
    sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini
else
    echo "crypt_level=low" >> /etc/xrdp/xrdp.ini
fi

systemctl restart xrdp

echo ">>> Optimizing network settings (BBR)..."
echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_congestion_control
systemctl restart xrdp

echo ">>> Installing dependencies for VMware..."
apt install build-essential gcc make linux-headers-$(uname -r) libaio1 -y

# VMware Installation
VMWARE_FILE="VMware-Workstation-Full-25H2-XXXXXXXXXX.x86_64.bundle"
if [ -f "$VMWARE_FILE" ]; then
    echo ">>> Installing VMware Workstation ($VMWARE_FILE)..."
    chmod +x "$VMWARE_FILE"
    ./"$VMWARE_FILE" --console --required --eulas-agreed
    vmware-modconfig --console --install-all
else
    echo ">>> WARNING: The file $VMWARE_FILE was not found in the current directory."
    echo ">>> The VMware installation will be skipped."
fi

echo ">>> Installing Google Chrome..."
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg --yes
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list
apt update
apt install google-chrome-stable -y

echo ">>> Creating user 'prajenisw'..."
if id "prajenisw" &>/dev/null; then
    echo "User name prajenisw already exists."
else
    adduser --gecos "" prajenisw
fi

echo ">>> Adding a user to the sudo and ssl-cert groups..."
usermod -aG sudo prajenisw
usermod -aG ssl-cert prajenisw

echo ">>> Installation and setup complete!"
