# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/)

## [3.2] - 2026-06-22

Исправление критических ошибок v3.1 в работе apt, из-за которых на чистой Ubuntu 24.04 падали все `apt update / install` с сообщением:

```
❌ apt update failed, см. /var/log/server-setup.log
❌ Ошибка установки mc net-tools ncdu iftop ...
environment: line 218: docker: command not found
[2026-06-22 12:44:24] Docker установлен:
```

При этом скрипт продолжал выполнение, применял sysctl, писал "Docker установлен: " с пустой версией.

### Fixed
- **APT_OPTS: строка → массив**  
  Было: `APT_QUIET="-qq -o Dpkg::Use-Pty=0"` + `apt-get install -y $APT_QUIET "${pkgs[@]}"`  
  Стало: `APT_OPTS=(-qq -o Dpkg::Use-Pty=0)` + `apt-get install -y "${APT_OPTS[@]}" "${pkgs[@]}"`  
  Проблема: при любом IFS-мусоре в окружении строка разбивалась неправильно, apt получал битые аргументы. Массив — IFS-proof.

- **Вывод списка пакетов с `\n` вместо пробелов**  
  Было: `pkgs_str="${pkgs[*]}"` — зависит от глобального IFS.  
  Стало: `local IFS=' '; pkgs_str="${pkgs[*]}"` — всегда через пробел локально.  
  Убирает вывод вида:
  ```
  📦 Устанавливаю: mc
  net-tools
  ncdu
  ...
  ```

- **apt-lock race**  
  На свежем Ubuntu `unattended-upgrades` держит `/var/lib/dpkg/lock-frontend`. Раньше apt просто падал.  
  Добавлено: `wait_apt_lock()` — ждёт до 120 сек, показывает `⏳ Жду освобождения apt-lock...`

- **Скрипт не останавливался при ошибке apt**  
  Из-за `check_root && base_setup || { ... }` в меню: `set -e` отключается в AND-OR списке, apt падал, а скрипт шёл дальше.  
  Теперь: `base_setup()` явно проверяет каждый apt-шаг, при фейле `return 1`.  
  В меню: `if ! base_setup; then echo "Базовая настройка завершилась с ошибкой. См. $LOG_FILE"; pause_prompt; fi`

- **`docker --version` валил лог**  
  Было: `log "Docker установлен: $(docker --version)"` — при неустановленном docker подстановка падала с `set -u`.  
  Стало: `docker_ver=$(docker --version 2>/dev/null || echo "not found")`

- **LOG_FILE unbound в редиректах**  
  `>>"$LOG_FILE"` при пустом LOG_FILE → ошибка `set -u`.  
  Везде заменено на `>>"$(log_file)"`, где `log_file()` возвращает `/dev/null` как fallback.

- **Нет диагностики apt-ошибок в консоли**  
  Было просто: `❌ apt update failed, см. /var/log/server-setup.log`  
  Стало: `apt_fail_tail()` — сразу печатает последние 40 строк лога в консоль.

- **`need_cmd` падал с `set -u`** на `${#pkgs[@]}` при пустом массиве.

- **UFW-manager: cd leak при отказе** — оставались в `~/network-managers/ufw-manager`. Добавлен `cd ~` перед return.

- **Multitest: тесты валили меню** — `sysbench`, `traceroute`, `ping`, SSL-check с ненулевым кодом убивали скрипт через `set -e`. Все обернуты в `|| true`.

- **`read / pause_prompt`: Ctrl+D / EOF** — добавлено `|| true` / `|| choice=0`.

### Changed
- Версия в header и show_header: `v3.2`
- `install_docker_apt()` теперь возвращает ненулевой код при ошибке apt, а не идёт дальше
- `base_setup()` — строгая обработка ошибок, `set -e` внутри, явный `return 1` при фейле apt
- Главное меню — ловит ошибку `base_setup` и показывает `Базовая настройка завершилась с ошибкой`
- Все apt-вызовы: `"${APT_OPTS[@]}"` вместо `$APT_QUIET`
- Все редиректы логов: `>>"$(log_file)"` вместо `>>"$LOG_FILE"`

### Security
- без изменений

**SHA256:**
```
server-setup.sh  f3389ca5d0ac1aa1b01b242785a3739c9c91a42b898ce8d5250671276db5ec81
```

---

## [3.1] - 2026-06-22

Исправление 9 багов v3.0, обнаруженных при код-ревью (до боевого запуска).

### Fixed
- **Удалён глобальный `IFS=$'\n\t'`** — ломал apt, аргументы, `${pkgs[*]}`
- **`run_verified_script`: аргументы с дефисом ломались** — `run_verified_script "YABS" ... "-4"` интерпретировалось как `${4}`. Переписано на `run_verified_script "Name" "url" "sha" -- arg1 arg2`
- **Конфликт sysctl файлов** — SAFE и HIGHLOAD писали в разные файлы (`99-server-safe.conf` / `99-server-highload.conf` / `99-xray-highload.conf`), оба грузились `sysctl --system`. Теперь единый файл `/etc/sysctl.d/99-server.conf` и `/etc/security/limits.d/99-server.conf`, старые файлы авто-удаляются через `clean_old_sysctl()`
- **LOG_FILE unbound под `set -u`** — fallback на `/dev/null`, helper `log_file()`
- **`need_cmd` падал с `set -u`** на `${#pkgs[@]}`
- **UFW-manager: cd leak**
- **Multitest: тесты валили меню** — все обернуты в `|| true`
- **`read / pause_prompt`: Ctrl+D**
- **apt_install: вывод `${pkgs[*]}` с IFS**

### Changed
- Версия: `v3.1`
- Sysctl/limits пути унифицированы:  
  `SYSCTL_CONF="/etc/sysctl.d/99-server.conf"`  
  `LIMITS_CONF="/etc/security/limits.d/99-server.conf"`
- `run_verified_script` теперь: `run_verified_script "Name" "url" "sha" -- arg1 arg2`

---

## [3.0] - 2026-06-22

Первый релиз v3, основан на [Balbuto/Setup-and-Test-Server-Ubuntu-24 v2](https://github.com/Balbuto/Setup-and-Test-Server-Ubuntu-24).

### Added
- Раздельный профиль sysctl: SAFE (по умолчанию) и HIGHLOAD (опционально)
- Меню управления IPv6 с бэкапом и `/root/restore-ipv6.sh`
- Верификация всех внешних тест-скриптов: HTTPS-only, SHA256, ручное подтверждение
- Автобэкап всех перезаписываемых `/etc` файлов в `/root/server-setup-backups/YYYYMMDD-HHMMSS/`
- Тихие обёртки apt: `apt_update()`, `apt_install()`, `apt_upgrade_full()`
- Docker установка через официальный apt-репозиторий с GPG
- UFW-manager через `git clone` + `git diff` перед запуском
- Пакеты `ncdu`, `iftop` в базовую установку
- Отдельные пункты меню для применения SAFE/HIGHLOAD sysctl
- Документация: README, docs/USAGE.md, docs/SYSCTL.md, docs/TESTS.md
- CONTRIBUTING.md, SECURITY.md

### Changed
- IPv6 больше не отключается автоматически
- Sysctl по умолчанию консервативный: nofile 65535, conntrack 65536, somaxconn 4096, rmem/wmem_max 16 MB
- Base setup разбит на 6 отключаемых шагов
- `set -e` → `set -Eeuo pipefail`
- Логи без ANSI-цветов
- `DEBIAN_FRONTEND=noninteractive`, `apt -qq -o Dpkg::Use-Pty=0`
- Network Bench: добавлен fallback `ipv4.download.thinkbroadband.com`
- Пакеты для тестов ставятся только если отсутствуют, тихо

### Fixed
- Цветовые escape-коды больше не попадают в лог-файл
- `log()` больше не падает если LOG_FILE недоступен

### Security
- Все внешние скрипты: HTTPS + TLS 1.2+, SHA256 verification
- Docker: официальная apt-подпись
- UFW-manager: git-верификация перед запуском

---

## [2.0] - 2026-05-20

- Интегрирован Multitest
- BBR, отключение IPv6, hardening XRAY
- UFW-manager интеграция
- Автор: [Balbuto](https://github.com/Balbuto/Setup-and-Test-Server-Ubuntu-24)

## [1.0] - 2026-03-09

- Initial commit
- Автор: Balbuto
