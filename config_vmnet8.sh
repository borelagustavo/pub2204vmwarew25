#!/bin/bash

# --- PARTE 1: Configuração do DHCP (dhcpd.conf) ---
echo "[1/4] Configurando DHCP..."

# Parar serviços temporariamente
systemctl stop vmware
/usr/bin/vmware-networks --stop

# Escrever o dhcpd.conf
cat <<EOF > /etc/vmware/vmnet8/dhcpd/dhcpd.conf
allow unknown-clients;
default-lease-time 1800;                # 30 minutos
max-lease-time 7200;                    # 2 horas

subnet 172.16.0.0 netmask 255.255.255.0 {
    range 172.16.0.230 172.16.0.250;         # Range Solicitado
    option broadcast-address 172.16.0.255;
    option domain-name-servers 172.16.0.100; # DNS Solicitado
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

# --- PARTE 2: Configuração do NAT (nat.conf) ---
echo "[2/4] Configurando NAT..."

# Faz backup do nat.conf original
cp /etc/vmware/vmnet8/nat/nat.conf /etc/vmware/vmnet8/nat/nat.conf.bak

# Reescreve o nat.conf com as configurações corretas baseadas no seu arquivo
# Mantivemos as configurações padrão importantes e fixamos os IPs
cat <<EOF > /etc/vmware/vmnet8/nat/nat.conf
# VMware NAT configuration file
[host]
useMacosVmnetVirtApi = 0
# NAT gateway address (Gateway para as VMs)
ip = 172.16.0.2
netmask = 255.255.255.0
device = /dev/vmnet8
activeFTP = 1
allowAnyOUI = 1
# VMnet host IP address (IP do Ubuntu na rede interna)
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
# Adicione port forwarding aqui se precisar no futuro

[incomingudp]
EOF

# --- PARTE 3: Criar Script para IP Secundário ---
echo "[3/4] Criando script de persistência para IP de Storage..."

cat <<EOF > /usr/local/bin/vmnet8-add-ip.sh
#!/bin/bash
# Script para adicionar IP secundário à vmnet8
# Aguarda a interface existir
count=0
while ! ip link show vmnet8 > /dev/null 2>&1; do
  sleep 1
  count=\$((count+1))
  if [ \$count -ge 60 ]; then exit 1; fi # Desiste após 60s
done

# Aguarda mais um pouco para garantir que o VMware terminou de configurar o IP primário
sleep 5

# Adiciona o IP se ele não existir
if ! ip addr show vmnet8 | grep -q "10.0.130.250"; then
    ip addr add 10.0.130.250/24 dev vmnet8
fi
EOF

chmod +x /usr/local/bin/vmnet8-add-ip.sh

# --- PARTE 4: Criar Serviço Systemd para Persistência ---
echo "[4/4] Criando serviço Systemd para boot automático..."

cat <<EOF > /etc/systemd/system/vmnet8-storage-ip.service
[Unit]
Description=Adicionar IP de Storage na vmnet8
After=vmware.service vmware-networks.service network.target
Requires=vmware.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vmnet8-add-ip.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Recarregar Daemon, Habilitar no Boot e Iniciar tudo
systemctl daemon-reload
systemctl enable vmnet8-storage-ip.service

# Reiniciar VMware e aplicar o IP secundário agora
/usr/bin/vmware-networks --start
systemctl start vmware
systemctl start vmnet8-storage-ip.service

echo "Configuração Completa."
echo "Status atual da interface vmnet8:"
ip addr show vmnet8
