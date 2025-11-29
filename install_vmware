#!/bin/bash

# Verifica se o script está sendo executado como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script como root (sudo)."
  exit
fi

echo ">>> Iniciando atualização do sistema..."
apt update 
apt dist-upgrade -y

echo ">>> Instalando XFCE4 e componentes do Xorg..."
apt install xfce4 xfce4-goodies xorg dbus-x11 x11-xserver-utils -y

echo ">>> Instalando e configurando XRDP..."
apt install xrdp -y
systemctl enable xrdp
adduser xrdp ssl-cert

# Configura o startwm.sh para usar o XFCE
echo ">>> Configurando o ambiente de desktop para XRDP..."
cat <<EOF | tee /etc/xrdp/startwm.sh
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
. /etc/X11/Xsession
exec /usr/bin/startxfce4
EOF

chmod +x /etc/xrdp/startwm.sh
systemctl restart xrdp

# Resolve problemas de permissão do Colord/Polkit
echo ">>> Aplicando correção do Polkit para Color Manager..."
cat <<EOF | tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

systemctl restart xrdp

# Altera o nível de criptografia no xrdp.ini (Substituindo VIM por SED para automação)
echo ">>> Alterando crypt_level para 'low'..."
if grep -q "crypt_level=" /etc/xrdp/xrdp.ini; then
    sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini
else
    echo "crypt_level=low" >> /etc/xrdp/xrdp.ini
fi

systemctl restart xrdp

echo ">>> Otimizando configurações de rede (BBR)..."
echo "net.core.default_qdisc=fq" | tee -a /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" | tee -a /etc/sysctl.conf
sysctl -p
sysctl net.ipv4.tcp_congestion_control
systemctl restart xrdp

echo ">>> Instalando dependências para VMware..."
apt install build-essential gcc make linux-headers-$(uname -r) libaio1 -y

# Instalação do VMware
VMWARE_FILE="VMware-Workstation-Full-25H2-24995812.x86_64.bundle"
if [ -f "$VMWARE_FILE" ]; then
    echo ">>> Instalando VMware Workstation ($VMWARE_FILE)..."
    chmod +x "$VMWARE_FILE"
    ./"$VMWARE_FILE" --console --required --eulas-agreed
    vmware-modconfig --console --install-all
else
    echo ">>> AVISO: O arquivo $VMWARE_FILE não foi encontrado no diretório atual."
    echo ">>> A instalação do VMware será pulada."
fi

echo ">>> Instalando Google Chrome..."
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg --yes
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | tee /etc/apt/sources.list.d/google-chrome.list
apt update
apt install google-chrome-stable -y

echo ">>> Criando usuário 'prajenisw'..."
# --gecos "" impede perguntas de Nome, Sala, Telefone, etc. Pedirá apenas a senha.
if id "prajenisw" &>/dev/null; then
    echo "Usuário prajenisw já existe."
else
    adduser --gecos "" prajenisw
fi

echo ">>> Adicionando usuário aos grupos sudo e ssl-cert..."
usermod -aG sudo prajenisw
usermod -aG ssl-cert prajenisw

echo ">>> Instalação e configuração concluídas!"
