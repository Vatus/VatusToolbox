#!/bin/bash

# ==================== Env ====================
SCREEN_NAME="minecraft"          # Имя сессии screen, в которой запущен сервер
SERVER_DIR="/opt/minecraft"      # Путь к корневой папке сервера
WORLD_NAME="world"               # Название папки с миром 
BACKUP_DIR="/mnt/w_backups" # Папка для хранения бэкапов

LOG_FILE="/mnt/w_backups/logs/backup.log" # Файл логов. Если не хотите хронить фалйы логов, то просто укажите /dev/null
RETENTION_DAYS=7                 # Сколько дней хранить бэкапы (старые будут удаляться)
SAVE_WAIT_TIME=20                # Время на ожидание завершения сохранения мира

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="${BACKUP_DIR}/world_backup_${TIMESTAMP}.zip"

# Функция для логирования
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Функция необходима для гарантированного включения сохранения данных на диск
cleanup() {
    log "Включаю автосохранение (save-on)..."
    screen -S "$SCREEN_NAME" -p 0 -X stuff "save-on$(printf '\r')"
    log "Автосохранение включено."
}

# Устанавливаем trap: функция cleanup выполнится при ЛЮБОМ выходе из скрипта
trap cleanup EXIT


if ! screen -list | grep -q "$SCREEN_NAME"; then
    log "ОШИБКА: Сессия screen '$SCREEN_NAME' не найдена! Бэкап отменен."
    # Выход с ошибкой, но trap все равно выполнит save-on 
    exit 1
fi


mkdir -p "$BACKUP_DIR"

log "Начало резервного копирования мира '$WORLD_NAME'..."

#Отключаем автосохранение
log "Отключаю автосохранение (save-off)..."
screen -S "$SCREEN_NAME" -p 0 -X stuff "save-off$(printf '\r')"

#Принудительно сохраняем мир
log "Выполняю принудительное сохранение (save-all)..."
screen -S "$SCREEN_NAME" -p 0 -X stuff "save-all$(printf '\r')"

#Сбрасываем чанки на диск
log "Ожидание $SAVE_WAIT_TIME секунд для завершения сохранения..."
sleep "$SAVE_WAIT_TIME"

# Архивируем
log "Создание архива $BACKUP_FILE..."
cd "$SERVER_DIR" || exit 1
if zip -rq "$BACKUP_FILE" "$WORLD_NAME"; then
    log "Архив успешно создан. Размер: $(du -h "$BACKUP_FILE" | cut -f1)"
else
    log "ОШИБКА: Не удалось создать архив!"
fi

#Выполняем ротацию
log "Удаление бэкапов старше $RETENTION_DAYS дней..."
find "$BACKUP_DIR" -type f -name "*.zip" -mtime +$RETENTION_DAYS -exec rm -f {} \;
log "Очистка старых бэкапов завершена."

log "=== Процесс резервного копирования завершен ==="
