#!/bin/bash

# Подключаем файл окружения
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Файл для записи результатов
LOG_FILE="/var/log/system_check_results.txt"

# Очистка файла перед началом проверки
> "$LOG_FILE"

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

# Функция для записи и вывода результатов
log_and_echo() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Функция для выполнения команды и записи результата
execute_check() {
    local description="$1"
    local command="$2"

    log_and_echo "=========================================="
    log_and_echo "Проверка: $description"
    log_and_echo "Команда: $command"
    log_and_echo "------------------------------------------"

    # Выполнение команды и запись результата
    eval "$command" >> "$LOG_FILE" 2>&1
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_and_echo "Результат: УСПЕХ"
        add_result "$description" "OK"
    else
        log_and_echo "Результат: ОШИБКА (код: $exit_code)"
        add_result "$description" "FAIL"
    fi

    log_and_echo ""
}

log_and_echo "Начало проверки системы - $(date)"
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 1"
execute_check "IP адрес $HQ_CLI_IP" "ip a | grep $HQ_CLI_IP"

log_and_echo "=========================================="
log_and_echo "Критерий 2"
execute_check "Часовой пояс $TIMEZONE" "timedatectl | grep $TIMEZONE"
execute_check "Hostname $HQ_CLI_HOSTNAME" "hostnamectl | grep $HQ_CLI_HOSTNAME"

log_and_echo "=========================================="
log_and_echo "Критерий 5"
execute_check "Пользователи с домашними директориями" "cat /etc/passwd | grep home"

log_and_echo "=========================================="
log_and_echo "Критерий 6"
for target in "${HQ_CLI_PING_TARGETS[@]}"; do
    execute_check "Пинг $target" "ping $target -c 2"
done
execute_check "Пинг $DNS_CHECK_HOST (проверка DNS)" "ping $DNS_CHECK_HOST -c 2"

log_and_echo "=========================================="
log_and_echo "Проверка завершена - $(date)"

# Выводим итоговую таблицу
print_summary_table | tee -a "$LOG_FILE"

log_and_echo "Результаты сохранены в файл: $LOG_FILE"
