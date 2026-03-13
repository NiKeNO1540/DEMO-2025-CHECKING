#!/bin/bash

# Подключаем файл окружения
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Файл для записи результатов
LOG_FILE="/var/log/system_check.log"
> "$LOG_FILE"  # Очищаем файл перед началом записи

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

# Функция для вывода и записи в лог
log_and_echo() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Функция для выполнения команд и записи результатов
execute_check() {
    local description="$1"
    local command="$2"

    log_and_echo "=== $description ==="
    log_and_echo "Команда: $command"

    # Выполняем команду и захватываем вывод
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?

    echo "$output" >> "$LOG_FILE"
    echo "$output"

    if [ $exit_code -eq 0 ]; then
        log_and_echo "✓ УСПЕХ"
        add_result "$description" "OK"
    else
        log_and_echo "✗ ОШИБКА (код: $exit_code)"
        add_result "$description" "FAIL"
    fi

    log_and_echo ""
}

log_and_echo "Начало проверки системы - $(date)"
log_and_echo "=========================================="
log_and_echo "Критерий 1: IP-Адресация"

execute_check "IP адрес $BR_SRV_IP" "ip a | grep $BR_SRV_IP"

log_and_echo "=========================================="
log_and_echo "Критерий 2: Проверка временной зоны и имя устройства"

execute_check "Часовой пояс $TIMEZONE" "timedatectl | grep $TIMEZONE"
execute_check "Hostname $BR_SRV_HOSTNAME" "hostnamectl | grep $BR_SRV_HOSTNAME"

log_and_echo "=========================================="
log_and_echo "Критерий 5: Проверка пользователей"

execute_check "Пользователи с /home" "cat /etc/passwd | grep home"

log_and_echo "=========================================="
log_and_echo "Шестой критерий: Сетевая связность"
for target in "${BR_SRV_PING_TARGETS[@]}"; do
    execute_check "Ping $target" "ping -c 2 $target"
done

log_and_echo "=========================================="
log_and_echo "Критерий 9: Проверка SSH-связности."

execute_check "Ping $DNS_CHECK_HOST (проверка DNS)" "ping -c 2 $DNS_CHECK_HOST"

# Проверка доступности интернета для установки sshpass
log_and_echo "=== Проверка доступности интернета для установки sshpass ==="
if ping -c 2 "$DNS_SERVER" &> /dev/null; then
    log_and_echo "Интернет доступен, проверяем установку sshpass..."

    if ! command -v sshpass &> /dev/null; then
        log_and_echo "Установка sshpass..."
        apt-get update && apt-get install sshpass -y
    else
        log_and_echo "sshpass уже установлен"
    fi

    if command -v sshpass &> /dev/null; then
        log_and_echo "=== Настройка SSH ключей ==="

        execute_check "Добавление SSH хоста в known_hosts" "timeout 10 ssh-keyscan -p $SSH_PORT -H $BR_SRV_SSH_TARGET >> ~/.ssh/known_hosts"

        if ! [ -f ~/.ssh/id_rsa.pub ]; then
        execute_check "Создание RSA ключа для копирования" "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q"
        else
        log_and_echo "Ключ уже есть."
        fi

        execute_check "Копирование SSH ключа" "timeout 10 sshpass -p \"$SSH_PASSWORD\" ssh-copy-id -o ConnectTimeout=5 -p $SSH_PORT $SSH_USER@$BR_SRV_SSH_TARGET"
    else
        log_and_echo "Не удалось установить sshpass, пропускаем настройку SSH ключей"
    fi
else
    log_and_echo "Интернет недоступен, пропускаем установку sshpass"
fi

log_and_echo "Команда: ssh $SSH_USER@$BR_SRV_SSH_TARGET -p $SSH_PORT"
log_and_echo "Выполняется тестовое SSH подключение (timeout 10s)..."

if timeout 10s ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$SSH_PORT" "$SSH_USER@$BR_SRV_SSH_TARGET" "echo 'SSH подключение успешно'" 2>> "$LOG_FILE"; then
    log_and_echo "✓ SSH подключение УСПЕШНО"
    add_result "SSH подключение к $BR_SRV_SSH_TARGET:$SSH_PORT" "OK"
else
    log_and_echo "✗ SSH подключение НЕ УДАЛОСЬ"
    add_result "SSH подключение к $BR_SRV_SSH_TARGET:$SSH_PORT" "FAIL"
fi

log_and_echo ""
log_and_echo "=========================================="
log_and_echo "Проверка завершена - $(date)"

print_summary_table | tee -a "$LOG_FILE"

log_and_echo "Полный лог сохранен в файл: $LOG_FILE"
