#!/bin/bash
# ======================================================
# Setup & Test Server Ubuntu 24.04
# https://github.com/Balbuto/Setup-and-Test-Server-Ubuntu-24
# Версия: 3.1
#
# Основано на v2 от Balbuto
# v3.1: исправлены ошибки IFS, sysctl-конфликты, LOG_FILE, аргументы тестов
# ======================================================

set -Eeuo pipefail

# --- Цвета ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'
CHECK_MARK="✅"; CROSS_MARK="❌"; WARNING="⚠️"; INFO="ℹ️"

LOG_FILE=""
BACKUP_DIR="/root/server-setup-backups/$(date +%Y%m%d-%H%M%S)"

# --- Логирование без цветов ---
strip_ansi() { sed -r 's/\x1B\[[0-9;]*[mK]//g'; }
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "$msg" | strip_ansi
    if [[ -n "${LOG_FILE:-}" && -w "$(dirname "$LOG_FILE" 2>/dev/null || echo /tmp)" ]]; then
        echo -e "$msg" | strip_ansi >> "$LOG_FILE" 2>/dev/null || true
    fi
}

init_logging() {
    for path in "/var/log/server-setup.log" "/tmp/server-setup.log" "$HOME/server-setup.log"; do
        if touch "$path" 2>/dev/null; then
            LOG_FILE="$path"
            log "Лог: $LOG_FILE"
            return 0
        fi
    done
    LOG_FILE="/dev/null"
    echo -e "${WARNING} Логирование в файл отключено, использую /dev/null" >&2
}
log_file() { echo "${LOG_FILE:-/dev/null}"; }

backup_file() {
    local f="$1"
    if [[ -f "$f" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$f" "$BACKUP_DIR/$(echo "$f" | tr '/' '_').bak"
        log "Backup: $f -> $BACKUP_DIR"
    fi
}

# ======================================================
# APT тихие обёртки
# ======================================================
export DEBIAN_FRONTEND=noninteractive
APT_QUIET="-qq -o Dpkg::Use-Pty=0"

apt_update() {
    echo -ne "${BLUE}📦 Обновление списков пакетов...${NC}"
    if apt-get update $APT_QUIET >>"$(log_file)" 2>&1; then
        echo -e "\r${GREEN}📦 Списки пакетов обновлены          ${NC}"
    else
        echo -e "\r${CROSS_MARK} ${RED}apt update failed, см. $LOG_FILE${NC}"
        return 1
    fi
}

apt_install() {
    local pkgs=("$@")
    local pkgs_str
    printf -v pkgs_str '%s ' "${pkgs[@]}"
    echo -ne "${BLUE}📦 Устанавливаю: ${pkgs_str}...${NC}"
    if apt-get install -y $APT_QUIET "${pkgs[@]}" >>"$(log_file)" 2>&1; then
        echo -e "\r${CHECK_MARK} Установлено: ${pkgs_str}          ${NC}"
        log "apt install OK: ${pkgs_str}"
    else
        echo -e "\r${CROSS_MARK} ${RED}Ошибка установки ${pkgs_str}, см. $LOG_FILE${NC}"
        return 1
    fi
}

apt_upgrade_full() {
    echo -ne "${BLUE}📦 upgrade / dist-upgrade ...${NC}"
    if apt-get upgrade -y $APT_QUIET >>"$(log_file)" 2>&1 \
    && apt-get dist-upgrade -y $APT_QUIET >>"$(log_file)" 2>&1; then
        echo -e "\r${CHECK_MARK} Система обновлена              ${NC}"
    else
        echo -e "\r${CROSS_MARK} ${RED}upgrade failed, см. $LOG_FILE${NC}"
        return 1
    fi
}

apt_autoclean() {
    apt-get autoremove -y $APT_QUIET >>"$(log_file)" 2>&1 || true
    apt-get autoclean -y $APT_QUIET >>"$(log_file)" 2>&1 || true
}

need_cmd() {
    local cmd=$1; shift
    local pkgs=("$@")
    if [[ ${#pkgs[@]} -eq 0 ]]; then pkgs=("$cmd"); fi
    if ! command -v "$cmd" &>/dev/null; then
        if [[ $EUID -ne 0 ]]; then
            echo -e "${WARNING} Нужен root для установки $cmd, пропустите"
            return 1
        fi
        apt_install "${pkgs[@]}"
    fi
}

check_distro() {
    if [[ -f /etc/os-release ]]; then . /etc/os-release; fi
    if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
        echo -e "${WARNING} ${YELLOW}Оптимизировано для Ubuntu 24.04, у вас: ${PRETTY_NAME:-unknown}${NC}"
        read -p "Продолжить? (y/N): " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi
}
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${CROSS_MARK} ${RED}Нужен root: sudo $0${NC}"; return 1
    fi
    return 0
}

show_header() {
    clear
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}🚀 НАСТРОЙКА И ДИАГНОСТИКА СЕРВЕРА  v3.1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    . /etc/os-release 2>/dev/null || true
    echo -e "${BLUE} Система: ${PRETTY_NAME:-$(uname -a)}${NC}"
    echo -e "${BLUE} Ядро: $(uname -r)${NC}\n"
}
pause_prompt() { read -p "Нажмите Enter для продолжения..." _ || true; }

# ======================================================
# БЕЗОПАСНАЯ ЗАГРУЗКА
# ======================================================
secure_download() {
    local url="$1" dest="$2" expected_sha="${3:-}"
    echo -e "${INFO} Скачивание: ${CYAN}$url${NC}"
    
    if [[ ! "$url" =~ ^https:// ]]; then
        echo -e "${CROSS_MARK} ${RED}Заблокировано: только HTTPS разрешён${NC}"
        return 1
    fi
    if ! curl -fsSL --proto '=https' --tlsv1.2 --max-time 30 -o "$dest" "$url"; then
        echo -e "${CROSS_MARK} Не удалось скачать $url"
        return 1
    fi
    local sha; sha=$(sha256sum "$dest" | awk '{print $1}')
    echo -e "  SHA256: ${YELLOW}$sha${NC}"
    echo -e "  Размер: $(wc -c < "$dest") байт"
    if [[ -n "$expected_sha" ]]; then
        if [[ "$sha" != "$expected_sha" ]]; then
            echo -e "${CROSS_MARK} ${RED}Хэш не совпал! Ожидалось: $expected_sha${NC}"
            rm -f "$dest"; return 1
        else
            echo -e "${CHECK_MARK} Хэш совпал"
        fi
    else
        echo -e "${WARNING} Хэш для этого файла не задан в скрипте."
        echo "  Проверьте содержимое: less $dest"
        read -p "Запустить этот скрипт? (y/N): " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] || { rm -f "$dest"; return 1; }
    fi
    chmod +x "$dest"; return 0
}

run_verified_script() {
    local name="$1" url="$2" expected_sha="${3:-}"
    shift 3
    if [[ "${1:-}" == "--" ]]; then shift; fi
    local args=("$@")
    local tmp="/tmp/verified-$(echo "$name" | tr ' /' '_')-$$.sh"
    echo -e "\n${CYAN}━━━━━━━━ $name ━━━━━━━━${NC}"
    if secure_download "$url" "$tmp" "$expected_sha"; then
        log "Running verified script: $name $url ${args[*]:-}"
        bash "$tmp" "${args[@]}"
        local rc=$?
        rm -f "$tmp"; return $rc
    else
        echo -e "${CROSS_MARK} Пропуск $name"; return 1
    fi
}

# ======================================================
# 1. БАЗОВАЯ НАСТРОЙКА
# ======================================================
SYSCTL_CONF="/etc/sysctl.d/99-server.conf"
LIMITS_CONF="/etc/security/limits.d/99-server.conf"

clean_old_sysctl() {
    rm -f /etc/sysctl.d/99-server-safe.conf /etc/sysctl.d/99-xray-highload.conf /etc/sysctl.d/99-server-highload.conf 2>/dev/null || true
    rm -f /etc/security/limits.d/99-server-safe.conf /etc/security/limits.d/99-xray.conf /etc/security/limits.d/99-server-highload.conf 2>/dev/null || true
}

install_docker_apt() {
    echo -e "${BLUE}🐳 Установка Docker через официальный apt-репозиторий${NC}"
    apt_update; apt_install ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
    apt_update
    apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker >>"$(log_file)" 2>&1 || true
    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        usermod -aG docker "$SUDO_USER"
        log "Пользователь $SUDO_USER добавлен в группу docker"
    fi
    log "Docker установлен: $(docker --version)"
}

enable_bbr() {
    backup_file "$SYSCTL_CONF"; clean_old_sysctl
    cat > "$SYSCTL_CONF" <<'EOF'
# BBR TCP congestion control
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    sysctl -p "$SYSCTL_CONF" >>"$(log_file)" 2>&1 || true
    log "BBR включён"
}

apply_sysctl_safe() {
    backup_file "$SYSCTL_CONF"; clean_old_sysctl
    cat > "$SYSCTL_CONF" <<'EOF'
# Server hardening - Ubuntu 24.04 SAFE
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
fs.file-max = 524288
vm.swappiness = 10
vm.max_map_count = 262144
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 5000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.netfilter.nf_conntrack_max = 65536
EOF
    backup_file "$LIMITS_CONF"
    cat > "$LIMITS_CONF" <<'EOF'
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
EOF
    sysctl --system >>"$(log_file)" 2>&1 || true
    log "SAFE sysctl применён"
}

apply_sysctl_highload() {
    echo -e "${WARNING} ${YELLOW}HIGHLOAD профиль: nofile 1M+, conntrack 2M. Для XRAY/VPN на мощных серверах.${NC}"
    read -p "Точно применить HIGHLOAD? (y/N): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || return 0
    backup_file "$SYSCTL_CONF"; clean_old_sysctl
    cat > "$SYSCTL_CONF" <<'EOF'
# Server HIGHLOAD - XRAY / VPN
fs.file-max = 2097152
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 1048576
vm.swappiness = 10
vm.max_map_count = 262144
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.somaxconn = 1048576
net.core.netdev_max_backlog = 262144
net.core.optmem_max = 67108864
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_max_syn_backlog = 1048576
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_max_tw_buckets = 2000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384
net.ipv4.ip_local_port_range = 1024 65535
net.netfilter.nf_conntrack_max = 2097152
net.netfilter.nf_conntrack_tcp_timeout_established = 600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 30
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 15
net.netfilter.nf_conntrack_udp_timeout = 30
net.netfilter.nf_conntrack_udp_timeout_stream = 120
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ratelimit = 100
net.ipv4.neigh.default.gc_thresh1 = 4096
net.ipv4.neigh.default.gc_thresh2 = 8192
net.ipv4.neigh.default.gc_thresh3 = 16384
EOF
    backup_file "$LIMITS_CONF"
    cat > "$LIMITS_CONF" <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
    sysctl --system >>"$(log_file)" 2>&1 || true
    log "HIGHLOAD sysctl применён"
}

ipv6_menu() {
    show_header; echo -e "${WHITE}Управление IPv6${NC}\n"
    if sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q 1; then echo -e "Статус: ${RED}Отключён${NC}"; else echo -e "Статус: ${GREEN}Включён${NC}"; fi
    echo ""; echo "1) Отключить IPv6 (с бэкапом + restore-скрипт)"; echo "2) Включить IPv6 обратно"; echo "0) Назад"
    read -p "Выбор: " c
    case $c in
        1) backup_file /etc/sysctl.d/70-disable-ipv6.conf
            cat > /etc/sysctl.d/70-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
            sysctl --system >>"$(log_file)" 2>&1 || true
            cat > /root/restore-ipv6.sh <<'RESTORE'
#!/bin/bash
rm -f /etc/sysctl.d/70-disable-ipv6.conf
sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0
sysctl -w net.ipv6.conf.lo.disable_ipv6=0
sysctl --system
echo "IPv6 включён обратно"
RESTORE
            chmod +x /root/restore-ipv6.sh
            echo -e "${CHECK_MARK} IPv6 отключён. Откат: ${YELLOW}/root/restore-ipv6.sh${NC}"
            log "IPv6 disabled"; pause_prompt ;;
        2) rm -f /etc/sysctl.d/70-disable-ipv6.conf
            sysctl -w net.ipv6.conf.all.disable_ipv6=0 >>"$(log_file)" 2>&1 || true
            sysctl -w net.ipv6.conf.default.disable_ipv6=0 >>"$(log_file)" 2>&1 || true
            sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >>"$(log_file)" 2>&1 || true
            sysctl --system >>"$(log_file)" 2>&1 || true
            echo -e "${CHECK_MARK} IPv6 включён"; pause_prompt ;;
    esac
}

base_setup() {
    show_header; echo -e "${WHITE}БАЗОВАЯ НАСТРОЙКА - выберите шаги${NC}\n"
    read -p "1. Обновить систему? [Y/n] " a_update; a_update=${a_update:-Y}
    read -p "2. Установить базовый софт (mc, net-tools, ncdu, iftop, curl, wget, git)? [Y/n] " a_base; a_base=${a_base:-Y}
    read -p "3. Установить Docker (apt + GPG)? [Y/n] " a_docker; a_docker=${a_docker:-Y}
    read -p "4. Включить BBR? [Y/n] " a_bbr; a_bbr=${a_bbr:-Y}
    echo "5. Hardening профиль: [s]afe / [h]ighload / [n]one"
    read -p "Выбор [s]: " a_hard; a_hard=${a_hard:-s}
    read -p "6. Установить irqbalance? [Y/n] " a_irq; a_irq=${a_irq:-Y}
    echo ""
    if [[ $a_update =~ ^[Yy] ]]; then apt_update; apt_upgrade_full; apt_autoclean; fi
    if [[ $a_base =~ ^[Yy] ]]; then apt_install mc net-tools ncdu iftop curl wget git ca-certificates gnupg lsb-release; fi
    if [[ $a_docker =~ ^[Yy] ]]; then if ! command -v docker &>/dev/null; then install_docker_apt; else echo "Docker уже установлен"; fi; fi
    if [[ $a_bbr =~ ^[Yy] ]]; then enable_bbr; fi
    case $a_hard in s|S) apply_sysctl_safe ;; h|H) apply_sysctl_highload ;; *) echo "Hardening пропущен" ;; esac
    if [[ $a_irq =~ ^[Yy] ]]; then apt_install irqbalance; systemctl enable --now irqbalance >>"$(log_file)" 2>&1 || true; fi
    echo -e "\n${CHECK_MARK} Готово! Бэкапы в: $BACKUP_DIR"
    echo -e "Полный лог apt: ${BLUE}$LOG_FILE${NC}"
    if [[ -f /var/run/reboot-required ]]; then echo -e "${WARNING} Требуется перезагрузка"; read -p "Перезагрузить сейчас? (y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] && reboot; fi
    pause_prompt
}

manage_ufw() {
    show_header; check_root || { pause_prompt; return; }
    local UFW_DIR="$HOME/network-managers/ufw-manager"
    mkdir -p "$(dirname "$UFW_DIR")"
    if [[ ! -d "$UFW_DIR/.git" ]]; then echo "Клонирую Balbuto/ufw-manager..."; git clone https://github.com/Balbuto/ufw-manager.git "$UFW_DIR"
    else (cd "$UFW_DIR" && git fetch --all -q); fi
    cd "$UFW_DIR"; echo -e "\nПоследние коммиты:"; git log --oneline -5; echo ""
    read -p "Проверить diff перед запуском? [Y/n] " d; d=${d:-Y}
    if [[ $d =~ ^[Yy] ]]; then git diff HEAD || true; read -p "Запустить ufw-manager.sh? (y/N): " -n 1 -r; echo; [[ $REPLY =~ ^[Yy]$ ]] || { cd ~; return; }; fi
    export SSH_CLIENT="${SSH_CLIENT:-0.0.0.0 22 0}"
    bash ./ufw-manager.sh; cd ~
}

run_multitest() {
    show_header; echo -e "🧪 ДИАГНОСТИКА - все скрипты верифицируются\n"
    need_cmd curl curl || true; need_cmd wget wget || true; need_cmd traceroute traceroute || true
    local H_IPREG="" H_CENSOR="" H_IPERF="" H_YABS="" H_IPCHECK="" H_BENCH="" H_IPQUALITY=""
    while true; do
    show_header
    echo -e "${CYAN}── ДОСТУПНЫЕ ТЕСТЫ (с верификацией) ──${NC}\n"
    echo " 1) IP Region"
    echo " 2) Censorcheck — геоблок"
    echo " 3) Censorcheck — DPI"
    echo " 4) iPerf3 — RU сервера"
    echo " 5) YABS"
    echo " 6) IP Check Place"
    echo " 7) bench.sh"
    echo " 8) IPQuality"
    echo " 9) sysbench CPU"
    echo "10) sysbench Memory"
    echo "11) Network Bench"
    echo "12) SSL/TLS check"
    echo "13) Traceroute yandex.ru"
    echo "14) Ping yandex.ru"
    echo "99) Запустить ВСЕ"
    echo " 0) Назад"
    read -p "Выбор: " choice; echo ""
    case $choice in
      1) run_verified_script "IP Region" "https://ipregion.vrnt.xyz" "$H_IPREG" || true; pause_prompt ;;
      2) run_verified_script "Censorcheck" "https://github.com/vernette/censorcheck/raw/master/censorcheck.sh" "$H_CENSOR" -- --mode geoblock || true; pause_prompt ;;
      3) run_verified_script "Censorcheck DPI" "https://github.com/vernette/censorcheck/raw/master/censorcheck.sh" "$H_CENSOR" -- --mode dpi || true; pause_prompt ;;
      4) need_cmd iperf3 iperf3 || true; run_verified_script "iPerf3 RU" "https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh" "$H_IPERF" || true; pause_prompt ;;
      5) run_verified_script "YABS" "https://yabs.sh" "$H_YABS" -- -4 || true; pause_prompt ;;
      6) run_verified_script "IP Check Place" "https://ip.check.place/script/check.sh" "$H_IPCHECK" -- -l en || true; pause_prompt ;;
      7) run_verified_script "bench.sh" "https://bench.sh" "$H_BENCH" || true; pause_prompt ;;
      8) run_verified_script "IPQuality" "https://check.place/script/check.sh" "$H_IPQUALITY" -- -l en || true; pause_prompt ;;
      9) need_cmd sysbench sysbench || true; sysbench cpu run || true; pause_prompt ;;
      10) need_cmd sysbench sysbench || true; sysbench memory run || true; pause_prompt ;;
      11) echo "Тест скорости: файлы 100MB"; wget -qO /dev/null http://speedtest.tele2.net/100MB.zip || wget -qO /dev/null http://ipv4.download.thinkbroadband.com/100MB.zip || true; pause_prompt ;;
      12) { openssl s_client -connect google.com:443 -tls1_2 </dev/null 2>&1 | grep -q "Protocol" && echo "TLS 1.2 OK"; } || echo "TLS 1.2 недоступен"; { openssl s_client -connect google.com:443 -tls1_3 </dev/null 2>&1 | grep -q "Protocol" && echo "TLS 1.3 OK"; } || echo "TLS 1.3 недоступен"; pause_prompt ;;
      13) traceroute -n yandex.ru || tracepath yandex.ru || true; pause_prompt ;;
      14) ping -c 4 yandex.ru || true; pause_prompt ;;
      99)
        run_verified_script "IP Region" "https://ipregion.vrnt.xyz" "$H_IPREG" || true
        run_verified_script "Censorcheck" "https://github.com/vernette/censorcheck/raw/master/censorcheck.sh" "$H_CENSOR" -- --mode geoblock || true
        run_verified_script "Censorcheck DPI" "https://github.com/vernette/censorcheck/raw/master/censorcheck.sh" "$H_CENSOR" -- --mode dpi || true
        need_cmd iperf3 iperf3 || true; run_verified_script "iPerf3 RU" "https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh" "$H_IPERF" || true
        run_verified_script "YABS" "https://yabs.sh" "$H_YABS" -- -4 || true
        run_verified_script "IP Check Place" "https://ip.check.place/script/check.sh" "$H_IPCHECK" -- -l en || true
        run_verified_script "bench.sh" "https://bench.sh" "$H_BENCH" || true
        run_verified_script "IPQuality" "https://check.place/script/check.sh" "$H_IPQUALITY" -- -l en || true
        need_cmd sysbench sysbench || true; sysbench cpu run || true; sysbench memory run || true
        echo "Все тесты завершены"; pause_prompt ;;
      0) return ;;
      *) echo "Неверный выбор"; sleep 1 ;;
    esac
    done
}

main() {
    init_logging; mkdir -p "$BACKUP_DIR" 2>/dev/null || true; check_distro
    trap 'echo -e "\n${YELLOW}Прервано${NC}"; exit 130' INT
    while true; do
        show_header
        echo -e "${WHITE}ГЛАВНОЕ МЕНЮ:${NC}\n"
        echo " 1. Базовая настройка сервера (выборочно)"
        echo " 2. Управление IPv6 (вкл/выкл + откат)"
        echo " 3. Управление файерволом UFW"
        echo " 4. Диагностика Multitest"
        echo ""
        echo " 5. Применить SAFE sysctl отдельно"
        echo " 6. Применить HIGHLOAD sysctl отдельно"
        echo ""
        echo " 0. Выйти"
        echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
        read -p "Выбор: " choice || choice=0
        case $choice in
            1) check_root && base_setup || { echo "Нужен root"; pause_prompt; } ;;
            2) check_root && ipv6_menu || { echo "Нужен root"; pause_prompt; } ;;
            3) manage_ufw ;;
            4) run_multitest ;;
            5) check_root && apply_sysctl_safe && pause_prompt || { echo "Нужен root"; pause_prompt; } ;;
            6) check_root && apply_sysctl_highload && pause_prompt || { echo "Нужен root"; pause_prompt; } ;;
            0) log "Exit"; exit 0 ;;
            *) echo "Неверно"; sleep 1 ;;
        esac
    done
}
main "$@"
