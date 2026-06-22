# Sysctl профили

Скрипт предлагает 2 профиля hardening. Оба включают BBR.

**Важно (v3.1+)**: оба профиля пишут в **один и тот же файл**:
```
/etc/sysctl.d/99-server.conf
/etc/security/limits.d/99-server.conf
```
Старые файлы от v3.0 / v2 (`99-server-safe.conf`, `99-xray-highload.conf`, `99-server-highload.conf`) автоматически удаляются через `clean_old_sysctl()` — конфликтов нет.

## SAFE — по умолчанию

Для обычного VPS 1-4 ГБ RAM, веб-сервер, базы, docker.

```
# BBR
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# Файлы / память
fs.file-max = 524288
vm.swappiness = 10
vm.max_map_count = 262144

# Сеть
net.core.somaxconn = 4096
net.core.netdev_max_backlog = 5000
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 600

# Безопасность
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1

# conntrack
net.netfilter.nf_conntrack_max = 65536

# limits
* soft nofile 65535
* hard nofile 65535
```

## HIGHLOAD — XRAY / VPN

Для мощных серверов с тысячами одновременных соединений.

```
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

# Безопасность
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

# limits
* soft nofile 1048576
* hard nofile 1048576
```

## Сравнение

| Параметр | SAFE | HIGHLOAD | x |
|---|---|---|---|
| file-max | 524k | 2M | 4x |
| nofile | 65k | 1M | 16x |
| somaxconn | 4096 | 1M | 256x |
| netdev_max_backlog | 5k | 262k | 52x |
| rmem/wmem_max | 16 MB | 128 MB | 8x |
| conntrack_max | 65k | 2M | 32x |
| tcp_fin_timeout | 30s | 10s | - |
| inotify watches | default | 1M | - |
| neigh gc_thresh | default | 4k/8k/16k | - |

**Когда использовать SAFE:**
- Веб-сервер, БД, обычные docker-контейнеры
- VPS ≤ 4 ГБ RAM
- < 10k одновременных соединений

**Когда использовать HIGHLOAD:**
- XRAY / VLESS / VMess / Shadowsocks прокси
- > 10k одновременных соединений
- Сервер ≥ 4 ГБ RAM
- Нужен QUIC / UDP flood resilience

HIGHLOAD на маленьком VPS может съесть всю память под conntrack/сокет-буферы.

## Применение

Через меню:
- `5. Применить SAFE sysctl отдельно`
- `6. Применить HIGHLOAD sysctl отдельно`

Или вручную в коде:
```bash
sudo bash -c 'source server-setup.sh; init_logging; apply_sysctl_safe'
```

HIGHLOAD всегда спрашивает подтверждение.

При применении любого профиля старые конфликтующие файлы автоматически удаляются:
- `/etc/sysctl.d/99-server-safe.conf`
- `/etc/sysctl.d/99-xray-highload.conf`
- `/etc/sysctl.d/99-server-highload.conf`
- `/etc/security/limits.d/99-server-safe.conf`
- `/etc/security/limits.d/99-xray.conf`
- `/etc/security/limits.d/99-server-highload.conf`

Актуальные файлы всегда:
```
/etc/sysctl.d/99-server.conf
/etc/security/limits.d/99-server.conf
```

## Откат

Бэкап оригинальных файлов: `/root/server-setup-backups/YYYYMMDD-HHMMSS/`

Откат:
```bash
rm /etc/sysctl.d/99-server.conf
rm /etc/security/limits.d/99-server.conf
sysctl --system
```

Или скопируйте бэкап обратно и `sysctl --system`.

Для отката на дефолты Ubuntu просто удалите оба файла и перезагрузитесь.
