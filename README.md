# Бэкап сервера VPS (Германия)

Скрипт для автоматического ежедневного резервного копирования критически важных данных сервера в Google Drive с ротацией архивов.

> **Скрипт создан для Леонидыча. Не проебать!**

---

## Что входит в бэкап

Скрипт собирает в архив следующие директории:
* `/var/www` — файлы сайтов и веб-проектов
* `/etc/nginx` — конфиги веб-сервера Nginx
* `/etc/wireguard` — конфигурации туннелей WireGuard
* `/usr/local/x-ui` — база данных и настройки панели X-UI
* `/opt/AdGuardHome` — настройки и данные AdGuard Home

---

## Особенности работы

* **Куда сохраняет:** Google Drive (папка `VPS_Backups`).
* **Ротация:** автоматически удаляет старые копии, сохраняя только **7 последних архивов**.
* **Логирование:** подробный лог выполнения пишется в `/var/log/backup.log`.

---

## Быстрая установка

Выполни команду на сервере от имени `root`:

```bash
mkdir -p /root/scripts && curl -sSL [https://raw.githubusercontent.com/ln71v/backup_vps_Germaniya/main/backup.sh](https://raw.githubusercontent.com/ln71v/backup_vps_Germaniya/main/backup.sh) -o /root/scripts/backup.sh && chmod +x /root/scripts/backup.sh
