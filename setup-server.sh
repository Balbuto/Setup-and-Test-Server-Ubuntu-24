#!/bin/bash
# ======================================================
# Интерактивный скрипт настройки сервера Ubuntu 24.04
# Версия: 1.0
# ======================================================

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Эмодзи
CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
LOCK="🔒"
GEAR="⚙️"
TEST_TUBE="🧪"
BAR_CHART="📊"
RUSSIA="🇷🇺"
MAP="🗺"
CAMERA="📸"
PACKAGE="📦"
DOCKER="🐳"

# ✅ Директории менеджеров в /opt (ОТДЕЛЬНЫЕ папки)
IPV6_MANAGER_DIR="/opt/ipv6-manager"
UFW_MANAGER_DIR="/opt/ufw-manager"

# Логирование
LOG_FILE="/var/log/server-setup.log"
LOG_FILE_FALLBACK="/tmp/server-setup.log"

# Флаги
MANAGERS_CHECKED=false
APT_UPDATED=false

# ======================================================
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${CROSS_MARK} ${RED}Нужны root-права! Используйте: sudo $0${NC}"
        return 1
    fi
    return 0
}

# ======================================================
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message" | tee -a "$LOG_FILE" 2>/dev/null || \
    echo -e "$message" | tee -a "$LOG_FILE_FALLBACK" 2>/dev/null
}

# ======================================================
check_dependencies() {
    log "${INFO} Проверка зависимостей..."
    echo -e "${INFO} Проверка пакетов..."
    
    local deps=("wget" "curl" "git")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
            echo -e "${WARNING} Отсутствует: $dep"
        else
            echo -e "${CHECK_MARK} Установлен: $dep"
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${INFO} Установка: ${missing[*]}"
        apt-get update -qq || { echo -e "${CROSS_MARK} Ошибка update"; return 1; }
        apt-get install -y -qq "${missing[@]}" || { echo -e "${CROSS_MARK} Ошибка install"; return 1; }
        echo -e "${CHECK_MARK} Зависимости установлены"
        APT_UPDATED=true
    fi
    
    git --version &> /dev/null || { echo -e "${CROSS_MARK} Git не работает"; return 1; }
    echo -e "${CHECK_MARK} Git: $(git --version)"
    return 0
}

# ======================================================
show_header() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${ROCKET}  НАСТРОЙКА И ТЕСТИРОВАНИЕ СЕРВЕРА ${ROCKET}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    [[ -f /etc/os-release ]] && . /etc/os-release && echo -e "${BLUE}  Система: $PRETTY_NAME${NC}"
    echo -e "${BLUE}  Ядро: $(uname -r)${NC}"
    echo -e "${BLUE}  Время: $(date '+%H:%M:%S %d.%m.%Y')${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ======================================================
show_main_menu() {
    echo -e "${WHITE}ГЛАВНОЕ МЕНЮ:${NC}"
    echo ""
    echo -e "${GEAR} 1. Настройка сервера (BBR, IPv6, UFW, ПО)"
    echo -e "${TEST_TUBE} 2. Тестирование сервера"
    echo ""
    echo -e "0. Выйти"
}

# ======================================================
show_server_menu() {
    echo -e "${WHITE}МЕНЮ НАСТРОЙКИ:${NC}"
    echo ""
    echo -e "${PACKAGE} 1. Обновление системы"
    echo -e "${PACKAGE} 2. Установка ПО (mc, net-tools, Docker)"
    echo -e "${ROCKET} 3. Включение BBR"
    echo -e "${GEAR} 4. Управление IPv6"
    echo -e "${LOCK} 5. Управление UFW"
    echo ""
    echo -e "0. Назад"
}

# ======================================================
show_tests_menu() {
    echo -e "${WHITE}МЕНЮ ТЕСТОВ:${NC}"
    echo ""
    echo -e "${RUSSIA} 1. DPI тест (censorcheck)"
    echo -e "${ROCKET} 2. Бенчмарк (зарубежные) - bench.sh"
    echo -e "${RUSSIA} 3. Бенчмарк (с РФ) - bench.gig.ovh"
    echo -e "${BAR_CHART} 4. YABS"
    echo -e "${MAP} 5. IP Region"
    echo -e "${CAMERA} 6. Instagram Audio"
    echo ""
    echo -e "0. Назад"
}

# ======================================================
# ✅ ФУНКЦИЯ: Принудительная установка прав +x
# ======================================================
force_chmod_x() {
    local file="$1"
    if [[ -f "$file" ]]; then
        chmod +x "$file" 2>/dev/null
        if [[ -x "$file" ]]; then
            return 0
        fi
    fi
    return 1
}

# ======================================================
# ✅ ПРОВЕРКА И КЛОНИРОВАНИЕ МЕНЕДЖЕРОВ
# ✅ Принудительный chmod +x после клонирования
# ======================================================
ensure_managers() {
    if [[ "$MANAGERS_CHECKED" == "true" ]]; then
        [[ -x "$IPV6_MANAGER_DIR/ipv6-manager.sh" && -x "$UFW_MANAGER_DIR/ufw-manager.sh" ]] && {
            echo -e "${CHECK_MARK} Менеджеры готовы (локально)"
            return 0
        }
        MANAGERS_CHECKED=false
    fi
    
    echo -e "${INFO} Проверка менеджеров..."
    local ipv6_ok=false ufw_ok=false
    
    # ===== IPv6 Manager =====
    if [[ -f "$IPV6_MANAGER_DIR/ipv6-manager.sh" ]]; then
        echo -e "${CHECK_MARK} IPv6 Manager найден"
        # ✅ ПРИНУДИТЕЛЬНАЯ УСТАНОВКА +x
        if ! force_chmod_x "$IPV6_MANAGER_DIR/ipv6-manager.sh"; then
            echo -e "${WARNING} Не удалось установить +x, пробуем переустановить..."
            rm -rf "$IPV6_MANAGER_DIR"
        else
            cd "$IPV6_MANAGER_DIR" || return 1
            timeout 60 git pull -q &>> "$LOG_FILE"
            force_chmod_x "ipv6-manager.sh"
            cd /
            ipv6_ok=true
        fi
    fi
    
    # Если не ок — клонируем заново
    if [[ "$ipv6_ok" != "true" ]]; then
        echo -e "${INFO} IPv6 Manager: клонирование..."
        rm -rf "$IPV6_MANAGER_DIR" 2>/dev/null
        mkdir -p /opt
        if timeout 120 git clone -q https://github.com/Balbuto/ipv6-manager.git "$IPV6_MANAGER_DIR" &>> "$LOG_FILE"; then
            # ✅ ПРИНУДИТЕЛЬНАЯ УСТАНОВКА +x ПОСЛЕ КЛОНИРОВАНИЯ
            if force_chmod_x "$IPV6_MANAGER_DIR/ipv6-manager.sh"; then
                ipv6_ok=true
                echo -e "${CHECK_MARK} IPv6 Manager клонирован и исполняемый"
            else
                # Пробуем найти альтернативный .sh файл
                local alt_script=$(find "$IPV6_MANAGER_DIR" -maxdepth 1 -name "*.sh" -type f | head -1)
                if [[ -n "$alt_script" ]]; then
                    force_chmod_x "$alt_script"
                    ln -sf "$(basename "$alt_script")" "$IPV6_MANAGER_DIR/ipv6-manager.sh" 2>/dev/null
                    ipv6_ok=true
                    echo -e "${CHECK_MARK} IPv6 Manager: использован $(basename "$alt_script")"
                else
                    echo -e "${CROSS_MARK} Не найдено исполняемых .sh файлов"
                    echo -e "${INFO} Содержимое репозитория:"
                    ls -la "$IPV6_MANAGER_DIR/" 2>/dev/null
                fi
            fi
        else
            echo -e "${CROSS_MARK} Ошибка клонирования IPv6 Manager"
        fi
    fi
    
    # ===== UFW Manager =====
    if [[ -f "$UFW_MANAGER_DIR/ufw-manager.sh" ]]; then
        echo -e "${CHECK_MARK} UFW Manager найден"
        if ! force_chmod_x "$UFW_MANAGER_DIR/ufw-manager.sh"; then
            echo -e "${WARNING} Не удалось установить +x, пробуем переустановить..."
            rm -rf "$UFW_MANAGER_DIR"
        else
            cd "$UFW_MANAGER_DIR" || return 1
            timeout 60 git pull -q &>> "$LOG_FILE"
            force_chmod_x "ufw-manager.sh"
            cd /
            ufw_ok=true
        fi
    fi
    
    if [[ "$ufw_ok" != "true" ]]; then
        echo -e "${INFO} UFW Manager: клонирование..."
        rm -rf "$UFW_MANAGER_DIR" 2>/dev/null
        mkdir -p /opt
        if timeout 120 git clone -q https://github.com/Balbuto/ufw-manager.git "$UFW_MANAGER_DIR" &>> "$LOG_FILE"; then
            if force_chmod_x "$UFW_MANAGER_DIR/ufw-manager.sh"; then
                ufw_ok=true
                echo -e "${CHECK_MARK} UFW Manager клонирован и исполняемый"
            else
                echo -e "${CROSS_MARK} Не удалось сделать ufw-manager.sh исполняемым"
            fi
        else
            echo -e "${CROSS_MARK} Ошибка клонирования UFW Manager"
        fi
    fi
    
    echo ""
    if [[ "$ipv6_ok" == "true" && "$ufw_ok" == "true" ]]; then
        MANAGERS_CHECKED=true
        echo -e "${CHECK_MARK} Все менеджеры готовы"
        return 0
    else
        echo -e "${WARNING} Некоторые менеджеры не готовы (можно продолжить)"
        return 0
    fi
}

# ======================================================
update_system() {
    show_header
    echo -e "${PACKAGE} Обновление системы"
    echo ""
    
    [[ "$APT_UPDATED" != "true" ]] && { apt-get update -qq || { echo -e "${CROSS_MARK} Ошибка"; read; return 1; }; APT_UPDATED=true; }
    
    apt-get upgrade -y -qq
    apt-get dist-upgrade -y -qq
    apt-get autoremove -y -qq
    apt-get autoclean -qq
    
    echo -e "${CHECK_MARK} Обновление завершено"
    
    [[ -f /var/run/reboot-required ]] && {
        echo -e "${WARNING} Требуется перезагрузка!"
        read -p "Перезагрузить? (y/n): " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] && reboot
    }
    
    echo -e "${INFO} Нажмите Enter..."
    read
}

# ======================================================
install_base_software() {
    show_header
    echo -e "${PACKAGE} Установка базового ПО"
    echo ""
    
    [[ "$APT_UPDATED" != "true" ]] && { apt-get update -qq; APT_UPDATED=true; }
    
    echo -e "${INFO} Установка mc и net-tools..."
    apt-get install -y -qq mc net-tools
    
    command -v mc &> /dev/null && echo -e "${CHECK_MARK} mc" || echo -e "${CROSS_MARK} mc ошибка"
    command -v ifconfig &> /dev/null && echo -e "${CHECK_MARK} net-tools" || echo -e "${CROSS_MARK} net-tools ошибка"
    
    echo ""
    echo -e "${DOCKER} Установка Docker..."
    
    if command -v docker &> /dev/null; then
        echo -e "${CHECK_MARK} Docker уже установлен"
    else
        curl --max-time 60 -fsSL https://get.docker.com -o get-docker.sh && \
        sh get-docker.sh &>> "$LOG_FILE" && rm -f get-docker.sh && \
        echo -e "${CHECK_MARK} Docker установлен"
        [[ -n "$SUDO_USER" ]] && usermod -aG docker "$SUDO_USER" 2>/dev/null
    fi
    
    echo -e "${INFO} Нажмите Enter..."
    read
}

# ======================================================
enable_bbr() {
    show_header
    echo -e "${ROCKET} Включение BBR"
    echo ""
    
    local cong=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)
    
    if [[ "$cong" == "bbr" ]]; then
        echo -e "${CHECK_MARK} BBR уже включен"
    else
        grep -q "net.ipv4.tcp_congestion_control = bbr" /etc/sysctl.conf 2>/dev/null || \
            echo -e "\nnet.core.default_qdisc = fq\nnet.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
        sysctl -p &>> "$LOG_FILE"
        echo -e "${CHECK_MARK} BBR включен"
    fi
    
    echo -e "${INFO} Нажмите Enter..."
    read
}

# ======================================================
# ✅ УПРАВЛЕНИЕ IPv6 — с проверкой исполняемости
# ======================================================
manage_ipv6() {
    show_header
    echo -e "${GEAR} Управление IPv6"
    echo ""
    
    ensure_managers
    
    # ✅ ПРОВЕРКА: файл существует И исполняемый
    if [[ ! -f "$IPV6_MANAGER_DIR/ipv6-manager.sh" ]]; then
        echo -e "${CROSS_MARK} Файл не найден: $IPV6_MANAGER_DIR/ipv6-manager.sh"
        echo -e "${INFO} Содержимое директории:"
        ls -la "$IPV6_MANAGER_DIR/" 2>/dev/null || echo "Директория пуста"
        read -p "Enter..."
        return 1
    fi
    
    # ✅ ПРИНУДИТЕЛЬНАЯ УСТАНОВКА +x ПЕРЕД ЗАПУСКОМ
    if ! force_chmod_x "$IPV6_MANAGER_DIR/ipv6-manager.sh"; then
        echo -e "${CROSS_MARK} Не удалось сделать скрипт исполняемым"
        echo -e "${INFO} Пробуем запустить через bash..."
        cd "$IPV6_MANAGER_DIR" && bash ipv6-manager.sh && cd /
        read -p "Enter..."
        return 0
    fi
    
    echo -e "${CHECK_MARK} Запуск IPv6 Manager..."
    cd "$IPV6_MANAGER_DIR" || return 1
    ./ipv6-manager.sh
    cd /
    read -p "Enter..."
}

# ======================================================
# ✅ УПРАВЛЕНИЕ UFW — с проверкой исполняемости
# ======================================================
manage_ufw() {
    show_header
    echo -e "${LOCK} Управление UFW"
    echo ""
    
    ensure_managers
    
    if [[ ! -f "$UFW_MANAGER_DIR/ufw-manager.sh" ]]; then
        echo -e "${CROSS_MARK} Файл не найден: $UFW_MANAGER_DIR/ufw-manager.sh"
        echo -e "${INFO} Содержимое директории:"
        ls -la "$UFW_MANAGER_DIR/" 2>/dev/null || echo "Директория пуста"
        read -p "Enter..."
        return 1
    fi
    
    if ! force_chmod_x "$UFW_MANAGER_DIR/ufw-manager.sh"; then
        echo -e "${CROSS_MARK} Не удалось сделать скрипт исполняемым"
        echo -e "${INFO} Пробуем запустить через bash..."
        cd "$UFW_MANAGER_DIR" && bash ufw-manager.sh && cd /
        read -p "Enter..."
        return 0
    fi
    
    echo -e "${CHECK_MARK} Запуск UFW Manager..."
    cd "$UFW_MANAGER_DIR" || return 1
    ./ufw-manager.sh
    cd /
    read -p "Enter..."
}

# ======================================================
# ТЕСТЫ
# ======================================================
test_dpi() { show_header; echo -e "${RUSSIA} DPI тест"; bash <(timeout 60 wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode dpi 2>/dev/null || echo -e "${CROSS_MARK} Ошибка"; read -p "Enter..."; }
test_bench_global() { show_header; echo -e "${ROCKET} Бенчмарк"; timeout 60 wget -qO- bench.sh | bash 2>/dev/null || echo -e "${CROSS_MARK} Ошибка"; read -p "Enter..."; }
test_bench_russia() { show_header; echo -e "${RUSSIA} Бенчмарк РФ"; timeout 60 wget -qO- bench.gig.ovh | bash 2>/dev/null || echo -e "${CROSS_MARK} Ошибка"; read -p "Enter..."; }
test_yabs() { show_header; echo -e "${BAR_CHART} YABS"; curl --max-time 60 -sL yabs.sh | bash -s -- -4 2>/dev/null || echo -e "${CROSS_MARK} Ошибка"; read -p "Enter..."; }
test_ip_region() { show_header; echo -e "${MAP} IP Region"; bash <(timeout 60 wget -qO- https://ipregion.xyz) 2>/dev/null || echo -e "${CROSS_MARK} Ошибка"; read -p "Enter..."; }
test_instagram_audio() { show_header; echo -e "${CAMERA} Instagram"; bash <(curl --max-time 60 -L -s https://bench.openode.xyz/checker_inst.sh) 2>/dev/null || echo -e "${CROSS_MARK} Ошибка"; read -p "Enter..."; }

# ======================================================
server_menu_loop() {
    while true; do
        show_header; show_server_menu
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        read -p "Выберите (0-5): " c
        [[ -z "$c" || ! "$c" =~ ^[0-5]$ ]] && { echo -e "${CROSS_MARK} Неверно"; continue; }
        case $c in
            1) check_root && update_system ;;
            2) check_root && install_base_software ;;
            3) check_root && enable_bbr ;;
            4) check_root && manage_ipv6 ;;
            5) check_root && manage_ufw ;;
            0) return ;;
        esac
    done
}

# ======================================================
tests_menu_loop() {
    while true; do
        show_header; show_tests_menu
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        read -p "Выберите (0-6): " c
        [[ -z "$c" || ! "$c" =~ ^[0-6]$ ]] && { echo -e "${CROSS_MARK} Неверно"; continue; }
        case $c in
            1) test_dpi ;; 2) test_bench_global ;; 3) test_bench_russia ;;
            4) test_yabs ;; 5) test_ip_region ;; 6) test_instagram_audio ;;
            0) return ;;
        esac
    done
}

# ======================================================
main() {
    touch "$LOG_FILE" 2>/dev/null || { LOG_FILE="$LOG_FILE_FALLBACK"; touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/dev/null"; }
    
    log "${INFO} Запуск: $(date)"
    
    check_dependencies || { echo -e "${CROSS_MARK} Ошибка зависимостей"; exit 1; }
    
    ensure_managers
    
    while true; do
        show_header; show_main_menu
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        read -p "Выберите (0-2): " c
        [[ -z "$c" || ! "$c" =~ ^[0-2]$ ]] && { echo -e "${CROSS_MARK} Неверно"; continue; }
        case $c in
            1) server_menu_loop ;;
            2) tests_menu_loop ;;
            0) echo -e "${CHECK_MARK} Выход"; log "${INFO} Завершён"; exit 0 ;;
        esac
    done
}

# ======================================================
main "$@"
