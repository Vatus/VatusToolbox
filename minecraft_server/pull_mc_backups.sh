# Скрипт для ежедневного сбора резевных копий с удаленного сервера 
# В скрипт была встроена собственная ротация логов и файлов резервных копий. 

# при запуске через коронтаб перенапрявь вывод и ошибки в /dev/null
# пример для crontab: 0 5 * * * * /home/user/pull_mc_backups.sh >/dev/null 2>&1

REMOTE_USER="user" #Имя удаленного пользователя
REMOTE_HOST="*.*.*.*" #IP вашего сервера
SSH_KEY="/home/user/.ssh/id_ed25519" #Путь до файла закрытого ssh ключа
REMOTE_DIR="/mnt/w_backups" # Каталог на удаленном сервере, где лежат резервные копии
LOCAL_DIR="/var/w_backups" # Куда поместить резервную копию на локальном хосте

# Настройки логирования и ротации
LOG_FILE="${LOCAL_DIR}/backup_script.log"
DAYS_TO_KEEP=7 # за сколько дней на м нужно сохранять копии

#Настройки ротации логов
MAX_LOG_SIZE_MB=50
LOG_ROTATE_COUNT=3   
MAX_LOG_SIZE=$((MAX_LOG_SIZE_MB * 1024 * 1024)) # Переводим МБ в байты


#РОТАЦИЯ ЛОГ-ФАЙЛА
if [ -f "$LOG_FILE" ]; then

    CURRENT_SIZE=$(wc -c < "$LOG_FILE")

    if [ "$CURRENT_SIZE" -gt "$MAX_LOG_SIZE" ]; then
        #Сдвигаем старые архивы (например, .2.gz становится .3.gz)
        for i in $(seq $((LOG_ROTATE_COUNT - 1)) -1 1); do
            if [ -f "${LOG_FILE}.${i}.gz" ]; then
                mv "${LOG_FILE}.${i}.gz" "${LOG_FILE}.$((i + 1)).gz"
            fi
        done

        #Удаляем самый старый архив, если он вышел за пределы LOG_ROTATE_COUNT
        rm -f "${LOG_FILE}.${LOG_ROTATE_COUNT}.gz"

        #Архивируем текущий лог
        gzip -c "$LOG_FILE" > "${LOG_FILE}.1.gz"

        #Очищаем текущий лог
        > "$LOG_FILE"
    fi
fi

# ЛОГИРОВАНИЕ
# Перенаправляем весь вывод в лог-файл и на экран 
exec > >(tee -a "$LOG_FILE") 2>&1

echo "===================================================="
echo "ЗАПУСК СКРИПТА: $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================="

# Создаем локальную папку, если ее нет
mkdir -p "$LOCAL_DIR"

#ПОЛУЧЕНИЕ ДАТЫ С УДАЛЕННОГО СЕРВЕРА
echo "[INFO] Подключение к удаленному серверу для получения даты..."
REMOTE_DATE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}" "date +%F")

if [ -z "$REMOTE_DATE" ]; then
    echo "[ERROR] Не удалось получить дату с удаленного сервера. Проверьте сеть или SSH-ключ. Прерывание."
    exit 1
fi
echo "[INFO] Дата на удаленном сервере: $REMOTE_DATE"


echo "[INFO] Начинаем скачивание бэкапов за $REMOTE_DATE..."
scp -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/world_backup_${REMOTE_DATE}_*.zip" "${LOCAL_DIR}/"

if [ $? -eq 0 ]; then
    echo "[SUCCESS] Скачивание успешно завершено."
else
    echo "[WARNING] Скачивание завершилось с кодом ошибки (возможно, бэкапов за сегодня еще нет или они не создались)."
fi

#РОТАЦИЯ ФАЙЛОВ 
echo "[INFO] Запуск ротации бэкапов: удаление файлов старше $DAYS_TO_KEEP дней..."

# Находим файлы по маске, которые были изменены более DAYS_TO_KEEP дней назад,
# печатаем их имена в лог и удаляем
find "$LOCAL_DIR" -type f -name "world_backup_*.zip" -mtime +${DAYS_TO_KEEP} -print -delete | while read -r file; do
    echo "[ROTATION] Удален старый бэкап: $file"
done

echo "[INFO] Ротация бэкапов завершена."

echo "===================================================="
echo "СКРИПТ ЗАВЕРШЕН: $(date '+%Y-%m-%d %H:%M:%S')"
echo "===================================================="
