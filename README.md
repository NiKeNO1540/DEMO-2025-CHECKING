# DEMO-2025-CHECKING

Проверка осуществляется скриптами, но перед этим на проверке любого модуля нужно сделать допольнительные конфигурации. Именно для возможности запуска скрипта:

### BR-RTR | HQ-RTR

```tcl
en
conf
no security default
end
wr
```

> Отключается профиль безопасности, который блокирует SSH-Подключения на роутерах. И на этом вся преднастройка закончена.

## Активация проверки

### Установка утилиты wget

```bash
apt-get update && apt-get install wget -y
```

### Скачивание и запуск скрипта

```bash
wget [Ссылка] && chmod +x [Название файла] && ./[Название файла]
```

> Уточнение: Ссылка должна быть raw версией, нужно всего лишь на определенном файле скрипта нажать эту кнопку(Кнопка "raw"):
> <img width="1177" height="180" alt="image" src="https://github.com/user-attachments/assets/057dae3f-31cb-46fe-a184-4082e65492b5" />
> Затем скопировать ссылку и вставить.

# Вставки

<details>
<summary>HQ-SRV</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-SRV-Module-1.sh
chmod +x HQ-SRV-Module-1.sh && ./HQ-SRV-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-SRV-Module-2.sh
chmod +x HQ-SRV-Module-2.sh && ./HQ-SRV-Module-2.sh
```

</details>

<details>
<summary>BR-SRV</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/BR-SRV-Module-1.sh
chmod +x BR-SRV-Module-1.sh && ./BR-SRV-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/BR-SRV-Module-2.sh
chmod +x BR-SRV-Module-2.sh && ./BR-SRV-Module-2.sh
```

</details>

<details>
<summary>HQ-CLI</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-CLI-Module-1.sh
chmod +x HQ-CLI-Module-1.sh && ./HQ-CLI-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/HQ-CLI-Module-2.sh
chmod +x HQ-CLI-Module-2.sh && ./HQ-CLI-Module-2.sh
```

</details>

<details>
<summary>HQ-RTR</summary>

### HQ-RTR

```tcl
en
conf
no security default
end
wr
```

### Первый модуль [ЗАПУСКАЕТСЯ НА HQ-SRV]

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

### Второй модуль [ЗАПУСКАЕТСЯ НА HQ-SRV]

### HQ-RTR

```tcl
en
conf
no security default
end
wr
```

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

</details>

<details>
<summary>BR-RTR</summary>

### Первый модуль [ЗАПУСКАЕТСЯ НА BR-SRV]

### BR-RTR

```tcl
en
conf
no security default
end
wr
```

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

### Второй модуль [ЗАПУСКАЕТСЯ НА BR-SRV]

### BR-RTR

```tcl
en
conf
no security default
end
wr
```

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/Uni_export_v2.sh
chmod +x Uni_export_v2.sh && ./Uni_export_v2.sh
```

</details>

<details>
<summary>ISP</summary>

### Первый модуль

```bash
apt-get update && apt-get install wget -y
wget https://raw.githubusercontent.com/NiKeNO1540/DEMO-2025-CHECKING/refs/heads/main/ISP-Module-1.sh
chmod +x ISP-Module-1.sh && ./ISP-Module-1.sh
```

### Второй модуль

```bash
apt-get update && apt-get install wget -y
wget placeholder
chmod +x ISP-Module-2.sh && ./ISP-Module-2.sh
```

</details>
