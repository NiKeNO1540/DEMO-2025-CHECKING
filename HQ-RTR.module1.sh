#!/bin/bash

# Подключаем файл окружения
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Массивы для отслеживания результатов
declare -a CHECK_NAMES=()
declare -a CHECK_RESULTS=()

# Функция для записи результата проверки
add_result() {
    CHECK_NAMES+=("$1")
    CHECK_RESULTS+=("$2")
}

# Функция для вывода итоговой таблицы
print_summary_table() {
    local pass=0
    local fail=0
    local total=${#CHECK_NAMES[@]}

    echo ""
    echo "================================ ИТОГОВАЯ ТАБЛИЦА ================================"
    printf "%-55s | %s\n" "Пункт проверки" "Результат"
    echo "-----------------------------------------------------------+--------------------"

    for i in "${!CHECK_NAMES[@]}"; do
        if [[ "${CHECK_RESULTS[$i]}" == "OK" ]]; then
            printf "%-55s | \e[32m✓ Выполнено\e[0m\n" "${CHECK_NAMES[$i]}"
            ((pass++))
        else
            printf "%-55s | \e[31m✗ Не выполнено\e[0m\n" "${CHECK_NAMES[$i]}"
            ((fail++))
        fi
    done

    echo "-----------------------------------------------------------+--------------------"
    echo -e "ИТОГО: \e[32m$pass\e[0m из $total выполнено"
    echo "================================================================================="
}

# Функция для проверки конфигурации HQ роутера
check_hq_config() {
    local config_file="EcoRouterOS.conf"

    echo "Проверка конфигурации HQ роутера в файле $config_file"

    if [[ ! -f "$config_file" ]]; then
        echo "ОШИБКА: Файл $config_file не найден!"
        add_result "Файл конфигурации $config_file" "FAIL"
        return 1
    fi
    add_result "Файл конфигурации $config_file" "OK"

    for entry in "${HQ_RTR_EXPECTED_LINES[@]}"; do
        # Поддержка альтернатив через | (например "вариант1|вариант2")
        if [[ "$entry" == *"|"* ]]; then
            IFS='|' read -ra alternatives <<< "$entry"
            local found=false
            for alt in "${alternatives[@]}"; do
                if grep -q "$alt" "$config_file"; then
                    echo "✓ Найдено: $alt"
                    add_result "Конфиг: $alt" "OK"
                    found=true
                    break
                fi
            done
            if ! $found; then
                echo "✗ ОШИБКА: Не найдено ни одного из: $entry"
                add_result "Конфиг: $entry" "FAIL"
            fi
        else
            if grep -q "$entry" "$config_file"; then
                echo "✓ Найдено: $entry"
                add_result "Конфиг: $entry" "OK"
            else
                echo "✗ ОШИБКА: Не найдено: $entry"
                add_result "Конфиг: $entry" "FAIL"
            fi
        fi
    done

    echo "--- Дополнительные проверки ---"

    local nat_pool_ok=true
    for pool_pattern in "${HQ_RTR_NAT_POOLS[@]}"; do
        if grep -qE "$pool_pattern" "$config_file"; then
            echo "✓ NAT pool найден: $pool_pattern"
            add_result "NAT pool: $pool_pattern" "OK"
        else
            echo "✗ ОШИБКА: NAT pool не найден: $pool_pattern"
            add_result "NAT pool: $pool_pattern" "FAIL"
            nat_pool_ok=false
        fi
    done

    local found_networks=$(grep -c "network.*area 0.0.0.0" "$config_file")
    if [[ $found_networks -ge $HQ_RTR_OSPF_NETWORKS_COUNT_MIN && $found_networks -le $HQ_RTR_OSPF_NETWORKS_COUNT_MAX ]]; then
        echo "✓ Найдено $found_networks OSPF network объявлений"
        add_result "OSPF networks ($found_networks шт.)" "OK"
    else
        echo "✗ ОШИБКА: Ожидалось ${HQ_RTR_OSPF_NETWORKS_COUNT_MIN}-${HQ_RTR_OSPF_NETWORKS_COUNT_MAX} OSPF network, найдено $found_networks"
        add_result "OSPF networks (${HQ_RTR_OSPF_NETWORKS_COUNT_MIN}-${HQ_RTR_OSPF_NETWORKS_COUNT_MAX} шт.)" "FAIL"
    fi

    echo "--- Проверка статических NAT правил ---"

    local hq_nat_success=0
    for nat_rule in "${HQ_RTR_NAT_STATIC[@]}"; do
        if grep -q "$nat_rule" "$config_file"; then
            echo "✓ Найдено: $nat_rule"
            add_result "NAT static: $nat_rule" "OK"
            ((hq_nat_success++))
        else
            echo "✗ ОШИБКА: Не найдено: $nat_rule"
            add_result "NAT static: $nat_rule" "FAIL"
        fi
    done

    if [[ $hq_nat_success -eq ${#HQ_RTR_NAT_STATIC[@]} ]]; then
        echo "Второй модуль выполнен успешно."
    else
        echo "Второй модуль не выполнен успешно или ещё не начат."
    fi
}

# Функция для проверки и настройки FTP сервера
setup_ftp_server() {
    echo "Проверка FTP сервера..."

    if rpm --quiet -q vsftpd; then
        echo "FTP сервер уже установлен"
    else
        echo "Установка FTP сервера..."
        apt-get install vsftpd anonftp lftp net-tools -y
    fi

    if systemctl is-active --quiet vsftpd || systemctl is-active --quiet xinetd; then
        echo "FTP сервер уже запущен"
        return 0
    fi

    echo "Настройка FTP сервера..."

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

    if id "ftpuser" &>/dev/null; then
        echo "Пользователь ftpuser уже существует"
    else
        useradd -m -s /bin/bash ftpuser
        echo "ftpuser:password" | chpasswd
    fi

    mkdir -p /srv/public/pub/
    chown -R ftpuser:ftpuser /srv/public/pub/
    chmod 755 /srv/public/pub/
    chown ftpuser:ftpuser /home/ftpuser/
    mkdir -p /home/ftpuser/srv/public/pub
    chown ftpuser:ftpuser /home/ftpuser/srv/public/pub/
    chmod 755 /home/ftpuser/srv/public/pub/

    if ! grep -q "/srv/public/pub.*/home/ftpuser/srv/public/pub" /etc/fstab; then
        echo -e '/srv/public/pub\t/home/ftpuser/srv/public/pub\tnone\tdefaults,bind\t0\t0' >> /etc/fstab
    fi

    mount -a
    systemctl restart xinetd.service

    echo "FTP сервер настроен и запущен"
}

# === Основная логика ===
apt-get update
setup_ftp_server

wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/new/HQ-RTR-Export-Config.exp

export HQ_RTR_IP=$HQ_RTR_IP
export HQ_SRV_IP_EX="${HQ_SRV_IP%%/*}"

echo "Выполняется скрипт проверки HQ-RTR"
apt-get install wget sshpass -y
grep -q "$HQ_RTR_SSH_HOST" ~/.ssh/known_hosts 2>/dev/null || ssh-keyscan "$HQ_RTR_SSH_HOST" >> ~/.ssh/known_hosts
if ! [ -f "$HQ_RTR_EXPORT_SCRIPT" ]; then
    wget "$HQ_RTR_EXPORT_URL"
fi
expect "$HQ_RTR_EXPORT_SCRIPT"
tar -xvf "$HQ_RTR_CONFIG_ARCHIVE" -C /root/
tar -xvf /root/startup_backup.tar
check_hq_config

# Выводим итоговую таблицу
print_summary_table

echo "Скрипт завершен"
