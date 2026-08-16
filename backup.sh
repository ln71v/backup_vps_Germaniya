#!/bin/bash
# Жесткий контроль ошибок
set -euo pipefail

TIME=$(date +%F_%H-%M)
ARCHIVE_NAME="vps_adguhom_$TIME.tar.gz"
ENC_ARCHIVE_NAME="$ARCHIVE_NAME.gpg"
REMOTE="gdrive:VPS_Backups"
LOG_FILE="/var/log/backup.log"
PASS_FILE="/root/.backup_passphrase"
KEEP=7

# Автоопределение rclone (если не найден — упадёт)
RCLONE_PATH=$(command -v rclone || { echo "rclone not found" >&2; exit 1; })

# Проверка файла с паролем шифрования (должен существовать и быть закрыт от чужих глаз)
if [[ ! -f "$PASS_FILE" ]]; then
    echo "[$(date)] ❌ Не найден файл пароля $PASS_FILE" >> "$LOG_FILE"
    exit 1
fi
PERM=$(stat -c%a "$PASS_FILE")
if [[ "$PERM" != "600" && "$PERM" != "400" ]]; then
    echo "[$(date)] ❌ Небезопасные права на $PASS_FILE ($PERM), должно быть 600" >> "$LOG_FILE"
    exit 1
fi

# Ротация лога, если >10 МБ
if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -gt 10485760 ]]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
fi

# Уникальная временная директория + гарантированная очистка при любом выходе
TMP_DIR=$(mktemp -d /tmp/backup_work.XXXXXX)
cleanup() {
    rm -rf "$TMP_DIR" "/tmp/$ARCHIVE_NAME" "/tmp/$ENC_ARCHIVE_NAME"
}
trap cleanup EXIT

echo "[$(date)] --- Начало бэкапа ---" >> "$LOG_FILE"

# Копируем данные. Ошибки не глушим в /dev/null — пишем в лог, но не роняем скрипт,
# т.к. часть директорий может законно отсутствовать.
for dir in /var/www /etc/nginx /etc/wireguard /usr/local/x-ui /opt/AdGuardHome; do
    if [[ -d "$dir" ]]; then
        mkdir -p "$TMP_DIR$(dirname "$dir")"
        if ! cp -r "$dir" "$TMP_DIR$dir" 2>>"$LOG_FILE"; then
            echo "[$(date)] ⚠️ Ошибка копирования $dir" >> "$LOG_FILE"
        fi
    else
        echo "[$(date)] ⚠️ Директория $dir не найдена, пропуск" >> "$LOG_FILE"
    fi
done

# Упаковка
tar -czf "/tmp/$ARCHIVE_NAME" -C "$TMP_DIR" . >> "$LOG_FILE" 2>&1 || [ $? -eq 1 ]

# Шифрование архива перед отправкой в облако (AES256, пароль из файла)
gpg --batch --yes --pinentry-mode loopback \
    --passphrase-file "$PASS_FILE" \
    --symmetric --cipher-algo AES256 \
    -o "/tmp/$ENC_ARCHIVE_NAME" "/tmp/$ARCHIVE_NAME" >> "$LOG_FILE" 2>&1

# Отправка на Google Drive
if ! $RCLONE_PATH copy "/tmp/$ENC_ARCHIVE_NAME" "$REMOTE" >> "$LOG_FILE" 2>&1; then
    echo "[$(date)] ❌ Ошибка отправки бэкапа!" >> "$LOG_FILE"
    exit 1
fi

# Удаляем старые бэкапы (оставляем KEEP последних). Фильтр по маске — не трогаем чужие файлы в папке.
count=$($RCLONE_PATH lsf "$REMOTE" --include "vps_adguhom_*.tar.gz.gpg" | wc -l)
if [ "$count" -gt "$KEEP" ]; then
    to_delete=$((count - KEEP))

    # Временно отключаем pipefail, чтобы SIGPIPE от head не прибил скрипт
    set +o pipefail
    $RCLONE_PATH lsf "$REMOTE" --include "vps_adguhom_*.tar.gz.gpg" | sort | head -n "$to_delete" | while IFS= read -r old; do
        $RCLONE_PATH delete "$REMOTE/$old" >> "$LOG_FILE" 2>&1
        echo "[$(date)] 🗑️ Удалён старый бэкап: $old" >> "$LOG_FILE"
    done
    set -o pipefail
fi

echo "[$(date)] ✅ Бэкап создан успешно." >> "$LOG_FILE"
