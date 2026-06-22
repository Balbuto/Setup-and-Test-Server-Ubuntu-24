# 🚀 Setup & Test Server Ubuntu 24.04

**Универсальный скрипт для первоначальной настройки и диагностики сервера Ubuntu 24.04 LTS.**

Версия 3.0

[![Bash](https://img.shields.io/badge/bash-5.1+-green)](https://www.gnu.org/software/bash/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange)](https://ubuntu.com/)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Выполняет полную настройку сети, установку необходимого ПО, hardening и предоставляет встроенный набор тестов для проверки производительности.



---

## Что нового в v3.0

| v2 | v3.0 |
|---|---|
| IPv6 отключается всегда | IPv6 **не трогается**. Отдельное меню с бэкапом и `/root/restore-ipv6.sh` |
| `nofile 1M+, conntrack 2M` сразу | **SAFE профиль по умолчанию**: nofile 65k, conntrack 65k. HIGHLOAD опционально |
| `curl \| bash` без проверки | Все внешние скрипты **HTTPS + SHA256 + подтверждение** |
| Docker через `get.docker.com \| sh` | Docker через **официальный apt-репозиторий с GPG** |
| Перезапись `/etc` без бэкапа | **Автобэкап** в `/root/server-setup-backups/` |
| Логи с ANSI-мусором | Чистые логи |
| Весь вывод apt в консоль | **Тихая установка**: прогресс в 1 строку, полный лог в файл |
| UFW-manager: blind wget | `git clone` + `git diff` перед запуском |
| Базовый софт: mc, net-tools | + **ncdu, iftop** |

---

## ✨ Возможности

### 1. Базовая настройка сервера
Интерактивно, каждый шаг отключаемый:

1. **Обновление системы** - `update / upgrade / dist-upgrade / autoremove / autoclean`
2. **Базовый софт** - `mc, net-tools, ncdu, iftop, curl, wget, git`
3. **Docker + Docker Compose** - официальный apt-репозиторий, GPG
4. **BBR** - TCP congestion control
5. **Hardening** - на выбор SAFE / HIGHLOAD / none
6. **irqbalance**

### 2. Управление IPv6
- Посмотреть статус
- Отключить с автобэкапом + `/root/restore-ipv6.sh`
- Включить обратно

### 3. Управление файерволом UFW
Обертка над [Balbuto/ufw-manager](https://github.com/Balbuto/ufw-manager):
- `git clone`, показ `git log`, `git diff` перед запуском

### 4. Диагностика Multitest
14 тестов, все через верифицированную загрузку:

| # | Тест | Источник |
|---|---|---|
| 1 | IP Region | `ipregion.vrnt.xyz` |
| 2 | Censorcheck — геоблок | `vernette/censorcheck` |
| 3 | Censorcheck — DPI | `vernette/censorcheck` |
| 4 | iPerf3 — RU | `itdoginfo/russian-iperf3-servers` |
| 5 | YABS | `yabs.sh` |
| 6 | IP Check Place | `IP.Check.Place` |
| 7 | bench.sh | `bench.sh` |
| 8 | IPQuality | `Check.Place` |
| 9 | sysbench CPU |
| 10 | sysbench Memory |
| 11 | Network Bench |
| 12 | SSL/TLS check |
| 13 | Traceroute yandex.ru |
| 14 | Ping yandex.ru |

Пункт **99 - Запустить ВСЕ**.

---

## 📦 Установка

```bash
wget https://raw.githubusercontent.com/Balbuto/Setup-and-Test-Server-Ubuntu-24/main/server-setup
chmod +x server-setup
sudo ./server-setup
```

Требования: **Ubuntu 24.04 LTS**, root.

---

## 🛡️ Sysctl профили

Подробно: [SYSCTL.md](SYSCTL.md)

**SAFE (по умолчанию):**
```
nofile = 65535
conntrack_max = 65536
somaxconn = 4096
rmem/wmem_max = 16 MB
```

**HIGHLOAD (XRAY/VPN):**
```
nofile = 1048576
conntrack_max = 2097152
somaxconn = 1048576
rmem/wmem_max = 128 MB
```

Оба с BBR, FastOpen, syncookies, anti-spoof.

---

## 🔒 Верификация внешних скриптов

Каждый тест-скрипт: HTTPS-only, TLS 1.2+, SHA256, ручное подтверждение если хэш не зашит.

Хэши в `run_multitest()` пустые по умолчанию - заполните после первого прогона, см. [TESTS.md](TESTS.md)

---

## 📁 Структура

```
server-setup.sh          # основной скрипт, ~560 строк
README.md
CHANGELOG.md
LICENSE
CONTRIBUTING.md
SECURITY.md
USAGE.md
SYSCTL.md
TESTS.md
```

Логи: `/var/log/server-setup.log` → `/tmp/server-setup.log` → `~/server-setup.log`

Бэкапы: `/root/server-setup-backups/YYYYMMDD-HHMMSS/`

---

## 📖 Документация

- [Использование](USAGE.md)
- [Sysctl профили](SYSCTL.md)
- [Тесты](TESTS.md)

---

## 📜 Лицензия

MIT

---

## 🙏 Благодарности

- [Balbuto](https://github.com/Balbuto) - автор v1/v2
- Авторы yabs.sh, bench.sh, censorcheck, ipregion, IP.Check.Place и др.
