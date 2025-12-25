e#!/bin/bash

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
run_check "Проверка Установленного Яндекса" "command -v yandex-browser-stable"
run_check "Проверка NTP-связности" "timedatectl | grep 'System clock synchronized: yes'"

log_and_echo "=========================================="
log_and_echo "Критерий 3"
run_check "Проверка Клиентской части" "sudo -l -U hquser1 | grep '/usr/bin/id'"

log_and_echo "=========================================="
log_and_echo "Критерий 4"
run_check "ID-проверка" "id administrator"
if ! klist | grep "administrator@AU-TEAM.IRPO"; then
log_and_echo "Логирование под администратора"
echo "P@ssw0rd" | kinit administrator
run_check "Проверка билетов Kerberos" "klist"
else
run_check "Проверка билетов Kerberos" "klist"
fi


log_and_echo "=========================================="
log_and_echo "Критерий 5"
run_check "Доступность веб-сервиса на BR-SRV" "curl -I http://172.16.2.1 | grep nginx"
run_check "Доступность веб-сервиса на BR-SRV с входом" "curl -I -s -f -u WEB:P@ssw0rd http://172.16.2.1"
run_check "Доступность веб-сервиса на HQ-SRV через прокси" "curl -I -u WEB:P@ssw0rd -s -f http://web.au-team.irpo"
run_check "Доступность веб-сервиса на BR-SRV через прокси" "curl -I -s -f http://docker.au-team.irpo"
