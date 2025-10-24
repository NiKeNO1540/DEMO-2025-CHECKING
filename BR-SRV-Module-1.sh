#!/bin/bash

# Файл для записи результатов
LOG_FILE="system_check.log"
> "$LOG_FILE"  # Очищаем файл перед началом записи

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
    else
        log_and_echo "✗ ОШИБКА (код: $exit_code)"
    fi
    
    log_and_echo ""
}

log_and_echo "Начало проверки системы - $(date)"
log_and_echo "=========================================="

# Проверка IP адреса
execute_check "Проверка IP адреса 192.168.3.10/28" "ip a | grep 192.168.3.10/28"

# Проверка временной зоны
execute_check "Проверка временной зоны" "timedatectl | grep Asia/Yekaterinburg"

# Проверка hostname
execute_check "Проверка hostname" "hostnamectl | grep br-srv.au-team.irpo"

# Проверка пользователей с домашними директориями
execute_check "Проверка пользователей с /home" "cat /etc/passwd | grep home"

# Проверка доступности сетевых узлов
execute_check "Ping 192.168.3.1" "ping -c 2 192.168.3.1"
execute_check "Ping 192.168.2.10" "ping -c 2 192.168.2.10"
execute_check "Ping 172.16.2.1" "ping -c 2 172.16.2.1"
execute_check "Ping 192.168.1.10" "ping -c 2 192.168.1.10"
execute_check "Ping 8.8.8.8" "ping -c 2 8.8.8.8"

# Проверка DNS разрешения имен
execute_check "Ping ya.ru (проверка DNS)" "ping -c 2 ya.ru"

# Проверка доступности интернета для установки sshpass
log_and_echo "=== Проверка доступности интернета для установки sshpass ==="
if ping -c 2 8.8.8.8 &> /dev/null; then
    log_and_echo "Интернет доступен, проверяем установку sshpass..."
    
    # Проверяем установлен ли sshpass
    if ! command -v sshpass &> /dev/null; then
        log_and_echo "Установка sshpass..."
        
        # Определяем пакетный менеджер
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y sshpass
        elif command -v yum &> /dev/null; then
            yum install -y sshpass
        elif command -v dnf &> /dev/null; then
            dnf install -y sshpass
        else
            log_and_echo "Не удалось определить пакетный менеджер для установки sshpass"
        fi
    else
        log_and_echo "sshpass уже установлен"
    fi
    
    # Проверяем успешность установки sshpass
    if command -v sshpass &> /dev/null; then
        log_and_echo "=== Настройка SSH ключей ==="
        
        # Добавляем хост в known_hosts
        execute_check "Добавление SSH хоста в known_hosts" "ssh-keyscan -p 2026 -H 192.168.1.10 >> ~/.ssh/known_hosts"

        # Добавление ключа
        if ! [ -f ~/.ssh/id_rsa.pub ]; then
        execute_check "Создание RSA ключа для копирования" "ssh-keygen -t rsa -b 4096 -N '' -f ~/.ssh/id_rsa -q"
        else
        log_and_echo "Ключ уже есть."
        fi
        
        # Копируем SSH ключ
        execute_check "Копирование SSH ключа" "sshpass -p \"P@ssw0rd\" ssh-copy-id -p 2026 sshuser@192.168.1.10"
    else
        log_and_echo "Не удалось установить sshpass, пропускаем настройку SSH ключей"
    fi
else
    log_and_echo "Интернет недоступен, пропускаем установку sshpass"
fi

# Проверка SSH подключения
log_and_echo "=== Проверка SSH подключения ==="
log_and_echo "Команда: ssh sshuser@192.168.1.10 -p 2026"
log_and_echo "Выполняется тестовое SSH подключение (timeout 10s)..."

# Тестовое SSH подключение с таймаутом
if timeout 10s ssh -o ConnectTimeout=5 -o BatchMode=yes -p 2026 sshuser@192.168.1.10 "echo 'SSH подключение успешно'" 2>> "$LOG_FILE"; then
    log_and_echo "✓ SSH подключение УСПЕШНО"
else
    log_and_echo "✗ SSH подключение НЕ УДАЛОСЬ"
fi

log_and_echo ""
log_and_echo "=========================================="
log_and_echo "Проверка завершена - $(date)"
log_and_echo "Полный лог сохранен в файл: $LOG_FILE"

# Выводим итоговую информацию о лог-файле
echo ""
echo "Последние строки лог-файла:"
tail -20 "$LOG_FILE"
