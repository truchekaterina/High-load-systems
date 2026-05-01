# LAB8 — микросервис Additional (кратко)

Цель: второй сервис на порту **8084** вызывает основной CRUD (**8083**) по HTTP (**RestTemplate**, WebClient, Feign — по выбору в отдельном репозитории), «join» агрегатов — **в Java**, не в БД.

## Где живёт код Additional

Отдельный репозиторий: **[truchekaterina/zil-additional-service](https://github.com/truchekaterina/zil-additional-service)** — образ собираете **там** (или CI), пушите тег в **Harbor/Docker Hub**.

В этом репозитории (**`first_laba` / `zil`**) второй микросервис **не дублируется**: в **`docker-compose.yml`** задаётся только **готовый образ** через переменную **`ZIL_ADDITIONAL_IMAGE`**.

Из папки **`zil`** после того, как нужный образ уже есть локально или в registry:

```bash
export ZIL_ADDITIONAL_IMAGE=registry.example/you/zil-additional:v1   # свой тег
docker compose pull additional   # если образ в регистри
docker compose up -d
```

Образ можно собрать вручную рядом с клоном: `docker build -t zil-additional:local ./zil-additional-service` и тогда оставить по умолчанию **`zil-additional:local`** без `pull`.

Основной CRUD (**`app`**): в **`registry-tags-lab8-hl7.env`** по умолчанию образ с **Docker Hub** (`docker.io/rinakt/zil-app:hl7-latest`); сборка только из локального **`Dockerfile`** нужна только если хотите свой образ без Hub.

## CPU (0.5 и 1.0)

Перед `docker compose up` на хосте (пример):

```bash
export APP_CPUS=0.5
export ADDITIONAL_CPUS=0.5
```

Для второго набора замените значения на **1.0**, перезапустите нужные контейнеры (**`--force-recreate`** при необходимости).

Переменные: **`APP_CPUS`**, **`ADDITIONAL_CPUS`** (+ при необходимости **`APP_MEM`**, **`ADDITIONAL_MEM`**).

## Настройка Additional → CRUD

В compose для сервиса **`additional`** задаётся URL CRUD (**`MAIN_SERVICE_BASE_URL=http://app:8083`**, имя сервиса **`app`** в общей Docker-сети). В **`zil-additional-service`** свойство **`main-service.base-url`** также читает **`RENTAL_CRUD_BASE_URL`**, если задали его вместо первого имени.

Локальная разработка Additional без compose — см. **`application.properties`** в репозитории **`zil-additional-service`**.

## Эндпоинты LAB8 для k6

Совпадают с контрактом в вашем доп. сервисе и сценарием **`load-lab8-s2s.js`**, см. там пути (**`/additional/...`**).

Подробнее по k6 и графикам — **[README_K6_LABS_RU.md](README_K6_LABS_RU.md)** (раздел LAB8).

## Образы в Docker Hub (фиксация для отчётности)

На момент сдачи строки образов задаются в **`[registry-tags-lab8-hl7.env](../registry-tags-lab8-hl7.env)`**: основной сервис с **Docker Hub** (`rinakt/zil-app:hl7-latest` по умолчанию), дополнительный — **Harbor** (`katya/zil-additional-service:lab8`). Уточните у методиста, если нужны другие теги.

