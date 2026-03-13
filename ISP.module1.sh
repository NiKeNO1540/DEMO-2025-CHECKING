#!/bin/bash

# Подключаем файл окружения
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/env.sh"

# Файл для записи результатов
LOG_FILE="system_check_results.txt"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

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

echo "=== Результаты проверки системы - $TIMESTAMP ===" | tee "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Проверка IP адресов
echo "1. Проверка IP адресов:" | tee -a "$LOG_FILE"

echo "Проверка $ISP_IP1:" | tee -a "$LOG_FILE"
if ip a | grep -q "$ISP_IP1"; then
    echo "✓ Найден IP $ISP_IP1" | tee -a "$LOG_FILE"
    add_result "IP адрес $ISP_IP1" "OK"
else
    echo "✗ IP $ISP_IP1 не найден" | tee -a "$LOG_FILE"
    add_result "IP адрес $ISP_IP1" "FAIL"
fi

echo "Проверка $ISP_IP2:" | tee -a "$LOG_FILE"
if ip a | grep -q "$ISP_IP2"; then
    echo "✓ Найден IP $ISP_IP2" | tee -a "$LOG_FILE"
    add_result "IP адрес $ISP_IP2" "OK"
else
    echo "✗ IP $ISP_IP2 не найден" | tee -a "$LOG_FILE"
    add_result "IP адрес $ISP_IP2" "FAIL"
fi

echo "" | tee -a "$LOG_FILE"

# Проверка hostname
echo "2. Проверка hostname:" | tee -a "$LOG_FILE"
if hostnamectl | grep -q "$ISP_HOSTNAME"; then
    echo "✓ Hostname содержит '$ISP_HOSTNAME'" | tee -a "$LOG_FILE"
    hostnamectl | grep -i "static hostname" | tee -a "$LOG_FILE"
    add_result "Hostname $ISP_HOSTNAME" "OK"
else
    echo "✗ Hostname не содержит '$ISP_HOSTNAME'" | tee -a "$LOG_FILE"
    hostnamectl | grep -i "static hostname" | tee -a "$LOG_FILE"
    add_result "Hostname $ISP_HOSTNAME" "FAIL"
fi

echo "" | tee -a "$LOG_FILE"

# Проверка временной зоны
echo "3. Проверка временной зоны:" | tee -a "$LOG_FILE"
if timedatectl | grep -q "$TIMEZONE"; then
    echo "✓ Временная зона установлена: $TIMEZONE" | tee -a "$LOG_FILE"
    add_result "Часовой пояс $TIMEZONE" "OK"
else
    echo "✗ Временная зона не установлена на $TIMEZONE" | tee -a "$LOG_FILE"
    timedatectl | grep "Time zone" | tee -a "$LOG_FILE"
    add_result "Часовой пояс $TIMEZONE" "FAIL"
fi

echo "" | tee -a "$LOG_FILE"
echo "Подробная информация о времени:" | tee -a "$LOG_FILE"
timedatectl | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "=== Проверка завершена ===" | tee -a "$LOG_FILE"

# Выводим итоговую таблицу
print_summary_table | tee -a "$LOG_FILE"

echo "Результаты сохранены в файл: $LOG_FILE" | tee -a "$LOG_FILE"
