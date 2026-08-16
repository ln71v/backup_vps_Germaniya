# Бэкап сервера VPS (Германия)

Скрипт для автоматического ежедневного резервного копирования критически важных данных сервера в Google Drive с шифрованием и ротацией архивов.

> **Скрипт создан для Леонидыча. Не проебать!**

---

## Что входит в бэкап

Скрипт собирает в архив следующие директории (с сохранением исходных путей):

* `/var/www` — файлы сайтов и веб-проектов
* `/etc/nginx` — конфиги веб-сервера Nginx
* `/etc/wireguard` — конфигурации туннелей WireGuard
* `/usr/local/x-ui` — база данных и настройки панели X-UI
* `/opt/AdGuardHome` — настройки и данные AdGuard Home

---

## Особенности работы

* **Шифрование:** архив шифруется (GPG, AES256) перед отправкой — в облако уходит `.tar.gz.gpg`.
* **Куда сохраняет:** Google Drive (папка `VPS_Backups`).
* **Ротация:** автоматически удаляет старые копии, сохраняя только **7 последних архивов**.
* **Логирование:** подробный лог выполнения пишется в `/var/log/backup.log`.

---

## Подготовка (один раз перед первым запуском)

1. Установить зависимости:

```bash
apt install -y rclone gnupg
```

2. Настроить rclone-remote с именем `gdrive` (интерактивный мастер):

```bash
rclone config
```

3. Создать файл пароля для шифрования архивов и закрыть его от чужих глаз:

```bash
openssl rand -base64 32 > /root/.backup_passphrase
chmod 600 /root/.backup_passphrase
```

---

## Быстрая установка скрипта

Выполни на сервере от имени `root`:

```bash
mkdir -p /root/scripts && curl -sSL https://raw.githubusercontent.com/ln71v/backup_vps_Germaniya/main/backup.sh -o /root/scripts/backup.sh && chmod +x /root/scripts/backup.sh
```

## Настройка ежедневного запуска (cron)

```bash
crontab -e
```

Добавить строку (например, в 3:00 ночи):

```
0 3 * * * /root/scripts/backup.sh
```

---

## Восстановление из бэкапа

```bash
gpg --batch --passphrase-file /root/.backup_passphrase -d vps_adguhom_<дата>.tar.gz.gpg > archive.tar.gz
tar -xzf archive.tar.gz -C /
```
