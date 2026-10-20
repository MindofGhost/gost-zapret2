![Zapret2 Version](https://img.shields.io/badge/zapret2-v1.0.5-red)

Docker-контейнер на основе [zapret2 от bol-van](https://github.com/bol-van/zapret2) с интегрированным [gost](https://github.com/go-gost/gost) для подключения к контейнеру. Предназначен для удобной маршрутизации трафика через изолированную среду без модификации основной сети. Продолжение [ss-zapret](https://github.com/vernette/ss-zapret).

В отличие от [оригинального репозитория ss-zapret2](https://github.com/vernette/ss-zapret2), отдельный Shadowsocks заменён на gost-прокси. Цель — упростить контейнер и снизить потребление RAM. В gost уже встроено множество протоколов, включая Shadowsocks; параметры команды запуска позволяют включать только необходимые протоколы и отключать остальные.

- Изоляция zapret2 в отдельном контейнере
- Простая интеграция с sing-box, Xray и другими прокси-клиентами

> [!CAUTION]
> В режиме `nfqws` контейнер работает только на Linux из-за отсутствия `nfqueue` на других ОС

## Содержание

- [Быстрый старт](#быстрый-старт)
  - [Предварительные требования](#предварительные-требования)
  - [Установка и запуск](#установка-и-запуск)
- [Изменение конфигурации](#изменение-конфигурации)
- [Расширенные возможности](#расширенные-возможности)
  - [Поиск стратегий](#поиск-стратегий)
  - [Custom.d скрипты](#customd-скрипты)
  - [Lua](#lua)
  - [Fake-файлы](#fake-файлы)
  - [Проверка работы стратегий](#проверка-работы-стратегий)
  - [Интеграция с прокси-клиентами](#интеграция-с-прокси-клиентами)
- [Работа Instagram в браузере](#работа-instagram-в-браузере)
- [Сценарии использования](#сценарии-использования)
- [Разработка](#разработка)
- [Вклад в разработку](#вклад-в-разработку)
- [Предупреждение про доступ к прокси](#предупреждение-про-доступ-к-прокси)
- [Благодарности](#благодарности)

## Быстрый старт

### Предварительные требования

1. Установка git:

```bash
# Ubuntu/Debian
sudo apt install git

# Fedora
sudo dnf install git

# Arch Linux
sudo pacman -S git
```

2. Установка Docker:

```bash
bash <(wget -qO- https://get.docker.com)
```

### Установка и запуск

1. Клонируйте репозиторий:

```bash
git clone --branch gost https://github.com/MindofGhost/gost-zapret2
cd gost-zapret2
```

2. Скопируйте стандартный конфиг zapret2:

```bash
cp config.default config
```

3. Настройте gost в `docker-compose.yml`:

```yaml
    environment:
      GOST_COMMAND: "-L=:8888"
      GOST_VERBOSE: "0"
```

`GOST_COMMAND` обязателен: он задаёт аргументы запуска gost. В текущем примере используется порт `8888`, опубликованный только на `127.0.0.1` хоста по TCP и UDP. Проверка работоспособности контейнера также использует порт `8888`. При смене порта обновите `ports` и `healthcheck` в Compose.

| Переменная | Описание |
| ---------- | -------- |
| `GOST_COMMAND` | Аргументы запуска gost: необходимые протоколы, порты, авторизация и другие параметры |
| `GOST_VERBOSE` | `1` включает отладочные логи gost (`-D`), `0` отключает; по умолчанию `0` |

Чтобы хранить параметры в `.env`, скопируйте `.env.example`:

```bash
cp .env.example .env
```

```env
GOST_COMMAND="-L=:8888"
GOST_VERBOSE=0
```

И замените блок `environment` в `docker-compose.yml` на подстановки:

```yaml
    environment:
      GOST_COMMAND: "${GOST_COMMAND}"
      GOST_VERBOSE: "${GOST_VERBOSE:-0}"
```

Без этой подстановки значение `GOST_COMMAND` из `.env` не заменяет аргументы, заданные непосредственно в Compose. Переменные `SS_PORT`, `SOCKS_PORT`, `SS_PASSWORD`, `SS_ENCRYPT_METHOD`, `SS_TIMEOUT` и `SS_VERBOSE` больше не используются.

Параметры протоколов и примеры команд описаны в [репозитории gost](https://github.com/go-gost/gost), образ которого используется в Dockerfile (`go-gost/gost`).

4. Соберите и запустите контейнер из текущих исходников:

```bash
docker compose up -d --build
```

После изменения переменных окружения примените конфигурацию повторной командой `docker compose up -d`; обычный `restart` не обновляет переменные контейнера.

## Изменение конфигурации

Для внесения изменений в конфиг открываем его в текстовом редакторе:

```bash
nano config
```

Стратегия меняется в переменной `NFQWS2_OPT`, например:

```
NFQWS2_OPT="
--filter-tcp=80 --filter-l7=http --payload http_req --lua-desync=http_methodeol --new
--filter-tcp=443 --filter-l7=tls --payload=tls_client_hello --hostlist-domains=youtube.com,googlevideo.com,youtubei.googleapis.com --lua-desync=multisplit:pos=10:seqovl=1 --new
--filter-tcp=443 --filter-l7=tls --payload=tls_client_hello --lua-desync=multidisorder:pos=2 --new
--filter-udp=443 --filter-l7=quic --payload=quic_initial --lua-desync=fake:blob=fake_default_quic:repeats=6
"
```

- `--filter-tcp=80` - стратегия для всего HTTP трафика
- `--filter-tcp=443 ... --hostlist-domains=youtube.com,googlevideo.com,youtubei.googleapis.com` - стратегия для HTTPS для определенных доменов
- `--filter-tcp=443` - стратегия для всего остального HTTPS трафика
- `--filter-udp=443` - стратегия для всего HTTP3 (QUIC) трафика

После внесения изменений не забудьте перезапустить контейнер:

```bash
docker compose restart
```

## Расширенные возможности

### Поиск стратегий

Перед поиском стратегий нужно обязательно остановить zapret2 командой, чтобы поиск шёл без модификации трафика:

```bash
docker compose exec gost-zapret2 sh /opt/zapret2/init.d/sysv/zapret2 stop
```

Как и в оригинальном проекте, поиск стратегий осуществляется скриптом `blockcheck2.sh`. Этот скрипт подбирает оптимальные стратегии для вашего домашнего/хостинг провайдера:

```bash
docker compose exec gost-zapret2 sh /opt/zapret2/blockcheck2.sh
```

> [!TIP]
> К скрипту поиска можно применять дополнительные параметры. Более подробно в [оригинальном репозитории](https://github.com/bol-van/zapret?tab=readme-ov-file#%D0%BF%D1%80%D0%BE%D0%B2%D0%B5%D1%80%D0%BA%D0%B0-%D0%BF%D1%80%D0%BE%D0%B2%D0%B0%D0%B9%D0%B4%D0%B5%D1%80%D0%B0)

Пример запуска с параметрами:

```bash
docker compose exec gost-zapret2 sh -c 'REPEATS=8 DOMAINS="amnezia.org discord.com" /opt/zapret2/blockcheck2.sh'
```

#### Поиск стратегий для HTTP, HTTPS TLS 1.2, без HTTPS TLS 1.3 и HTTP3 (QUIC). Подходит для сайтов, которые не поддерживают TLS 1.3 (таких мало, но они есть)

```bash
docker compose exec gost-zapret2 sh -c 'SKIP_DNSCHECK=1 SECURE_DNS=0 IPVS=4 ENABLE_HTTP=1 ENABLE_HTTPS_TLS12=1 ENABLE_HTTPS_TLS13=0 ENABLE_HTTP3=0 REPEATS=8 PARALLEL=1 SCANLEVEL=standard BATCH=1 DOMAINS="amnezia.org discord.com" /opt/zapret2/blockcheck2.sh'
```

#### Поиск стратегий для HTTPS TLS 1.3, без HTTP, HTTPS TLS 1.2 и HTTP3 (QUIC). Подходит для большинства сайтов и серверов YouTube

```bash
docker compose exec gost-zapret2 sh -c 'SKIP_DNSCHECK=1 SECURE_DNS=0 IPVS=4 ENABLE_HTTP=0 ENABLE_HTTPS_TLS12=0 ENABLE_HTTPS_TLS13=1 ENABLE_HTTP3=0 REPEATS=8 PARALLEL=1 SCANLEVEL=standard BATCH=1 DOMAINS="xxxxxx.googlevideo.com" /opt/zapret2/blockcheck2.sh'
```

Вместо `xxxxxx.googlevideo.com` можно указать адрес ближайшего GGC сервера, который можно найти командой (требуется установленный `curl` и `jq`):

```bash
curl "https://www.youtube.com/youtubei/v1/player" \
  --silent \
  --request POST \
  --json '{"videoId":"dQw4w9WgXcQ","context":{"client":{"clientName":"ANDROID","clientVersion":"21.02.35","androidSdkVersion":30,"userAgent":"com.google.android.youtube/21.02.35(Linux;U;Android11)gzip","osName":"Android","osVersion":"11"}}}' \
  --proxy socks5://localhost:8888 |
  jq -r ".streamingData.serverAbrStreamingUrl" |
  awk -F'/' '{print $3}'
```

> [!NOTE]
> Обратите внимание, что запрос мы делаем через локальный прокси контейнера

После завершения поиска стратегий запустите zapret2 командой:

```bash
docker compose exec gost-zapret2 sh /opt/zapret2/init.d/sysv/zapret2 start
```

Либо перезапустите контейнер:

```bash
docker compose restart
```

#### blockcheckw

В контейнер интегрирован [blockcheckw](https://github.com/rcd27/blockcheckw). Это форк `blockcheck2` от [rcd27](https://github.com/rcd27), написанный на Rust.

Для его работы в конфиге необходимо переключить `FWTYPE` на `nftables`:

```bash
FWTYPE=nftables
```

Пример запуска:

```bash
docker compose exec gost-zapret2 sh -c "blockcheckw -w 32 scan -d rutracker.org | blockcheckw check -d rutracker.org --take 10"
```

Более подробная документация описана в оригинальном репозитории.

### Custom.d скрипты

После первого запуска контейнера в директории проекта будет создана директория `scripts`:

```
scripts
├── custom.d
└── examples
    ├── 10-keenetic-udp-fix
    ├── 20-fw-extra
    ├── 40-webserver
    ├── 50-dht4all
    ├── 50-discord-media
    ├── 50-nfqws-ipset
    ├── 50-quic4all
    ├── 50-stun4all
    └── 50-wg4all
```

Для того, чтобы использовать эти скрипты, необходимо скопировать их из директории `examples` в директорию `custom.d`. Например, скопируем скрипты для Discord и Stun (Telegram, WhatsApp):

```bash
cp scripts/examples/{50-discord-media,50-stun4all} scripts/custom.d
```

После чего необходимо перезапустить контейнер, чтобы скрипты применились:

```bash
docker compose restart
```

### Lua

После первого запуска контейнера в директории проекта будет создана директория `lua`:

```
lua/
├── zapret-antidpi.lua
├── zapret-auto.lua
├── zapret-lib.lua
├── zapret-pcap.lua
├── zapret-tests.lua
└── zapret-wgobfs.lua
```

Помимо стандартных скриптов, вы можете добавлять собственные lua-файлы для расширения функциональности.

### Fake-файлы

После первого запуска контейнера в директории проекта будет создана директория `fakes` со встроенными в zapret2 фейк-файлами:

```
fakes
├── tls_clienthello_rutracker_org_kyber.bin
├── tls_clienthello_sberbank_ru.bin
├── tls_clienthello_vk_com.bin
├── tls_clienthello_vk_com_kyber.bin
├── tls_clienthello_www_google_com.bin
...
```

Вы можете добавлять в эту директорию собственные fake-файлы и использовать их в стратегиях.

### Проверка работы стратегий

Проверить работу стратегий можно используя скрипт [censorcheck](https://github.com/vernette/censorcheck), указав локальный прокси контейнера:

```bash
bash <(wget -qO- https://github.com/vernette/censorcheck/raw/master/censorcheck.sh) --mode dpi --proxy localhost:8888
```

Проверить работу видео-доменов YouTube можно следующей командой:

```bash
curl --connect-to ::speedtest.selectel.ru https://manifest.googlevideo.com/100MB -k -o/dev/null -x socks5://localhost:8888
```

В поле `Current speed` должна расти скорость скачивания. Если она вообще не идёт или постоянно прыгает (во втором случае всё равно нужно проверить работу видео вручную) - стратегия не подходит.

### Интеграция с прокси-клиентами

Настройте прокси-клиент на протокол и порт, выбранный через `GOST_COMMAND`. При запуске клиента на хосте контейнера используйте адрес `127.0.0.1`.

## Работа Instagram в браузере

Чаще всего IP Instagram будет заблокирован и будет работать только в мобильном приложении.

Чтобы решить эту проблему, нам нужно найти незаблокированный IP и прописать его в `docker-compose.yml` на сервере:

```yaml
gost-zapret2:
  ...
  extra_hosts:
    instagram.com: "незаблокированный_ip"
    www.instagram.com: "незаблокированный_ip"
```

> Например instagram.com: "11.22.33.44"

После чего перезапустить compose, чтобы он прописал изменения в файл `/etc/hosts` контейнера:

```bash
docker compose down && docker compose up -d
```

## Сценарии использования

- **Локальное использование**: Запуск контейнера на домашнем сервере для изолированной работы zapret2 без модификации основной сети
- **Серверное использование**: Развертывание на удалённом VPS как единая точка подключения

## Разработка

Сборка образа с другой версией zapret2:

```bash
docker build -t gost-zapret2:v0.8 --build-arg ZAPRET_TAG=v0.8 .
```

Затем отредактируйте `docker-compose.yml`:

```yaml
gost-zapret2:
  image: gost-zapret2:v0.8
```

## Вклад в разработку

Если у вас есть идеи для улучшения проекта, вы нашли баг или хотите предложить новую функциональность - не стесняйтесь создавать [issue](https://github.com/MindofGhost/gost-zapret2/issues) или отправлять [pull request](https://github.com/MindofGhost/gost-zapret2/pulls).

## Предупреждение про доступ к прокси

> [!IMPORTANT]
> В текущем Compose прокси доступен только через `127.0.0.1:8888`. Перед публикацией порта на внешних интерфейсах настройте авторизацию в gost и ограничьте доступ к прокси.

## Благодарности

- [bol-van](https://github.com/bol-van) - За zapret2
- [ampetelin](https://github.com/ampetelin) - За [изначальный](https://github.com/ampetelin/ss-zapret) проект
- [rcd27](https://github.com/rcd27) - За blockcheckw

- [ginuerzh/gost](https://github.com/ginuerzh/gost) - За прокси, используемый в образе
