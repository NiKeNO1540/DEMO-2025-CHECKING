#!/bin/bash

# Настройки
LOG_FILE="system_check_m2.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

log_and_echo() {
    local message="$1"
    echo "$message" | tee -a "$LOG_FILE"
}

# Функция для выполнения проверки и логирования
run_check() {
    local description="$1"
    local command="$2"
    
    echo "=== $description ===" | tee -a "$LOG_FILE"
    echo "Команда: $command" | tee -a "$LOG_FILE"
    echo "Результат:" | tee -a "$LOG_FILE"
    
    # Выполнение команды с обработкой ошибок
    if eval "$command" 2>&1 | tee -a "$LOG_FILE"; then
        echo "✓ Проверка выполнена успешно" | tee -a "$LOG_FILE"
    else
        echo "X Проверка завершилась с ошибкой" | tee -a "$LOG_FILE"
    fi
    
    echo "" | tee -a "$LOG_FILE"
}

# Очистка старого лог-файла и создание заголовка
echo "=== Результаты проверки системы ===" > "$LOG_FILE"
echo "Время проверки: $TIMESTAMP" >> "$LOG_FILE"
echo "===================================" >> "$LOG_FILE"
echo ""

echo "Начинаем проверку системы..."
echo "Результаты будут сохранены в файл: $LOG_FILE"
echo ""

log_and_echo "=========================================="
log_and_echo "Критерий 1"
run_check "Пинг всех узлов Ansible" "ansible all -m ping"
run_check "Проверка синхронизации системного времени" "timedatectl | grep 'System clock synchronized: yes'"
log_and_echo "=========================================="
log_and_echo "Критерий 3"
run_check "Проверка наличия пользователей в Samba" "samba-tool user list | grep hquser"
run_check "Проверка членов группы HQ в Samba" "samba-tool group listmembers hq"
log_and_echo "=========================================="
log_and_echo "Критерий 4"
run_check "Проверка статуса службы Samba" "systemctl status samba.service | grep 'Active: active'"
log_and_echo "=========================================="
log_and_echo "Критерий 5"
run_check "Проверка SSH подключения к удаленному серверу" "sshpass -p \"P@ssw0rd\" ssh -p 2026 -o ConnectTimeout=10 -o BatchMode=yes sshuser@172.16.1.4 'echo \"SSH connection successful\"'"
run_check "Проверка статуса приложения в Docker" "docker compose -f site.yml logs testapp | grep 'Uvicorn running'"

log_and_echo "=========================================="
log_and_echo "Допольнительные проверки"
run_check "Проверка доступности порта SSH на удаленном сервере" "nc -z -w 5 172.16.1.4 2026 && echo 'Порт 2026 доступен' || echo 'Порт 2026 недоступен'"
run_check "Проверка статуса Docker сервиса" "docker compose -f site.yml ps testapp"
run_check "Проверка использования диска" "df -h / | tail -1"
run_check "Проверка доступной памяти" "free -h"

echo "Проверка завершена!"
echo "Полные результаты сохранены в файл: $LOG_FILE"
echo ""
echo "Краткая сводка:"
grep -E "✓|X" "$LOG_FILE"
