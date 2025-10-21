#!/bin/bash

# Функция для проверки конфигурации HQ сервера
check_hq_config() {
    local config_file="EcoRouterOS.conf"
    local errors=0
    
    echo "Проверка конфигурации HQ сервера в файле $config_file"
    
    # Проверяем существование файла
    if [[ ! -f "$config_file" ]]; then
        echo "ОШИБКА: Файл $config_file не найден!"
        return 1
    fi
    
    # Массив ожидаемых строк для HQ
    declare -a expected_lines=(
        "hostname hq-rtr"
        "dhcp-server 1"
        "lease 86400"
        "mask 255.255.255.0"
        "gateway 192.168.2.1"
        "dns 192.168.1.10"
        "domain-name au-team.irpo"
        "mask 255.255.255.240"
        "ip domain-name au-team.irpo"
        "ip name-server 8.8.8.8"
        "router ospf 1"
        "passive-interface default"
        "no passive-interface tunnel.0"
        "area 0.0.0.0 authentication"
        "network 172.16.0.0/30 area 0.0.0.0"
        "network 192.168.1.0/27 area 0.0.0.0"
        "network 192.168.2.0/28 area 0.0.0.0"
        "ip route 0.0.0.0/0 172.16.1.1"
        "ntp timezone utc+5"
        "interface tunnel.0"
        "ip address 172.16.0.1/30"
        "ip tunnel 172.16.1.2 172.16.2.2 mode gre" || "ip tunnel 172.16.0.2 172.16.0.2 mode gre"
        "ip ospf authentication-key 0x8de456332b943f87"
        "interface int0"
        "ip nat outside"
        "ip address 172.16.1.2/28"
        "interface int1"
        "ip nat inside"
        "ip address 192.168.1.1/27"
        "interface int2"
        "dhcp-server 1"
        "ip nat inside"
        "ip address 192.168.2.1/28"
        "interface int3"
        "ip address 192.168.9.1/29" || "ip address 192.168.99.1/29"
        "ip nat pool"
        "ip nat source dynamic inside-to-outside pool np overload interface int0"
    )
    
    # Проверяем каждую ожидаемую строку
    for line in "${expected_lines[@]}"; do
        if grep -q "$line" "$config_file"; then
            echo "✓ Найдено: $line"
        else
            echo "✗ ОШИБКА: Не найдено: $line"
            ((errors++))
        fi
    done
    
    # Дополнительные проверки для специфичных паттернов
    echo "--- Дополнительные проверки ---"
    
    # Проверка NAT pool (любое название)
    if grep -q "ip nat pool.*192.168.1.1-192.168.1.254,192.168.2.1-192.168.2.254" "$config_file"; then
        echo "✓ NAT pool корректно настроен"
    else
        echo "✗ ОШИБКА: NAT pool настроен некорректно"
        ((errors++))
    fi
    
    # Проверка OSPF networks
    local ospf_networks=3
    local found_networks=$(grep -c "network.*area 0.0.0.0" "$config_file")
    if [[ $found_networks -eq $ospf_networks ]]; then
        echo "✓ Найдено $found_networks OSPF network объявлений"
    else
        echo "✗ ОШИБКА: Ожидалось $ospf_networks OSPF network, найдено $found_networks"
        ((errors++))
    fi
    
    return $errors
}

# Функция для проверки конфигурации BR сервера
check_br_config() {
    local config_file="EcoRouterOS.conf"
    local errors=0
    
    echo "Проверка конфигурации BR сервера в файле $config_file"
    
    # Проверяем существование файла
    if [[ ! -f "$config_file" ]]; then
        echo "ОШИБКА: Файл $config_file не найден!"
        return 1
    fi
    
    # Массив ожидаемых строк для BR
    declare -a expected_lines=(
        "hostname br-rtr"
        "ip domain-name au-team.irpo"
        "ip name-server 8.8.8.8"
        "router ospf 1"
        "passive-interface default"
        "no passive-interface tunnel.0"
        "area 0.0.0.0 authentication"
        "network 172.16.0.0/30 area 0.0.0.0"
        "network 192.168.3.0/28 area 0.0.0.0"
        "ip route 0.0.0.0/0 172.16.2.1"
        "ntp timezone utc+5"
        "interface tunnel.0"
        "ip address 172.16.0.2/30"
        "ip tunnel 172.16.2.2 172.16.1.2 mode gre"
        "ip ospf authentication-key 0x8de456332b943f87"
        "interface int0"
        "ip nat outside"
        "ip address 172.16.2.2/28"
        "interface int1"
        "ip nat inside"
        "ip address 192.168.3.1/28"
        "ip nat pool"
        "ip nat source dynamic inside-to-outside pool np overload interface int0"
    )
    
    # Проверяем каждую ожидаемую строку
    for line in "${expected_lines[@]}"; do
        if grep -q "$line" "$config_file"; then
            echo "✓ Найдено: $line"
        else
            echo "✗ ОШИБКА: Не найдено: $line"
            ((errors++))
        fi
    done
    
    # Дополнительные проверки для специфичных паттернов
    echo "--- Дополнительные проверки ---"
    
    # Проверка NAT pool (любое название)
    if grep -q "ip nat pool.*192.168.3.1-192.168.3.254" "$config_file"; then
        echo "✓ NAT pool корректно настроен"
    else
        echo "✗ ОШИБКА: NAT pool настроен некорректно"
        ((errors++))
    fi
    
    # Проверка OSPF networks
    local ospf_networks=2
    local found_networks=$(grep -c "network.*area 0.0.0.0" "$config_file")
    if [[ $found_networks -eq $ospf_networks ]]; then
        echo "✓ Найдено $found_networks OSPF network объявлений"
    else
        echo "✗ ОШИБКА: Ожидалось $ospf_networks OSPF network, найдено $found_networks"
        ((errors++))
    fi
    
    return $errors
}

# Функция для HQ сервера
hq_server_script() {
    echo "Выполняется скрипт для HQ сервера"
    # Добавьте свои команды для HQ сервера здесь
    echo "Настройки для HQ-SRV"
    apt-get install wget sshpass -y
    grep -q "192.168.1.1" ~/.ssh/known_hosts 2>/dev/null || ssh-keyscan 192.168.1.1 >> ~/.ssh/known_hosts
    wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-RTR-Export-Config.exp
    expect HQ-RTR-Export-Config.exp
    tar -xvf /home/ftpuser/srv/public/pub/hq-rtr-config.tar.gz -C /root/
    tar -xvf /root/startup_backup.tar
    check_hq_config
}

# Функция для BR сервера
br_server_script() {
    echo "Выполняется скрипт для BR сервера"
    # Добавьте свои команды для BR сервера здесь
    echo "Настройки для br-srv.au-team.irpo"
    grep -q "192.168.3.1" ~/.ssh/known_hosts 2>/dev/null || ssh-keyscan 192.168.3.1 >> ~/.ssh/known_hosts
    apt-get install wget sshpass -y
    wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/BR-RTR-Export-Config.exp
    expect BR-RTR-Export-Config.exp
    tar -xvf /home/ftpuser/srv/public/pub/br-rtr-config.tar.gz -C /root/
    tar -xvf /root/startup_backup.tar
    check_br_config
}


apt-get update
apt-get install vsftpd anonftp lftp net-tools -y

cat << EOF >> /etc/vsftpd.conf
local_enable=YES
write_enable=YES
chroot_local_user=YES
local_root=/srv/public
connect_from_port_20=YES
listen=NO
listen_ipv6=NO
pam_service_name=vsftpd
log_ftp_protocol=YES
EOF

sed -i "5s/yes/no/" /etc/xinetd.d/vsftpd
sed -i '13a\\tonly_from\t= 0/0' /etc/xinetd.d/vsftpd

useradd -m -s /bin/bash ftpuser
echo "ftpuser:password" | chpasswd
mkdir -p /srv/public/pub/
chown -R ftpuser:ftpuser /srv/public/pub/
chmod 755 /srv/public/pub/	
chown ftpuser:ftpuser /home/ftpuser/
mkdir -p /home/ftpuser/srv/public/pub
chown ftpuser:ftpuser /home/ftpuser/srv/public/pub/
chmod 755 /home/ftpuser/srv/public/pub/
echo -e '/srv/public/pub\t/home/ftpuser/srv/public/pub\tnone\tdefaults,bind\t0\t0' >> /etc/fstab
mount -a
systemctl restart xinetd.service

# Основная логика проверки
echo "Проверка hostname..."

# Проверяем HQ сервер
if hostnamectl | grep -q "hq-srv.au-team.irpo"; then
    echo "Обнаружен HQ сервер: hq-srv.au-team.irpo"
    hq_server_script

# Проверяем BR сервер
elif hostnamectl | grep -q "br-srv.au-team.irpo"; then
    echo "Обнаружен BR сервер: br-srv.au-team.irpo"
    br_server_script

# Если ни один hostname не совпадает
else
    echo "Ошибка: Неизвестный hostname"
    echo "Текущий hostname:"
    hostnamectl | grep "Static hostname" || hostnamectl | grep "Hostname"
    exit 1
fi

echo "Скрипт завершен успешно"
