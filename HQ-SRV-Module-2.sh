#!/bin/bash

# Настройки
LOG_FILE="/var/log/system_check.log"
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

# Выполняем проверки
run_check "Синхронизация времени" "timedatectl | grep 'System clock synchronized: yes'"
run_check "Существование RAID массива" "lsblk | grep md0"
run_check "Файл в NFS директории" "ls /raid/nfs | grep test"
run_check "UUID раздела RAID" "blkid /dev/md0p1"
run_check "Конфигурация mdadm" "cat /etc/mdadm.conf | grep '/dev/md'"
run_check "NFS экспорты" "exportfs -v | grep '/raid/nfs'"
run_check "Доступность веб-сервиса" "curl -s -f http://localhost > /dev/null"

# Дополнительные полезные проверки
run_check "Состояние RAID массива" "cat /proc/mdstat"
run_check "Монтирование NFS" "df -h | grep /raid"
run_check "Службы NFS" "systemctl status nfs-server 2>/dev/null | grep Active: active"

# Итоги
log_and_echo "=== Проверка завершена ==="
log_and_echo "Полный лог сохранен в: $LOG_FILE"
log_and_echo "Для просмотра лога выполните: cat $LOG_FILE"

# Краткий итог
log_and_echo ""
log_and_echo "=== Краткий итог ==="
grep -E "✓|X" "$LOG_FILE"
