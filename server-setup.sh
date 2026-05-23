#!/bin/bash

# ======================================================
# Универсальный скрипт настройки и диагностики сервера
# Предназначен для Ubuntu 24.04 LTS
# - Базовая настройка (установка ПО, BBR, отключение IPv6, тюнинг системы)
# - Управление файерволом UFW
# - Диагностика (Multitest с интеграцией всех проверок)
# Версия: 2
# ======================================================

set -e

# --- Цвета и оформление ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

CHECK_MARK="✅"
CROSS_MARK="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
LOCK="🔒"
GEAR="⚙️"
TEST_TUBE="🧪"
PACKAGE="📦"
DOCKER="🐳"
GLOBE="🌍"

# --- Переменные ---
MANAGER_DIR="$HOME/network-managers"
LOG_FILE=""

# --- Функция инициализации логирования ---
init_logging() {
    local possible_paths=("/var/log/server-setup.log" "/tmp/server-setup.log" "$HOME/server-setup.log")
    for path in "${possible_paths[@]}"; do
        if touch "$path" 2>/dev/null && echo "LOG INIT" >> "$path" 2>/dev/null; then
            LOG_FILE="$path"
            echo -e "${INFO} Логирование будет вестись в файл: $LOG_FILE" >&2
            log "Скрипт запущен, лог-файл инициализирован."
            return 0
        fi
    done
    LOG_FILE=""
    echo -e "${WARNING} ${YELLOW}Не удалось создать лог-файл ни в одном из мест. Логирование отключено.${NC}" >&2
    return 0
}

# --- Функция логирования (безопасная) ---
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$message"
    if [[ -n "$LOG_FILE" && -w "$(dirname "$LOG_FILE")" ]]; then
        echo -e "$message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# --- Проверка дистрибутива ---
check_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "24.04" ]]; then
            echo -e "${WARNING} ${YELLOW}Скрипт оптимизирован для Ubuntu 24.04 LTS.${NC}"
            echo -e "${INFO} Ваша система: $PRETTY_NAME"
            read -p "Продолжить? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    else
        echo -e "${WARNING} ${YELLOW}Не удалось определить дистрибутив. Продолжение на ваш риск.${NC}"
        read -p "Нажмите Enter для продолжения или Ctrl+C для выхода..."
    fi
}

# --- Проверка прав root ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${CROSS_MARK} ${RED}Для этого действия нужны root-права!${NC}"
        echo -e "${INFO} Используйте: sudo $0"
        return 1
    fi
    return 0
}

# --- Установка базовых зависимостей скрипта (wget, curl, git) ---
check_dependencies() {
    log "Проверка и установка базовых зависимостей (wget, curl, git)..."
    local deps=("wget" "curl" "git")
    local missing=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        apt-get update -qq
        apt-get install -y -qq "${missing[@]}"
        log "Установлены зависимости: ${missing[*]}"
    fi
}

# --- Заголовок ---
show_header() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}${ROCKET}        ИНТЕРАКТИВНАЯ НАСТРОЙКА И ДИАГНОСТИКА СЕРВЕРА        ${ROCKET}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo -e "${BLUE}  Система:      $PRETTY_NAME${NC}"
    fi
    echo -e "${BLUE}  Ядро:         $(uname -r)${NC}"
    echo -e "${BLUE}  Архитектура:  $(uname -m)${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

pause_prompt() {
    echo ""
    read -p "Нажмите Enter для продолжения..."
}

# ======================================================
# 1. БАЗОВАЯ НАСТРОЙКА СЕРВЕРА (ВСЁ В ОДНОМ)
# ======================================================
base_setup() {
    show_header
    echo -e "${GEAR} ${WHITE}ЗАПУСК БАЗОВОЙ НАСТРОЙКИ СЕРВЕРА${NC}\n"
    log "Начало базовой настройки."

    # --- 1.1 Обновление системы ---
    echo -e "${PACKAGE} [1/7] Обновление системы..."
    apt-get update -qq
    apt-get upgrade -y -qq
    apt-get dist-upgrade -y -qq
    apt-get autoremove -y -qq
    apt-get autoclean -qq
    log "Система обновлена."

    # --- 1.2 Установка базового ПО (mc, net-tools) ---
    echo -e "${PACKAGE} [2/7] Установка mc и net-tools..."
    apt-get install -y -qq mc net-tools
    log "Установлены mc, net-tools."

    # --- 1.3 Установка Docker и Docker Compose ---
    echo -e "${DOCKER} [3/7] Установка Docker и Docker Compose..."
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh &>> "$( [[ -n "$LOG_FILE" ]] && echo "$LOG_FILE" || echo "/dev/null" )"
        rm get-docker.sh
        if [[ -n "$SUDO_USER" ]]; then
            usermod -aG docker "$SUDO_USER"
            log "Пользователь $SUDO_USER добавлен в группу docker."
        fi
        apt-get install -y -qq docker-compose-plugin
        systemctl enable docker --now
        log "Docker и Docker Compose установлены и запущены."
    else
        echo -e "${CHECK_MARK} Docker уже установлен: $(docker --version)"
        log "Docker уже был установлен."
    fi

    # --- 1.4 Включение BBR (только здесь, без дублирования) ---
    echo -e "${ROCKET} [4/7] Включение BBR..."
    {
        echo "# BBR TCP congestion control (from xray-tune-hardening)"
        echo "net.core.default_qdisc = fq"
        echo "net.ipv4.tcp_congestion_control = bbr"
    } > /etc/sysctl.d/99-xray-highload.conf
    sysctl -p /etc/sysctl.d/99-xray-highload.conf &>> "$( [[ -n "$LOG_FILE" ]] && echo "$LOG_FILE" || echo "/dev/null" )"
    log "BBR включен."

    # --- 1.5 Отключение IPv6 ---
    echo -e "${GLOBE} [5/7] Отключение IPv6..."
    {
        echo "# Отключение IPv6"
        echo "net.ipv6.conf.all.disable_ipv6 = 1"
        echo "net.ipv6.conf.default.disable_ipv6 = 1"
        echo "net.ipv6.conf.lo.disable_ipv6 = 1"
    } > /etc/sysctl.d/70-disable-ipv6.conf
    sysctl --system &>> "$( [[ -n "$LOG_FILE" ]] && echo "$LOG_FILE" || echo "/dev/null" )"
    log "IPv6 отключен."

    # --- 1.6 Server Hardening (sysctl и limits) ---
    echo -e "${LOCK} [6/7] Применение параметров производительности (Hardening)..."
    # Добавляем остальные параметры, НО без дублирования BBR
    {
        echo "######################################################################"
        echo "# XRAY HIGHLOAD / ANTI-FLOOD / QUIC OPTIMIZED"
        echo "######################################################################"
        echo "fs.file-max = 2097152"
        echo "fs.inotify.max_user_instances = 8192"
        echo "fs.inotify.max_user_watches = 1048576"
        echo "vm.swappiness = 10"
        echo "vm.max_map_count = 262144"
        echo "vm.dirty_ratio = 10"
        echo "vm.dirty_background_ratio = 5"
        echo "net.core.somaxconn = 1048576"
        echo "net.core.netdev_max_backlog = 262144"
        echo "net.core.optmem_max = 67108864"
        echo "net.core.rmem_default = 262144"
        echo "net.core.wmem_default = 262144"
        echo "net.core.rmem_max = 134217728"
        echo "net.core.wmem_max = 134217728"
        echo "net.ipv4.tcp_syncookies = 1"
        echo "net.ipv4.tcp_synack_retries = 2"
        echo "net.ipv4.tcp_syn_retries = 3"
        echo "net.ipv4.tcp_max_syn_backlog = 1048576"
        echo "net.ipv4.tcp_fin_timeout = 10"
        echo "net.ipv4.tcp_keepalive_time = 600"
        echo "net.ipv4.tcp_keepalive_intvl = 30"
        echo "net.ipv4.tcp_keepalive_probes = 5"
        echo "net.ipv4.tcp_max_tw_buckets = 2000000"
        echo "net.ipv4.tcp_tw_reuse = 1"
        echo "net.ipv4.tcp_fastopen = 3"
        echo "net.ipv4.tcp_mtu_probing = 1"
        echo "net.ipv4.tcp_rmem = 4096 87380 67108864"
        echo "net.ipv4.tcp_wmem = 4096 65536 67108864"
        echo "net.ipv4.udp_rmem_min = 16384"
        echo "net.ipv4.udp_wmem_min = 16384"
        echo "net.ipv4.ip_local_port_range = 1024 65535"
        echo "net.netfilter.nf_conntrack_max = 2097152"
        echo "net.netfilter.nf_conntrack_tcp_timeout_established = 600"
        echo "net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30"
        echo "net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30"
        echo "net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30"
        echo "net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 15"
        echo "net.netfilter.nf_conntrack_udp_timeout = 30"
        echo "net.netfilter.nf_conntrack_udp_timeout_stream = 120"
        echo "net.ipv4.conf.all.rp_filter = 1"
        echo "net.ipv4.conf.default.rp_filter = 1"
        echo "net.ipv4.conf.all.accept_redirects = 0"
        echo "net.ipv4.conf.default.accept_redirects = 0"
        echo "net.ipv4.conf.all.send_redirects = 0"
        echo "net.ipv4.conf.default.send_redirects = 0"
        echo "net.ipv4.conf.all.accept_source_route = 0"
        echo "net.ipv4.conf.default.accept_source_route = 0"
        echo "net.ipv4.conf.all.log_martians = 1"
        echo "net.ipv4.icmp_echo_ignore_broadcasts = 1"
        echo "net.ipv4.icmp_ratelimit = 100"
        echo "net.ipv4.neigh.default.gc_thresh1 = 4096"
        echo "net.ipv4.neigh.default.gc_thresh2 = 8192"
        echo "net.ipv4.neigh.default.gc_thresh3 = 16384"
    } >> /etc/sysctl.d/99-xray-highload.conf

    {
        echo "* soft nofile 1048576"
        echo "* hard nofile 1048576"
        echo "root soft nofile 1048576"
        echo "root hard nofile 1048576"
    } > /etc/security/limits.d/99-xray.conf

    mkdir -p /etc/systemd/system/xray.service.d/
    {
        echo "[Service]"
        echo "LimitNOFILE=1048576"
        echo "LimitNPROC=1048576"
    } > /etc/systemd/system/xray.service.d/override.conf
    systemctl daemon-reload

    sysctl --system &>> "$( [[ -n "$LOG_FILE" ]] && echo "$LOG_FILE" || echo "/dev/null" )"
    apt-get install -y -qq irqbalance
    systemctl enable irqbalance &>> "$( [[ -n "$LOG_FILE" ]] && echo "$LOG_FILE" || echo "/dev/null" )"
    systemctl restart irqbalance &>> "$( [[ -n "$LOG_FILE" ]] && echo "$LOG_FILE" || echo "/dev/null" )"
    log "Параметры hardening применены."

    # --- 1.7 Завершение ---
    echo -e "${CHECK_MARK} [7/7] Базовая настройка завершена!"
    log "Базовая настройка завершена успешно."

    if [[ -f /var/run/reboot-required ]]; then
        echo -e "\n${WARNING} ${YELLOW}Для применения всех настроек рекомендуется перезагрузить сервер.${NC}"
        read -p "Перезагрузить сейчас? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Перезагрузка по требованию пользователя."
            reboot
        fi
    fi
    pause_prompt
}

# ======================================================
# 2. УПРАВЛЕНИЕ ФАЙЕРВОЛОМ (UFW Manager)
# ======================================================
manage_ufw() {
    show_header
    echo -e "${LOCK} ${WHITE}ЗАПУСК МЕНЕДЖЕРА UFW${NC}\n"
    
    if ! check_root; then
        pause_prompt
        return
    fi
    
    mkdir -p "$MANAGER_DIR/ufw-manager"
    cd "$MANAGER_DIR/ufw-manager"
    
    if [[ ! -f "ufw-manager.sh" ]]; then
        log "Скачивание ufw-manager.sh"
        wget -q https://raw.githubusercontent.com/Balbuto/ufw-manager/main/ufw-manager.sh -O ufw-manager.sh
        chmod +x ufw-manager.sh
    fi
    
    export SSH_CLIENT="${SSH_CLIENT:-0.0.0.0 22 0}"
    log "Запуск ufw-manager.sh"
    ./ufw-manager.sh
    
    cd ~
}

# ======================================================
# 3. МУЛЬТИТЕСТ (интегрированная диагностика)
# ======================================================
run_multitest() {
    show_header
    echo -e "${TEST_TUBE} ${WHITE}ЗАПУСК ДИАГНОСТИКИ MULTITEST${NC}\n"

    # --- Инициализация (скопировано из multitest.sh) ---
    SCRIPT_VERSION="1.1"
    REPO_URL="https://raw.githubusercontent.com/saveksme/multitest/master/multitest.sh"
    
    # Функции для работы с пакетами
    detect_pkg_manager() {
        if command -v apt-get &>/dev/null; then echo "apt"
        elif command -v dnf &>/dev/null; then echo "dnf"
        elif command -v yum &>/dev/null; then echo "yum"
        elif command -v apk &>/dev/null; then echo "apk"
        elif command -v pacman &>/dev/null; then echo "pacman"
        else echo "unknown"; fi
    }
    
    install_package() {
        local pkg="$1"
        local pm=$(detect_pkg_manager)
        echo -e "${YELLOW}Устанавливаю ${pkg}...${NC}"
        case "$pm" in
            apt) DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" ;;
            dnf) dnf install -y -q "$pkg" ;;
            yum) yum install -y -q "$pkg" ;;
            apk) apk add --quiet "$pkg" ;;
            pacman) pacman -S --noconfirm --quiet "$pkg" ;;
            *) echo -e "${RED}Не удалось определить пакетный менеджер. Установите ${pkg} вручную.${NC}"; return 1 ;;
        esac
    }
    
    check_and_install() {
        local cmd="$1"; local pkg="${2:-$1}"
        if ! command -v "$cmd" &>/dev/null; then
            echo -e "${YELLOW}${cmd} не найден.${NC}"
            install_package "$pkg"
        fi
        command -v "$cmd" &>/dev/null || { echo -e "${RED}Не удалось установить ${cmd}.${NC}"; return 1; }
        return 0
    }

    # Функции тестов
    print_separator() {
        echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e ">>> $1"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    }

    run_ip_region() {
        print_separator "IP Region"
        check_and_install wget
        bash <(wget -qO- https://ipregion.vrnt.xyz)
    }
    run_censorcheck_geoblock() {
        print_separator "Censorcheck — проверка геоблока"
        check_and_install wget
        bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode geoblock
    }
    run_censorcheck_dpi() {
        print_separator "Censorcheck — DPI (серверы РФ)"
        check_and_install wget
        bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode dpi
    }
    run_iperf3_ru() {
        print_separator "iPerf3 — тест до российских серверов"
        check_and_install wget; check_and_install iperf3
        bash <(wget -qO- https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh)
    }
    run_yabs() {
        print_separator "YABS — бенчмарк сервера"
        check_and_install curl
        curl -sL yabs.sh | bash -s -- -4
    }
    run_ip_check_place() {
        print_separator "IP Check Place — блокировки зарубежными сервисами"
        check_and_install curl
        bash <(curl -Ls IP.Check.Place) -l en
    }
    run_bench_sh() {
        print_separator "bench.sh — параметры сервера и скорость"
        check_and_install wget
        wget -qO- bench.sh | bash
    }
    run_ip_quality() {
        print_separator "IPQuality"
        check_and_install curl
        bash <(curl -Ls https://Check.Place) -EI
    }
    run_sysbench_cpu() {
        print_separator "sysbench CPU — тест процессора"
        check_and_install sysbench
        sysbench cpu run
    }
    run_sysbench_memory() {
        print_separator "sysbench Memory — тест оперативной памяти"
        check_and_install sysbench
        sysbench memory run
    }
    run_network_bench() {
        print_separator "Network Bench — тест скорости сети"
        check_and_install wget
        echo -e "${YELLOW}Тест скорости (wget)...${NC}"
        wget -qO /dev/null http://speedtest.tele2.net/100MB.zip
        echo -e "${GREEN}Тест скорости завершен.${NC}"
    }
    run_ssl_tls_check() {
        print_separator "SSL/TLS — проверка протоколов"
        check_and_install openssl
        echo -e "${YELLOW}Поддерживаемые версии TLS:${NC}"
        echo -n "TLS 1.2: "
        if echo "Q" | openssl s_client -connect google.com:443 -tls1_2 &>/dev/null; then echo -e "${GREEN}доступен${NC}"; else echo -e "${RED}недоступен${NC}"; fi
        echo -n "TLS 1.3: "
        if echo "Q" | openssl s_client -connect google.com:443 -tls1_3 &>/dev/null; then echo -e "${GREEN}доступен${NC}"; else echo -e "${RED}недоступен${NC}"; fi
    }
    run_traceroute_ru() {
        print_separator "Traceroute — до yandex.ru"
        check_and_install traceroute
        traceroute -n yandex.ru
    }
    run_ping_test() {
        print_separator "Ping — задержка до yandex.ru"
        ping -c 4 yandex.ru
    }

    # Меню тестов
    show_tests() {
        while true; do
            show_header
            echo -e "${CYAN}  ── ДОСТУПНЫЕ ТЕСТЫ ──${NC}\n"
            echo -e " ${GREEN} 1)${NC} IP Region"
            echo -e " ${GREEN} 2)${NC} Censorcheck — геоблок"
            echo -e " ${GREEN} 3)${NC} Censorcheck — DPI"
            echo -e " ${GREEN} 4)${NC} iPerf3 — до российских серверов"
            echo -e " ${GREEN} 5)${NC} YABS — бенчмарк сервера"
            echo -e " ${GREEN} 6)${NC} IP Check Place — блокировки"
            echo -e " ${GREEN} 7)${NC} bench.sh — параметры и скорость"
            echo -e " ${GREEN} 8)${NC} IPQuality"
            echo -e " ${GREEN} 9)${NC} sysbench CPU"
            echo -e " ${GREEN}10)${NC} sysbench Memory"
            echo -e " ${GREEN}11)${NC} Network Bench — тест скорости"
            echo -e " ${GREEN}12)${NC} SSL/TLS — проверка протоколов"
            echo -e " ${GREEN}13)${NC} Traceroute — до yandex.ru"
            echo -e " ${GREEN}14)${NC} Ping — задержка до yandex.ru"
            echo -e " ${GREEN}99)${NC} Запустить ВСЕ тесты"
            echo -e " ${RED} 0)${NC} Назад"
            echo ""
            read -p "Выберите тест: " choice

            case $choice in
                1) run_ip_region; pause_prompt ;;
                2) run_censorcheck_geoblock; pause_prompt ;;
                3) run_censorcheck_dpi; pause_prompt ;;
                4) run_iperf3_ru; pause_prompt ;;
                5) run_yabs; pause_prompt ;;
                6) run_ip_check_place; pause_prompt ;;
                7) run_bench_sh; pause_prompt ;;
                8) run_ip_quality; pause_prompt ;;
                9) run_sysbench_cpu; pause_prompt ;;
                10) run_sysbench_memory; pause_prompt ;;
                11) run_network_bench; pause_prompt ;;
                12) run_ssl_tls_check; pause_prompt ;;
                13) run_traceroute_ru; pause_prompt ;;
                14) run_ping_test; pause_prompt ;;
                99)
                    echo -e "\n${CYAN}Запуск всех тестов...${NC}"
                    run_ip_region
                    run_censorcheck_geoblock
                    run_censorcheck_dpi
                    run_iperf3_ru
                    run_yabs
                    run_ip_check_place
                    run_bench_sh
                    run_ip_quality
                    run_sysbench_cpu
                    run_sysbench_memory
                    run_network_bench
                    run_ssl_tls_check
                    run_traceroute_ru
                    run_ping_test
                    echo -e "\n${GREEN}Все тесты завершены!${NC}"
                    pause_prompt
                    ;;
                0) return ;;
                *) echo -e "${RED}Неверный выбор.${NC}"; pause_prompt ;;
            esac
        done
    }

    show_tests
}

# ======================================================
# МЕНЮ
# ======================================================
show_main_menu() {
    echo -e "${WHITE}ГЛАВНОЕ МЕНЮ:${NC}\n"
    echo -e "${GEAR} 1. Базовая настройка сервера (ПО, BBR, IPv6, Hardening)"
    echo -e "${LOCK} 2. Управление файерволом (UFW)"
    echo -e "${TEST_TUBE} 3. Запустить диагностику (Multitest)"
    echo -e "\n0. Выйти"
}

# ======================================================
# ОСНОВНАЯ ЛОГИКА
# ======================================================
main() {
    # Инициализация логирования
    init_logging
    
    # Проверка дистрибутива
    check_distro
    
    # Проверка и установка зависимостей (требует root)
    if check_root; then
        check_dependencies
    else
        echo -e "${WARNING} Некоторые зависимости (wget, curl, git) могут отсутствовать. Установите их вручную или запустите с sudo."
        for dep in wget curl git; do
            if ! command -v "$dep" &> /dev/null; then
                echo -e "${CROSS_MARK} Отсутствует $dep. Установите: sudo apt install $dep"
            fi
        done
    fi
    
    # Перехват Ctrl+C
    trap 'echo -e "\n${YELLOW}Операция прервана.${NC}"; exit 0' INT

    while true; do
        show_header
        show_main_menu
        echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        read -p "Выберите действие (0-3): " choice

        case $choice in
            1)
                if check_root; then
                    base_setup
                else
                    echo -e "${CROSS_MARK} ${RED}Базовая настройка требует root-прав.${NC}"
                    pause_prompt
                fi
                ;;
            2)
                manage_ufw
                ;;
            3)
                run_multitest
                ;;
            0)
                echo -e "\n${GREEN}До свидания!${NC}"
                log "Скрипт завершен."
                exit 0
                ;;
            *)
                echo -e "\n${RED}Неверный выбор.${NC}"
                pause_prompt
                ;;
        esac
    done
}

main "$@"
