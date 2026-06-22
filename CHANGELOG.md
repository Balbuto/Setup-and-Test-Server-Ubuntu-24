# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/)

## [3.0] - 2026-06-22

### Added
- Раздельный профиль sysctl: SAFE (по умолчанию) и HIGHLOAD (опционально)
- Меню управления IPv6 с бэкапом и `/root/restore-ipv6.sh`
- Верификация всех внешних тест-скриптов: HTTPS-only, SHA256, ручное подтверждение
- Автобэкап всех перезаписываемых `/etc` файлов в `/root/server-setup-backups/YYYYMMDD-HHMMSS/`
- Тихие обёртки apt: `apt_update()`, `apt_install()`, `apt_upgrade_full()` - вывод в лог, на экране только прогресс
- Docker установка через официальный apt-репозиторий с GPG
- UFW-manager через `git clone` + `git diff` перед запуском
- Пакеты `ncdu`, `iftop` в базовую установку
- Отдельные пункты меню для применения SAFE/HIGHLOAD sysctl
- Полная документация: README, docs/USAGE.md, docs/SYSCTL.md, docs/TESTS.md
- CONTRIBUTING.md, SECURITY.md

### Changed
- IPv6 больше не отключается автоматически, вынесено в отдельное меню
- Sysctl по умолчанию консервативный: nofile 65535, conntrack 65536, somaxconn 4096, rmem/wmem_max 16 MB
  HIGHLOAD профиль (nofile 1M+, conntrack 2M) доступен опционально
- Base setup разбит на 6 отключаемых шагов
- `set -e` → `set -Eeuo pipefail`
- Логи без ANSI-цветов
- `DEBIAN_FRONTEND=noninteractive`, `apt -qq -o Dpkg::Use-Pty=0`
- Network Bench: добавлен fallback `ipv4.download.thinkbroadband.com`
- Пакеты для тестов (`sysbench`, `iperf3`, `traceroute`) ставятся только если отсутствуют, тихо
- Имена конфигов: `/etc/sysctl.d/99-server.conf` и `/etc/security/limits.d/99-server.conf` для SAFE,
  `/etc/sysctl.d/99-server-highload.conf` для HIGHLOAD
- Лог-файл: `/var/log/server-setup.log`

### Fixed
- Цветовые escape-коды больше не попадают в лог-файл
- `log()` больше не падает если LOG_FILE недоступен

### Security
- Все внешние скрипты: HTTPS + TLS 1.2+, SHA256 verification
- Docker: официальная apt-подпись
- UFW-manager: git-верификация перед запуском

## [2.0] - 2026-05-20

- Интегрирован Multitest
- BBR, отключение IPv6, hardening XRAY
- UFW-manager интеграция
- Автор: [Balbuto](https://github.com/Balbuto/Setup-and-Test-Server-Ubuntu-24)

## [1.0] - 2026-03-09

- Initial commit
- Автор: Balbuto
