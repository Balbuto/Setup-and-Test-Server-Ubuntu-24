# Тесты Multitest

14 встроенных тестов. Внешние скрипты загружаются через `secure_download()` с HTTPS + SHA256 верификацией.

## Список

| # | Название | Команда | Источник | Зависимости |
|---|---|---|---|---|
| 1 | IP Region | геолокация IP | https://ipregion.vrnt.xyz | wget |
| 2 | Censorcheck — геоблок | проверка геоблокировок | https://github.com/vernette/censorcheck/raw/master/censorcheck.sh --mode geoblock | wget |
| 3 | Censorcheck — DPI | проверка DPI (РФ) | censorcheck.sh --mode dpi | wget |
| 4 | iPerf3 — RU | скорость до российских серверов | https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh | iperf3, wget |
| 5 | YABS | CPU/диск/сеть бенчмарк | https://yabs.sh -4 | curl |
| 6 | IP Check Place | блокировки зарубежными сервисами | https://ip.check.place/script/check.sh -l en | curl |
| 7 | bench.sh | параметры сервера + скорость | https://bench.sh | wget |
| 8 | IPQuality | проверка репутации IP | https://check.place/script/check.sh -l en | curl |
| 9 | sysbench CPU | CPU тест | sysbench cpu run | sysbench |
| 10 | sysbench Memory | RAM тест | sysbench memory run | sysbench |
| 11 | Network Bench | wget 100MB | http://speedtest.tele2.net/100MB.zip → fallback http://ipv4.download.thinkbroadband.com/100MB.zip | wget |
| 12 | SSL/TLS check | TLS 1.2 / 1.3 | openssl s_client google.com:443 | openssl |
| 13 | Traceroute | до yandex.ru | traceroute -n yandex.ru | traceroute |
| 14 | Ping | до yandex.ru | ping -c 4 yandex.ru | ping |

Пункт **99** запускает все 1-14 по порядку.

Все пакеты (`sysbench`, `iperf3`, `traceroute`, `curl`, `wget`) устанавливаются автоматически, тихо, только если отсутствуют.

## Верификация

Функция `secure_download(url, dest, expected_sha)`:

1. Разрешает только `https://`
2. `curl --proto '=https' --tlsv1.2 --max-time 30`
3. Считает SHA256, показывает на экране
4. Если `expected_sha` задан - сверяет, при несовпадении удаляет файл
5. Если `expected_sha` пустой - спрашивает ручное подтверждение `y/N`

Пример вывода:
```
━━━━━━━━ YABS ━━━━━━━━
ℹ️ Скачивание: https://yabs.sh
  SHA256: 5f3b2c...
  Размер: 28451 байт
⚠️ Хэш для этого файла не задан в скрипте.
  Проверьте содержимое: less /tmp/verified-YABS-...
Запустить этот скрипт? (y/N):
```

## Как зафиксировать хэши

В `run_multitest()` есть переменные:

```bash
local H_IPREG=""
local H_CENSOR=""
local H_IPERF=""
local H_YABS=""
local H_IPCHECK=""
local H_BENCH=""
local H_IPQUALITY=""
```

1. Запустите каждый тест один раз, запишите показанный SHA256
2. Вставьте в скрипт:
   ```bash
   local H_YABS="5f3b2c..."
   ```
3. При следующем запуске скрипт автоматически проверит хэш, без интерактива

Для быстрого сбора хэшей всех 7 внешних скриптов:

```bash
for url in \
  https://ipregion.vrnt.xyz \
  https://github.com/vernette/censorcheck/raw/master/censorcheck.sh \
  https://github.com/itdoginfo/russian-iperf3-servers/raw/main/speedtest.sh \
  https://yabs.sh \
  https://ip.check.place/script/check.sh \
  https://bench.sh \
  https://check.place/script/check.sh
do
  echo "--- $url"
  curl -fsSL "$url" | sha256sum
done
```

**Внимание:** эти скрипты - живые, авторы их обновляют. Зафиксированный хэш может устареть через неделю/месяц. Это нормально - скрипт сообщит о несовпадении, вы подтвердите вручную и обновите хэш.

Если хотите всегда последнюю версию без пина - просто оставьте переменные пустыми, тогда будет ручное подтверждение каждый раз.

## Замена источников

Все URL захардкожены в функции `run_multitest()`, в `case` блоке. Просто отредактируйте их в `server-setup.sh`.

Пример - поменять IP Check Place на другую локаль:
```bash
run_verified_script "IP Check Place" "https://ip.check.place/script/check.sh" "$H_IPCHECK" "-l ru"
```
