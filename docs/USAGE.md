# Использование

`server-setup.sh` v3.2

## Быстрый старт

```bash
chmod +x server-setup.sh
sudo ./server-setup.sh
```

Главное меню:

```
 1. Базовая настройка сервера (выборочно)
 2. Управление IPv6 (вкл/выкл + откат)
 3. Управление файерволом UFW
 4. Диагностика Multitest

 5. Применить SAFE sysctl отдельно
 6. Применить HIGHLOAD sysctl отдельно

 0. Выйти
```

---

## 1. Базовая настройка

При выборе пункта 1 скрипт спросит про каждый шаг отдельно, все Y по умолчанию:

```
БАЗОВАЯ НАСТРОЙКА - выберите шаги

1. Обновить систему? [Y/n]
2. Установить базовый софт (mc, net-tools, ncdu, iftop, curl, wget, git)? [Y/n]
3. Установить Docker (apt + GPG)? [Y/n]
4. Включить BBR? [Y/n]
5. Hardening профиль: [s]afe / [h]ighload / [n]one
   Выбор [s]:
6. Установить irqbalance? [Y/n]
```

Вывод apt минимизирован. На экране только:

```
📦 Обновление списков пакетов...
✅ Списки пакетов обновлены
📦 upgrade / dist-upgrade ...
✅ Система обновлена
📦 Устанавливаю: mc net-tools ncdu iftop curl wget git ca-certificates gnupg lsb-release ...
✅ Установлено: mc net-tools ncdu iftop curl wget git ca-certificates gnupg lsb-release
```

Полный вывод apt: `/var/log/server-setup.log`

При ошибке apt:
```
❌ apt update failed
--- последние 40 строк /var/log/server-setup.log ---
...
--- конец лога ---
```
и настройка прерывается — скрипт не идёт дальше ставить Docker/sysctl на сломанной системе.

После успешного завершения — бэкапы в `/root/server-setup-backups/YYYYMMDD-HHMMSS/`

Если требуется reboot (`/var/run/reboot-required`) — скрипт предложит перезагрузиться.

---

## 2. Управление IPv6

```
Управление IPv6

Статус: Включён

1) Отключить IPv6 (с бэкапом + restore-скрипт)
2) Включить IPv6 обратно
0) Назад
```

При отключении:
- создаётся `/etc/sysctl.d/70-disable-ipv6.conf`
- создаётся `/root/restore-ipv6.sh` для отката в 1 команду
- бэкап предыдущего конфига в `BACKUP_DIR`

Откат вручную:
```bash
sudo /root/restore-ipv6.sh
```

---

## 3. UFW Manager

1. При первом запуске клонирует `https://github.com/Balbuto/ufw-manager.git` в `~/network-managers/ufw-manager`
2. При повторных запусках делает `git fetch`
3. Показывает последние 5 коммитов
4. Предлагает показать `git diff`
5. Только после ручного подтверждения запускает `./ufw-manager.sh`

Переменная `SSH_CLIENT` экспортируется фейковая (`0.0.0.0 22 0`), чтобы ufw-manager не падал вне SSH-сессии.

При отказе от запуска — корректный возврат в главное меню (с `cd ~`).

---

## 4. Multitest

14 тестов, пункт 99 запускает все подряд.

Перед каждым внешним скриптом:

```
━━━━━━━━ YABS ━━━━━━━━
ℹ️ Скачивание: https://yabs.sh
  SHA256: a1b2c3d4...
  Размер: 28451 байт
⚠️ Хэш для этого файла не задан в скрипте.
  Проверьте содержимое: less /tmp/verified-YABS-...
Запустить этот скрипт? (y/N):
```

Если вы зашьёте хэш в скрипт (см. [TESTS.md](TESTS.md)), подтверждения не будет, будет авто-проверка:

```
  SHA256: a1b2c3...
✅ Хэш совпал
```

Пакеты для тестов (`sysbench`, `iperf3`, `traceroute`) ставятся автоматически, тихо, только если отсутствуют. Если установка не удалась — тест пропускается, меню не падает.

Аргументы внешним тест-скриптам передаются через `--`:
```bash
run_verified_script "YABS" "https://yabs.sh" "$H_YABS" -- -4
run_verified_script "Censorcheck" "..." "$H_CENSOR" -- --mode geoblock
```

---

## 5 / 6. Применение sysctl отдельно

Можно применить SAFE или HIGHLOAD профиль в любой момент, не проходя всю базовую настройку.

Оба профиля пишут в **один и тот же файл**:
```
/etc/sysctl.d/99-server.conf
/etc/security/limits.d/99-server.conf
```

Старые файлы от v3.0/v2 (`99-server-safe.conf`, `99-xray-highload.conf`, `99-server-highload.conf`) автоматически удаляются через `clean_old_sysctl()` — нет конфликтов.

HIGHLOAD всегда спрашивает подтверждение:
```
⚠️ HIGHLOAD профиль: nofile 1M+, conntrack 2M. Для XRAY/VPN на мощных серверах.
Точно применить HIGHLOAD? (y/N):
```

---

## Логи и бэкапы

Лог-файл (первый доступный):
1. `/var/log/server-setup.log`
2. `/tmp/server-setup.log`
3. `~/server-setup.log`

Если ни один не доступен — `/dev/null`, скрипт продолжает работу.

Логи чистые, без ANSI-escape.

Бэкап-директория создаётся на старте:
```
/root/server-setup-backups/20260622-143022/
  _etc_sysctl.d_99-server.conf.bak
  _etc_security_limits.d_99-server.conf.bak
  ...
```

Каждый перезаписываемый файл из `/etc` копируется туда перед изменением.

При ошибке apt — хвост лога (40 строк) выводится сразу в консоль, полный лог в `$LOG_FILE`.

---

## APT-особенности v3.2

- `APT_OPTS` — bash-массив, IFS-safe: `APT_OPTS=(-qq -o Dpkg::Use-Pty=0)`
- Все вызовы: `apt-get install -y "${APT_OPTS[@]}" "${pkgs[@]}"`
- Вывод пакетов: `local IFS=' '; pkgs_str="${pkgs[*]}"` — всегда через пробел
- Ожидание apt-lock: если `/var/lib/dpkg/lock-frontend` занят (unattended-upgrades), ждёт до 120 сек с индикатором `⏳`
- При ошибке apt — стоп, с хвостом лога в консоль
- `DEBIAN_FRONTEND=noninteractive` — без интерактивных вопросов

---

## FAQ

**Q: Скрипт завис на `⏳ Жду освобождения apt-lock...`?**
A: Это нормально на свежей Ubuntu — `unattended-upgrades` ставит обновления в фоне. Подождите до 2 минут, или убейте `unattended-upgr`: `sudo killall apt apt-get`.

**Q: `apt update failed`, что делать?**
A: Скрипт покажет хвост лога прямо в консоли. Чаще всего: нет сети / битые репозитории / закончилось место. Полный лог: `tail -100 /var/log/server-setup.log`

**Q: Docker уже установлен через snap / нестандартно?**
A: Скрипт проверяет `command -v docker`. Если найдёт — пропустит установку. Если у вас snap-версия — удалите её перед запуском, ставьте apt-версию.

**Q: Можно ли не отключать IPv6, но оставить остальной hardening?**
A: Да. Это поведение по умолчанию. IPv6 трогается только через пункт меню 2.

**Q: Как откатить sysctl?**
A: Бэкапы в `/root/server-setup-backups/`. Просто скопируйте оттуда нужный файл обратно в `/etc/sysctl.d/`, затем `sysctl --system`.

**Q: Тесты падают / не качаются?**
A: Проверьте исходящий HTTPS. Все URL в `run_multitest()`, можете поменять зеркала. Если сайт сменил скрипт — SHA256 не совпадёт, подтвердите вручную и обновите хэш у себя.

**Q: Почему скрипт прервался на "Обновление системы не удалось"?**
A: Это фича v3.2. Раньше (v3.0/v3.1) скрипт шёл дальше ставить Docker/sysctl на сломанной системе. Теперь — стоп с диагностикой. Почините apt (`apt update`, проверьте `/etc/apt/sources.list`, место на диске, DNS), запустите снова.
