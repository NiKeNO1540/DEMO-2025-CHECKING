#!/bin/bash

# Настройки
LOG_FILE="/var/log/system_check_m2.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Функция для логирования и вывода
log_and_echo() {
    local message="$1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Функция для выполнения проверки
run_check() {
    local name="$1"
    local command="$2"
    
    log_and_echo "=== Проверка: $name ==="
    log_and_echo "Команда: $command"
    log_and_echo "Результат:"
    
    # Выполняем команду и логируем результат
    if eval "$command" >> "$LOG_FILE" 2>&1; then
        log_and_echo "✓ Успешно"
    else
        log_and_echo "X Ошибка или условие не выполнено"
    fi
    log_and_echo ""
}

# Создаем файл лога
echo "=== Проверка системы $TIMESTAMP ===" > "$LOG_FILE"

log_and_echo "Начинаем проверку системы..."
log_and_echo "Лог будет сохранен в: $LOG_FILE"
log_and_echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 1"
run_check "Проверка сетевой службы NTP" "chronyc clients | grep -e '172.16.1.4' -e '172.16.2.5'"
if command -v curl > /dev/null; then
run_check "Проверка работоспособности сайта на HQ-SRV" "curl -I http://172.16.1.1"
run_check "Проверка работоспособности сайта на BR-SRV" "curl -I http://172.16.2.1"
else
apt-get update && apt-get install curl -y
run_check "Проверка работоспособности сайта на HQ-SRV" "curl -I http://172.16.1.1"
run_check "Проверка работоспособности сайта на BR-SRV" "curl -I http://172.16.2.1"
fi
