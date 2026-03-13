#!/bin/bash
# ============================================================================
# Файл переменных окружения для скриптов проверки
# Заполните значения под свою конфигурацию
# ============================================================================

# === Общие параметры ===
TIMEZONE="Asia/Yekaterinburg"
DOMAIN="au-team.irpo"
DNS_SERVER="8.8.8.8"
DNS_CHECK_HOST="ya.ru"
NTP_TIMEZONE="utc+5"

# === SSH параметры ===
SSH_USER="sshuser"
SSH_PASSWORD="P@ssw0rd"
SSH_PORT="2026"

# === OSPF ===
OSPF_AUTH_KEY="0xeb5442f9b26607db" # P@ssw0rd

# === Tunnel (GRE) ===
TUNNEL_NETWORK="10.10.10.0/30"
HQ_RTR_TUNNEL_IP="10.10.10.1/30"
BR_RTR_TUNNEL_IP="10.10.10.2/30"

# === VLANs ===
VLAN_MGMT="999"
VLAN_100="100"
VLAN_200="200"

# === DHCP (HQ-RTR) ===
DHCP_LEASE="86400"
DHCP_MASK="255.255.255.240"

# === ISP ===
ISP_HOSTNAME="ISP"
ISP_IP1="172.16.1.1"
ISP_IP2="172.16.2.1"

# === IP-адреса устройств (без маски — для пингов/SSH) ===
HQ_RTR_IP="192.168.100.1"
BR_RTR_IP="192.168.0.1"

# === IP-адреса интерфейсов роутеров (с маской — для проверки конфигов) ===
HQ_RTR_WAN_IP="172.16.1.2/28"
HQ_RTR_LAN1_IP="${HQ_RTR_IP}/27"
HQ_RTR_LAN2_IP="192.168.200.1/28"
HQ_RTR_LAN3_IP="192.168.99.1/29"

BR_RTR_WAN_IP="172.16.2.2/28"
BR_RTR_LAN_IP="${BR_RTR_IP}/28"

# === IP-адреса серверов/клиентов (с маской) ===
HQ_SRV_IP="192.168.100.2/27"
HQ_CLI_IP="192.168.200.2/28"
BR_SRV_IP="192.168.0.2/28"

# === Сети (для OSPF) ===
HQ_SRV_NETWORK="192.168.100.0/27"
HQ_CLI_NETWORK="192.168.200.0/28"
BR_SRV_NETWORK="192.168.0.0/28"

# === Hostnames ===
HQ_SRV_HOSTNAME="hq-srv.${DOMAIN}"
HQ_CLI_HOSTNAME="hq-cli.${DOMAIN}"
BR_SRV_HOSTNAME="br-srv.${DOMAIN}"

# === NAT pool диапазоны ===
# Вычисляем подсети (первые 3 октета) для построения диапазонов
_HQ_LAN1_SUBNET="${HQ_RTR_IP%.*}"                    # 192.168.100
_HQ_LAN2_IP="${HQ_RTR_LAN2_IP%%/*}"
_HQ_LAN2_SUBNET="${_HQ_LAN2_IP%.*}"                  # 192.168.200
_HQ_LAN3_IP="${HQ_RTR_LAN3_IP%%/*}"
_HQ_LAN3_SUBNET="${_HQ_LAN3_IP%.*}"                  # 192.168.99
_BR_LAN_SUBNET="${BR_RTR_IP%.*}"                      # 192.168.0

# NAT pool — отдельные паттерны для каждого VLAN
HQ_RTR_NAT_POOLS=(
    "ip nat pool.*${HQ_RTR_IP}-${_HQ_LAN1_SUBNET}.30"
    "ip nat pool.*${_HQ_LAN2_IP}-${_HQ_LAN2_SUBNET}.14"
    "ip nat pool.*${_HQ_LAN3_IP}-${_HQ_LAN3_SUBNET}.6"
)
BR_RTR_NAT_POOLS=(
    "ip nat pool.*${BR_RTR_IP}-${_BR_LAN_SUBNET}.14"
)

# === Ping-таргеты (используют переменные выше) ===
# ${VAR%%/*} убирает маску из IP, например 192.168.1.10/27 -> 192.168.1.10

HQ_CLI_PING_TARGETS=(
    "${BR_RTR_IP}"
    "${BR_SRV_IP%%/*}"
    "${ISP_IP2}"
    "${HQ_SRV_IP%%/*}"
    "${DNS_SERVER}"
)

HQ_SRV_PING_TARGETS=(
    "${HQ_RTR_IP}"
    "${HQ_CLI_IP%%/*}"
    "${ISP_IP1}"
    "${BR_SRV_IP%%/*}"
    "${DNS_SERVER}"
    "${BR_SRV_HOSTNAME}"
)

BR_SRV_PING_TARGETS=(
    "${BR_RTR_IP}"
    "${HQ_CLI_IP%%/*}"
    "${ISP_IP2}"
    "${HQ_SRV_IP%%/*}"
    "${DNS_SERVER}"
    "${HQ_SRV_HOSTNAME}"
)

# === SSH-таргеты (куда подключаемся по SSH) ===
HQ_SRV_SSH_TARGET="${BR_SRV_IP%%/*}"
BR_SRV_SSH_TARGET="${HQ_SRV_IP%%/*}"

# === HQ-RTR (EcoRouter) ===
HQ_RTR_SSH_HOST="${HQ_RTR_IP}"
HQ_RTR_EXPORT_SCRIPT="HQ-RTR-Export-Config.exp"
HQ_RTR_EXPORT_URL="https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-RTR-Export-Config.exp"
HQ_RTR_CONFIG_ARCHIVE="/home/ftpuser/srv/public/pub/hq-rtr-config.tar.gz"

HQ_RTR_EXPECTED_LINES=(
    "hostname hq-rtr"
    "dhcp-server 1"
    "lease ${DHCP_LEASE}"
    "mask ${DHCP_MASK}"
    "gateway ${HQ_RTR_LAN2_IP%%/*}"
    "dns ${HQ_SRV_IP%%/*}"
    "domain-name ${DOMAIN}"
    "ip domain-name ${DOMAIN}"
    "router ospf 1"
    "passive-interface default"
    "no passive-interface tunnel.0"
    "area 0.0.0.0 authentication|ip ospf authentication message-digest"
    "network ${TUNNEL_NETWORK} area 0.0.0.0"
    "network ${HQ_SRV_NETWORK} area 0.0.0.0"
    "network ${HQ_CLI_NETWORK} area 0.0.0.0"
    "ip route 0.0.0.0/0 ${ISP_IP1}"
    "ntp timezone ${NTP_TIMEZONE}"
    "interface tunnel.0"
    "ip address ${HQ_RTR_TUNNEL_IP}"
    "ip tunnel ${HQ_RTR_WAN_IP%%/*} ${BR_RTR_WAN_IP%%/*} mode gre"
    "ip ospf authentication-key ${OSPF_AUTH_KEY}|ip ospf message-digest-key 1 md5 ${OSPF_AUTH_KEY}"
    "ip nat outside"
    "ip address ${HQ_RTR_WAN_IP}"
    "ip nat inside"
    "ip address ${HQ_RTR_LAN1_IP}"
    "ip nat inside"
    "ip address ${HQ_RTR_LAN2_IP}"
    "encapsulation dot1q ${VLAN_MGMT}"
    "range ${HQ_CLI_IP%%/*}-${HQ_CLI_IP%%/*}"
    "encapsulation dot1q ${VLAN_200}"
    "encapsulation dot1q ${VLAN_100}"
    "ip nat pool"
)
HQ_RTR_OSPF_NETWORKS_COUNT_MIN=3
HQ_RTR_OSPF_NETWORKS_COUNT_MAX=4
# HQ_RTR_NAT_STATIC=(
#     "ip nat source static tcp ${HQ_SRV_IP%%/*} 80 ${HQ_RTR_WAN_IP%%/*} 8080"
#     "ip nat source static tcp ${HQ_SRV_IP%%/*} ${SSH_PORT} ${HQ_RTR_WAN_IP%%/*} ${SSH_PORT}"
# )

# === BR-RTR (EcoRouter) ===
BR_RTR_SSH_HOST="${BR_RTR_IP}"
BR_RTR_EXPORT_SCRIPT="BR-RTR-Export-Config.exp"
BR_RTR_EXPORT_URL="https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/BR-RTR-Export-Config.exp"
BR_RTR_CONFIG_ARCHIVE="/home/ftpuser/srv/public/pub/br-rtr-config.tar.gz"

BR_RTR_EXPECTED_LINES=(
    "hostname br-rtr"
    "ip domain-name ${DOMAIN}"
    "router ospf 1"
    "passive-interface default"
    "no passive-interface tunnel.0"
    "area 0.0.0.0 authentication|ip ospf authentication message-digest"
    "network ${TUNNEL_NETWORK} area 0.0.0.0"
    "network ${BR_SRV_NETWORK} area 0.0.0.0"
    "ip route 0.0.0.0/0 ${ISP_IP2}"
    "ntp timezone ${NTP_TIMEZONE}"
    "interface tunnel.0"
    "ip address ${BR_RTR_TUNNEL_IP}"
    "ip tunnel ${BR_RTR_WAN_IP%%/*} ${HQ_RTR_WAN_IP%%/*} mode gre"
    "ip ospf authentication-key ${OSPF_AUTH_KEY}|ip ospf message-digest-key 1 md5 ${OSPF_AUTH_KEY}"
    "ip nat outside"
    "ip address ${BR_RTR_WAN_IP}"
    "interface int1"
    "ip nat inside"
    "ip address ${BR_RTR_LAN_IP}"
    "ip nat pool"
)
BR_RTR_OSPF_NETWORKS_COUNT_MIN=2
BR_RTR_OSPF_NETWORKS_COUNT_MAX=2
# BR_RTR_NAT_STATIC=(
#     "ip nat source static tcp ${BR_SRV_IP%%/*} 8080 ${BR_RTR_WAN_IP%%/*} 8080"
#     "ip nat source static tcp ${BR_SRV_IP%%/*} ${SSH_PORT} ${BR_RTR_WAN_IP%%/*} ${SSH_PORT}"
# )

# === Конфигурация dnsmasq (HQ-SRV) ===
DNSMASQ_CONFIG_FILE="/etc/dnsmasq.conf"
DNSMASQ_EXPECTED=(
    "domain=${DOMAIN}"
    "server=${DNS_SERVER}"
    "\<hq-rtr.${DOMAIN}"
    "\<168.192.in-addr.arpa,hq-rtr.${DOMAIN}"
    "\<web.${DOMAIN}"
    "\<docker.${DOMAIN}"
    "\<br-rtr.${DOMAIN}"
    "\<hq-srv.${DOMAIN}"
    "\<168.192.in-addr.arpa,hq-srv.${DOMAIN}"
    "\<hq-cli.${DOMAIN}"
    "\<168.192.in-addr.arpa,hq-cli.${DOMAIN}"
    "\<br-srv.${DOMAIN}"
)
