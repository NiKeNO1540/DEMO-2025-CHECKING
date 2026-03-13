#!/bin/bash

# Подключаем файл окружения
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Файл для записи результатов
LOG_FILE="system_check_results.txt"

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

# Функция для логирования и вывода
log_and_echo() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Функция проверки доступа в интернет
check_internet_access() {
    log_and_echo "Проверка доступа в интернет..."
    ping -c 2 -W 3 "$DNS_SERVER" > /dev/null 2>&1
    return $?
}

# Функция установки sshpass
install_sshpass() {
    log_and_echo "Установка sshpass..."

    if ! command -v sshpass > /dev/null 2>&1; then
        apt-get install sshpass -y
    fi

    if command -v sshpass > /dev/null 2>&1; then
        log_and_echo "✓ sshpass успешно установлен"
        return 0
    else
        log_and_echo "✗ Ошибка установки sshpass"
        return 1
    fi
}

# Функция настройки SSH подключения
setup_ssh_connection() {
    log_and_echo "Настройка SSH подключения..."

    log_and_echo "Создание SSH ключа + добавление хоста в known_hosts..."
    timeout 10 ssh-keyscan -p "$SSH_PORT" -H "$HQ_SRV_SSH_TARGET" >> ~/.ssh/known_hosts 2>> "$LOG_FILE"
    if ! [ -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q
    else
    log_and_echo "Ключ уже есть."
    fi
    if [ $? -eq 0 ]; then
        log_and_echo "✓ SSH ключ хоста добавлен в known_hosts"
    else
        log_and_echo "✗ Ошибка добавления SSH ключа хоста"
    fi

    log_and_echo "Копирование SSH ключа на удаленный хост..."

    if timeout 10 sshpass -p "$SSH_PASSWORD" ssh-copy-id -p "$SSH_PORT" "$SSH_USER@$HQ_SRV_SSH_TARGET" >> "$LOG_FILE" 2>&1; then
        log_and_echo "✓ SSH ключ успешно скопирован на удаленный хост"
        return 0
    else
        if [ $? -eq 124 ]; then
            log_and_echo "✗ Тайм-аут при копировании SSH ключа (превышено 10 секунд)"
        else
            log_and_echo "✗ Ошибка копирования SSH ключа"
        fi
        return 1
    fi
}

# Очистка старого лог-файла
> "$LOG_FILE"

log_and_echo "=== Начало проверки системы ==="
log_and_echo "Время проверки: $(date)"
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 1"
log_and_echo "Проверка IP адреса:"
ip a | grep "$HQ_SRV_IP" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ IP адрес $HQ_SRV_IP настроен"
    add_result "IP адрес $HQ_SRV_IP" "OK"
else
    log_and_echo "✗ IP адрес $HQ_SRV_IP НЕ настроен"
    add_result "IP адрес $HQ_SRV_IP" "FAIL"
fi
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 2"
log_and_echo "Проверка временной зоны:"
timedatectl | grep "$TIMEZONE" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Временная зона $TIMEZONE установлена"
    add_result "Часовой пояс $TIMEZONE" "OK"
else
    log_and_echo "✗ Временная зона $TIMEZONE НЕ установлена"
    add_result "Часовой пояс $TIMEZONE" "FAIL"
fi
log_and_echo ""

log_and_echo "Проверка hostname:"
hostnamectl | grep "$HQ_SRV_HOSTNAME" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Hostname $HQ_SRV_HOSTNAME установлен"
    add_result "Hostname $HQ_SRV_HOSTNAME" "OK"
else
    log_and_echo "✗ Hostname $HQ_SRV_HOSTNAME НЕ установлен"
    add_result "Hostname $HQ_SRV_HOSTNAME" "FAIL"
fi
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 5"
log_and_echo "Проверка пользователей"
cat /etc/passwd | grep home >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Пользователи с домашними директориями найдены"
    add_result "Пользователи с домашними директориями" "OK"
else
    log_and_echo "✗ Пользователи с домашними директориями не найдены"
    add_result "Пользователи с домашними директориями" "FAIL"
fi
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 6"
log_and_echo "Проверка доступности сетевых узлов:"

for host in "${HQ_SRV_PING_TARGETS[@]}"; do
    log_and_echo "Пинг $host:"
    ping -c 2 "$host" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        log_and_echo "✓ $host - доступен"
        add_result "Пинг $host" "OK"
    else
        log_and_echo "✗ $host - НЕ доступен"
        add_result "Пинг $host" "FAIL"
    fi
done
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 7"
log_and_echo "Проверка DNS разрешения имен:"
ping -c 2 "$DNS_CHECK_HOST" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ DNS разрешение имен работает ($DNS_CHECK_HOST доступен)"
    add_result "DNS разрешение имен ($DNS_CHECK_HOST)" "OK"
else
    log_and_echo "✗ DNS разрешение имен НЕ работает"
    add_result "DNS разрешение имен ($DNS_CHECK_HOST)" "FAIL"
fi
log_and_echo ""

# Проверка службы dnsmasq
log_and_echo "Проверка службы dnsmasq:"
systemctl status dnsmasq | grep -q "Active: active" >> "$LOG_FILE" 2>&1
if [ $? -eq 0 ]; then
    log_and_echo "✓ Служба dnsmasq активна"
    add_result "Служба dnsmasq активна" "OK"
else
    log_and_echo "✗ Служба dnsmasq НЕ активна"
    add_result "Служба dnsmasq активна" "FAIL"
fi
log_and_echo ""

# Проверка конфигурации dnsmasq.conf
log_and_echo "8. Проверка конфигурации $DNSMASQ_CONFIG_FILE:"

if [ -f "$DNSMASQ_CONFIG_FILE" ]; then
    log_and_echo "✓ Файл конфигурации существует"

    missing_configs=0
    for config_line in "${DNSMASQ_EXPECTED[@]}"; do
        if grep -q "$config_line" "$DNSMASQ_CONFIG_FILE"; then
            log_and_echo "✓ Найдена строка: $config_line"
        else
            log_and_echo "✗ Отсутствует строка: $config_line"
            ((missing_configs++))
        fi
    done

    if [ $missing_configs -eq 0 ]; then
        log_and_echo "✓ Все необходимые конфигурационные строки присутствуют"
        add_result "Конфигурация dnsmasq" "OK"
    else
        log_and_echo "✗ Отсутствует $missing_configs конфигурационных строк"
        add_result "Конфигурация dnsmasq" "FAIL"
    fi
else
    log_and_echo "✗ Файл конфигурации $DNSMASQ_CONFIG_FILE не существует"
    add_result "Конфигурация dnsmasq" "FAIL"
fi
log_and_echo ""

# Проверка доступа в интернет и установка sshpass
log_and_echo "Проверка доступа в интернет и настройка SSH:"
if check_internet_access; then
    log_and_echo "✓ Доступ в интернет есть"

    if ! command -v sshpass > /dev/null 2>&1; then
        install_sshpass
    else
        log_and_echo "✓ sshpass уже установлен"
    fi

    if command -v sshpass > /dev/null 2>&1; then
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh

        setup_ssh_connection
    else
        log_and_echo "✗ sshpass недоступен, пропускаем настройку SSH ключей"
    fi
else
    log_and_echo "✗ Доступ в интернет отсутствует, пропускаем установку sshpass"
fi
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 9"
log_and_echo "Проверка SSH подключения:"
log_and_echo "Попытка подключения к $SSH_USER@$HQ_SRV_SSH_TARGET:$SSH_PORT..."

if [ -f ~/.ssh/id_rsa ] || [ -f ~/.ssh/id_ed25519 ]; then
    timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$SSH_USER@$HQ_SRV_SSH_TARGET" -p "$SSH_PORT" exit >> "$LOG_FILE" 2>&1
    ssh_exit_code=$?
else
    if command -v sshpass > /dev/null 2>&1; then
        timeout 10 sshpass -p "$SSH_PASSWORD" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$SSH_USER@$HQ_SRV_SSH_TARGET" -p "$SSH_PORT" exit >> "$LOG_FILE" 2>&1
        ssh_exit_code=$?
    else
        timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$SSH_USER@$HQ_SRV_SSH_TARGET" -p "$SSH_PORT" exit >> "$LOG_FILE" 2>&1
        ssh_exit_code=$?
    fi
fi

if [ $ssh_exit_code -eq 0 ]; then
    log_and_echo "✓ SSH подключение успешно"
    add_result "SSH подключение к $HQ_SRV_SSH_TARGET:$SSH_PORT" "OK"
elif [ $ssh_exit_code -eq 124 ]; then
    log_and_echo "⚠ SSH подключение требует аутентификации (таймаут)"
    add_result "SSH подключение к $HQ_SRV_SSH_TARGET:$SSH_PORT" "FAIL"
else
    log_and_echo "✗ SSH подключение НЕ удалось (код ошибки: $ssh_exit_code)"
    add_result "SSH подключение к $HQ_SRV_SSH_TARGET:$SSH_PORT" "FAIL"
fi

log_and_echo ""
log_and_echo "=== Проверка завершена ==="

print_summary_table | tee -a "$LOG_FILE"

log_and_echo "Подробные результаты сохранены в файл: $LOG_FILE"
