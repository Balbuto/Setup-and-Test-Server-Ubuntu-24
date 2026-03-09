# 🚀 Ubuntu Server Setup & Test Script

Интерактивный скрипт для первоначальной настройки и тестирования серверов на базе **Ubuntu 24.04**.

![Version](https://img.shields.io/badge/version-1.0-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04-orange)
![Bash](https://img.shields.io/badge/Bash-5.0+-green)
![License](https://img.shields.io/badge/license-MIT-blue)

## 📋 Описание

Скрипт объединяет в себе два основных модуля:
1.  **Настройка сервера** — автоматизация рутинных задач (обновление, установка ПО, оптимизация сети).
2.  **Тестирование сервера** — запуск популярных бенчмарков и проверок (скорость, регион, DPI).

Весь процесс управляется через удобное текстовое меню.

## ✨ Возможности

### 🛠 Настройка сервера
| Функция | Описание |
|---------|----------|
| **Обновление системы** | `apt update`, `upgrade`, `dist-upgrade`, очистка кэша |
| **Установка ПО** | `mc`, `net-tools`, `Docker`, `Docker Compose` |
| **Включение BBR** | Оптимизация сетевого стека (TCP BBR congestion control) |
| **Управление IPv6** | Интеграция со скриптом [Balbuto/ipv6-manager](https://github.com/Balbuto/ipv6-manager) |
| **Управление UFW** | Интеграция со скриптом [Balbuto/ufw-manager](https://github.com/Balbuto/ufw-manager) |

### 🧪 Тестирование сервера
| Тест | Описание |
|------|----------|
| **DPI Test** | Проверка на наличие систем DPI (актуально для РФ) |
| **Bench.sh** | Бенчмарк скорости до зарубежных провайдеров |
| **Bench.gig.ovh** | Бенчмарк с тестами до российских провайдеров |
| **YABS** | Подробный бенчмарк (CPU, Disk, Network) |
| **IP Region** | Определение географического региона IP |
| **Instagram Audio** | Проверка доступности аудиофункций Instagram |

## 🚀 Быстрый старт

### Установка и запуск

```bash
# 1. Скачайте скрипт
wget -O setup-server.sh https://raw.githubusercontent.com/Balbuto/Setup-and-Test-Server-Ubuntu-24/refs/heads/main/setup-server.sh

# 2. Сделайте его исполняемым
chmod +x setup-server.sh

# 3. Запустите от имени root
sudo ./setup-server.sh
