#!/bin/bash

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
