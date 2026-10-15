#!/bin/bash
set -e

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Запустите скрипт с Root правами"
    exit 1
fi

echo "=================================================="
echo " Подготовка к созданию шаблона ВМ"
echo "=================================================="

echo "[1/8] Проверка и установка cloud-init..."
apt-get update -y
apt-get install -y cloud-init

echo "[2/8] Очистка данных и логов cloud-init..."
if command -v cloud-init &> /dev/null; then
    cloud-init clean --logs || true
fi

echo "[3/8] Удаление SSH-ключей хоста..."
rm -f /etc/ssh/ssh_host_*

echo "[4/8] Сброс machine-id..."
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id

echo "[5/8] Сброс hostname на localhost..."
echo "localhost" > /etc/hostname
hostnamectl set-hostname localhost 2>/dev/null || true

echo "[6/8] Очистка системных логов и временных файлов..."
# Очистка journald
journalctl --rotate 2>/dev/null || true
journalctl --vacuum-time=1s 2>/dev/null || true
# Очистка текстовых логов
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \; 2>/dev/null || true
find /var/log -type f -name "*.gz" -delete 2>/dev/null || true
rm -rf /var/log/installer/* /var/log/apt/* /var/log/cloud-init* 2>/dev/null || true
# Очистка tmp
rm -rf /tmp/* /var/tmp/*
rm -rf /root/.cache/* /home/*/.cache/* 2>/dev/null || true

echo "[7/8] Очистка кэша apt-get..."
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[8/8] Очистка истории bash..."
rm -f /root/.bash_history
for userdir in /home/*; do
    if [ -d "$userdir" ]; then
        rm -f "$userdir/.bash_history"
    fi
done
history -c

echo "Включение сервисов cloud-init..."
systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service 2>/dev/null || true

echo "Синхронизация файловой системы..."
sync

echo "=================================================="
echo " Подготовка завершена!"
echo "=================================================="
echo ""
echo "ВАЖНО: Если вы хотите, чтобы cloud-init управлял сетью,"
echo "не забудьте удалить статические настройки сети (например,"
echo "из /etc/net/ или NetworkManager)"
echo "перед выключением машины, иначе они могут конфликтовать."
echo ""
echo "Теперь вы можете выключить ВМ: poweroff"
