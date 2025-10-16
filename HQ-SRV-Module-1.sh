#!/bin/bash

# Файл для записи результатов
LOG_FILE="system_check_results.txt"
CONFIG_FILE="/etc/dnsmasq.conf"
EXPECTED_CONFIG=(
    "domain=au-team.irpo"
    "server=8.8.8.8"
    "address=/hq-rtr.au-team.irpo/192.168.1.1"
    "server=/au-team.irpo/192.168.3.10"
    "ptr-record=1.1.168.192.in-addr.arpa,hq-rtr.au-team.irpo"
    "address=/web.au-team.irpo/172.16.1.1"
    "address=/docker.au-team.irpo/172.16.2.1"
    "address=/br-rtr.au-team.irpo/192.168.3.1"
    "address=/hq-srv.au-team.irpo/192.168.1.10"
    "ptr-record=10.1.168.192.in-addr.arpa,hq-srv.au-team.irpo"
    "address=/hq-cli.au-team.irpo/192.168.2.10"
    "ptr-record=10.2.168.192.in-addr.arpa,hq-cli.au-team.irpo"
    "address=/br-srv.au-team.irpo/192.168.3.10"
)

# Функция для логирования и вывода
log_and_echo() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Очистка старого лог-файла
> "$LOG_FILE"

log_and_echo "=== Начало проверки системы ==="
log_and_echo "Время проверки: $(date)"
log_and_echo ""

# Проверка IP адреса
log_and_echo "1. Проверка IP адреса:"
ip -c a | grep 192.168.1.10/27 >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ IP адрес 192.168.1.10/27 настроен"
else
    log_and_echo "✗ IP адрес 192.168.1.10/27 НЕ настроен"
fi
log_and_echo ""

# Проверка временной зоны
log_and_echo "2. Проверка временной зоны:"
timedatectl | grep "Asia/Yekaterinburg" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Временная зона Asia/Yekaterinburg установлена"
else
    log_and_echo "✗ Временная зона Asia/Yekaterinburg НЕ установлена"
fi
log_and_echo ""

# Проверка hostname
log_and_echo "3. Проверка hostname:"
hostnamectl | grep "hq-srv.au-team.irpo" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Hostname hq-srv.au-team.irpo установлен"
else
    log_and_echo "✗ Hostname hq-srv.au-team.irpo НЕ установлен"
fi
log_and_echo ""

# Проверка домашних директорий
log_and_echo "4. Проверка пользователей с домашними директориями:"
cat /etc/passwd | grep home >> "$LOG_FILE" 2>&1
log_and_echo "✓ Список пользователей с домашними директориями записан в лог"
log_and_echo ""

# Проверка доступности сетевых узлов
log_and_echo "5. Проверка доступности сетевых узлов:"

ping_hosts=(
    "192.168.1.1"
    "192.168.2.10" 
    "172.16.1.1"
    "192.168.3.10"
    "8.8.8.8"
)

for host in "${ping_hosts[@]}"; do
    log_and_echo "Пинг $host:"
    ping -c 2 "$host" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_and_echo "✓ $host - доступен"
    else
        log_and_echo "✗ $host - НЕ доступен"
    fi
done
log_and_echo ""

# Проверка DNS через ping ya.ru
log_and_echo "6. Проверка DNS разрешения имен:"
ping -c 2 ya.ru >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ DNS разрешение имен работает (ya.ru доступен)"
else
    log_and_echo "✗ DNS разрешение имен НЕ работает"
fi
log_and_echo ""

# Проверка службы dnsmasq
log_and_echo "7. Проверка службы dnsmasq:"
systemctl status dnsmasq >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Служба dnsmasq активна"
else
    log_and_echo "✗ Служба dnsmasq НЕ активна"
fi
log_and_echo ""

# Проверка конфигурации dnsmasq.conf
log_and_echo "8. Проверка конфигурации $CONFIG_FILE:"

if [ -f "$CONFIG_FILE" ]; then
    log_and_echo "✓ Файл конфигурации существует"
    
    missing_configs=0
    for config_line in "${EXPECTED_CONFIG[@]}"; do
        if grep -q "$config_line" "$CONFIG_FILE"; then
            log_and_echo "✓ Найдена строка: $config_line"
        else
            log_and_echo "✗ Отсутствует строка: $config_line"
            ((missing_configs++))
        fi
    done
    
    if [ $missing_configs -eq 0 ]; then
        log_and_echo "✓ Все необходимые конфигурационные строки присутствуют"
    else
        log_and_echo "✗ Отсутствует $missing_configs конфигурационных строк"
    fi
else
    log_and_echo "✗ Файл конфигурации $CONFIG_FILE не существует"
fi
log_and_echo ""

# Проверка SSH подключения
log_and_echo "9. Проверка SSH подключения:"
log_and_echo "Попытка подключения к sshuser@192.168.3.10:2026..."
# Используем timeout чтобы не зависнуть при запросе пароля
timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no sshuser@192.168.3.10 -p 2026 exit >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    log_and_echo "✓ SSH подключение успешно"
elif [ $? -eq 124 ]; then
    log_and_echo "⚠ SSH подключение требует аутентификации (таймаут)"
else
    log_and_echo "✗ SSH подключение НЕ удалось"
fi

log_and_echo ""
log_and_echo "=== Проверка завершена ==="
log_and_echo "Подробные результаты сохранены в файл: $LOG_FILE"

# Вывод итоговой информации
echo ""
echo "=== Краткие результаты проверки ==="
tail -n 50 "$LOG_FILE" | grep -E "^(✓|✗|⚠)"
