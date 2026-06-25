
#!/bin/bash

# Жесткий контроль ошибок
set -euo pipefail

TIME=$(date +%F_%H-%M)
ARCHIVE_NAME="vps_adguhom_$TIME.tar.gz"
TMP_DIR="/tmp/backup_work"
REMOTE="gdrive:VPS_Backups"
LOG_FILE="/var/log/backup.log"

# Автоопределение rclone (если не найден — упадёт)
RCLONE_PATH=$(command -v rclone || { echo "rclone not found" >&2; exit 1; })

# Ротация лога, если >10 МБ
if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt 10485760 ]]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
fi

echo "[$(date)] --- Начало бэкапа ---" >> "$LOG_FILE"

# Зачищаем папку от возможных старых ошметков
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Копируем данные (с игнорированием ошибок, чтобы скрипт не падал)
cp -r /var/www/ "$TMP_DIR/" 2>/dev/null || true
cp -r /etc/nginx/ "$TMP_DIR/" 2>/dev/null || true
cp -r /etc/wireguard/ "$TMP_DIR/" 2>/dev/null || true
cp -r /usr/local/x-ui/ "$TMP_DIR/" 2>/dev/null || true
cp -r /opt/AdGuardHome/ "$TMP_DIR/" 2>/dev/null || true

# Упаковка
tar -czf "/tmp/$ARCHIVE_NAME" -C /tmp backup_work >> "$LOG_FILE" 2>&1

# Отправка на Google Drive
if ! $RCLONE_PATH copy "/tmp/$ARCHIVE_NAME" "$REMOTE" >> "$LOG_FILE" 2>&1; then
    echo "[$(date)] ❌ Ошибка отправки бэкапа!" >> "$LOG_FILE"
    rm -rf "$TMP_DIR" "/tmp/$ARCHIVE_NAME"
    exit 1
fi

# Удаляем старые бэкапы (оставляем 7 последних)
count=$($RCLONE_PATH lsf "$REMOTE" | wc -l)
if [ "$count" -gt 7 ]; then
    to_delete=$((count - 7))
    
    # Временно отключаем pipefail, чтобы SIGPIPE от head не прибил скрипт
    set +o pipefail
    $RCLONE_PATH lsf "$REMOTE" | sort | head -n "$to_delete" | while IFS= read -r old; do
        $RCLONE_PATH delete "$REMOTE/$old" >> "$LOG_FILE" 2>&1
        echo "[$(date)] 🗑️ Удалён старый бэкап: $old" >> "$LOG_FILE"
    done
    set -o pipefail
fi

# Очистка временных файлов
rm -rf "$TMP_DIR" "/tmp/$ARCHIVE_NAME"

echo "[$(date)] ✅ Бэкап создан успешно." >> "$LOG_FILE"
