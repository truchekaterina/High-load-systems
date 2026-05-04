# LAB10 — подробное руководство: кеш в Additional, `@Scheduled`, нагрузка CPU 0.5 / 1.0

Документ описывает лабораторную на основе репозиториев [Labs_hls](https://github.com/truchekaterina/Labs_hls) (папка `zil`) и [zil-additional-service](https://github.com/truchekaterina/zil-additional-service), а также инфраструктуру курса (SSH, сеть `10.60.3.0/24`, БД `hl7`). Пароли не дублируются — берите из выданной таблицы (тот же логин/пароль, что для `hl@hlssh.zil.digital`).

**Стенд:** сервисы поднимаются через **`docker compose`** на ВМ (как в LAB8–LAB9). **Kubernetes / k3s в этом руководстве не рассматриваются** — при появлении такого стенда лимиты CPU и логику деплоя нужно переносить на него отдельно по методичке.

---

## 1. Что требует LAB10 в терминах кода

**Смысл задания:** в **additional** реже дергать основной CRUD за одними и теми же данными (в примере из ТЗ — **пользователи / клиенты**), хранить их в **`HashMap`**, периодически писать в **лог размер кеша** через **`@Scheduled`** (по аналогии с [StatisticsService в hl-module1](https://bitbucket.org/zil-courses/hl-module1/src/de80a88c55c19b5a35bd69d6ae3aa308355d6b02/src/main/java/ru/hpclab/hl/module1/service/StatisticsService.java)), затем **два нагрузочных прогона** с лимитом CPU **0.5** и **1.0**, сохранить **JSON k6** и **логи** (в логах — строки про размер кеша; при наличии LAB9 — ещё сводки `Observability`).

**Важно по типичному `AdditionalRentalService` в `zil-additional-service`:**

- Метод `getStats()` обычно каждый раз вызывает `mainCrudClient.getCars()`, `getClients()`, `getRents()` — прямое место, где **кеш клиентов** даёт экономию HTTP к основному сервису.
- Эндпоинт `/additional/cars/availability` при городе и дате использует **машины и аренды**; `getClients()` там может не участвовать. Если в «варианте 1» требуют «не перезапрашивать пользователя для каждого заказа», логично либо **обогатить** ответ по арендам данными клиента из кеша (если добавляете такую логику), либо в отчёте явно описать, что кеш **централизует** `ClientDto` после первого полного запроса списка клиентов и дальше используется везде, где нужны пользователи (в том числе при разборе заказов).

Нагрузочный сценарий k6: `zil/k6/load-lab8-s2s.js` — запросы к **`/additional/cars/availability`** и иногда **`/additional/stats`**. Кеш клиентов сильнее проявится на **`/additional/stats`** и на любой новой логике «аренда → клиент».

---

## 2. Карта ВМ из инфраструктурной таблицы (пример, без k3s)

В таблице курса могут быть и другие узлы (Kafka, кластер k3s и т.д.) — **для LAB10 по этому тексту достаточно** тех же ролей, что и для нагрузочных лаб на Docker: приложение, БД, registry, k6.

| Роль | IP (пример) | SSH-порт (пример) |
|------|-------------|-------------------|
| **k6** | `10.60.3.8` | `2311` |
| **PostgreSQL** | `10.60.3.9` | `2312` |
| **Harbor (registry)** | `10.60.3.11` | `2313` |

Отдельная строка в таблице студента — SSH на **вашу** ВМ приложений (например порт **2307**): с неё или с соседней машины выполняются **`docker compose`**, `pull` образов и при необходимости работа с Harbor.

Имя БД **hl7** согласуется с `DBNAME=hl7` в `registry-tags-lab8-hl7.env`. Поле **`DBHOST`** в env должно указывать на реальный хост PostgreSQL для вашего стенда (DNS курса или IP `10.60.3.9` и т.п.).

**Порты контейнеров `docker compose`:**

- основное приложение (**app**) — **8083**;
- **additional** — **8084**;
- лимиты CPU задаются переменными окружения на хосте **`APP_CPUS`** и **`ADDITIONAL_CPUS`** **перед** `docker compose up` (см. `docker-compose.yml`), а не только закомментированными строками в `.env`.

---

## 3. Реализация кеша в `zil-additional-service`

### 3.1. Включить планировщик

В главном классе приложения (например `ZilAdditionalServiceApplication`) добавьте:

```java
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
```

Без **`@EnableScheduling`** методы с **`@Scheduled` не выполнятся**.

### 3.2. Новый класс кеша

- **`@Service`**, например `ClientCacheService` или `UserStatisticsCache`.
- Внутри — **`ConcurrentHashMap<UUID, ClientDto>`** (или иной ключ, если модель другая). Под нагрузкой k6 обычный `HashMap` небезопасен; **`ConcurrentHashMap`** сохраняет идею «map» из ТЗ.
- Методы: заполнение из `List<ClientDto>`, `get(id)`, `size()`, при необходимости `clear()`.

### 3.3. Встраивание

Минимальный вариант:

- В **`AdditionalRentalService.getStats()`**: для клиентов — при пустом кеше один раз `getClients()` и наполнение карты; дальше использовать кеш (и обновлять политику согласованно с заданием: TTL, сброс по таймеру и т.д.).
- Если в коде есть цикл «по каждой аренде нужен клиент» — **`computeIfAbsent`** при доступности данных по id.

### 3.4. Периодический лог размера (`@Scheduled`)

В `application.properties`:

```properties
cache.statistics.log-interval-ms=10000
```

В сервисе кеша:

```java
@Scheduled(fixedRateString = "${cache.statistics.log-interval-ms:10000}")
public void logCacheSize() {
    log.info("Client cache size={}", size());
}
```

Для сравнения, в учебном [StatisticsService](https://bitbucket.org/zil-courses/hl-module1/src/de80a88c55c19b5a35bd69d6ae3aa308355d6b02/src/main/java/ru/hpclab/hl/module1/service/StatisticsService.java) используется `@Scheduled(fixedRateString = "${fixedRate.in.milliseconds}")`. Копировать `@Async` не обязательно.

Формат лога сделайте **узнаваемым** для `grep` в сохранённом файле.

---

## 4. Сборка образа и обновление `registry-tags-lab8-hl7.env`

### 4.1. Сборка и push

1. В корне **`zil-additional-service`**: собрать образ с тегом **`lab10`**.
2. `docker login` в ваш registry (**Harbor** или **Docker Hub** — как в методичке).
3. `docker push` в **ваш** репозиторий (путь должен совпасть со строкой `ZIL_ADDITIONAL_IMAGE` ниже).

### 4.2. Что менять в `registry-tags-lab8-hl7.env`

Для **LAB10** в этом файле **достаточно одной строки** — про образ **additional**. Остальное (**`DBHOST`**, **`ZIL_APP_IMAGE`**, пароли JDBC и т.д.) **не меняйте**, если методичка явно не просит.

**Лимиты CPU** (`APP_CPUS`, `ADDITIONAL_CPUS`) в `.env` обычно **не редактируют**: их задают в shell перед `docker compose up`, как в разделах **5** и **8** ниже.

Типичные варианты для **одной** строки `ZIL_ADDITIONAL_IMAGE` (без лишних пробелов и кавычек):

- **Harbor** (как в шаблоне репозитория `zil`):

```env
ZIL_ADDITIONAL_IMAGE=hl13.zil:8888/katya/zil-additional-service:lab10
```

- **Docker Hub** — короткая или полная форма (для Docker обычно эквивалентны):

```env
ZIL_ADDITIONAL_IMAGE=rinakt/zil-additional:lab10
```

```env
ZIL_ADDITIONAL_IMAGE=docker.io/rinakt/zil-additional:lab10
```

Главное — **одна** актуальная строка `ZIL_ADDITIONAL_IMAGE` и реальный путь к образу, который вы запушили.

### 4.3. Что ещё прописать в этом файле под LAB10?

По сути — **только тег additional** на `lab10` (или другой тег, если его дал преподаватель). Остальные переменные оставьте как для рабочего стенда LAB8/LAB9.

Основной образ **app** меняют только если в ТЗ нужна новая сборка `zil`; для чистого задания про кеш в **additional** часто достаточно обновить **только** `ZIL_ADDITIONAL_IMAGE`.

### 4.4. Перезапуск additional на ВМ

После правки env:

```bash
cd ~/Labs_hls/zil
docker compose --env-file registry-tags-lab8-hl7.env pull additional
docker compose --env-file registry-tags-lab8-hl7.env up -d --force-recreate additional
```

Если у вас по инструкции пересоздают оба сервиса:

```bash
docker compose --env-file registry-tags-lab8-hl7.env pull app additional
docker compose --env-file registry-tags-lab8-hl7.env up -d --force-recreate app additional
```

**Что ещё так прописать?** Если сомневаетесь — для десятой лабы почти всегда хватает **одной** строки `ZIL_ADDITIONAL_IMAGE` с тегом **`lab10`** и команд `pull` / `up` выше.

---

## 5. Поднять стенд с CPU **0.5**

На машине с контейнерами **app** + **additional**:

```bash
cd ~/Labs_hls/zil
export APP_CPUS=0.5
export ADDITIONAL_CPUS=0.5
docker compose --env-file registry-tags-lab8-hl7.env pull app additional
docker compose --env-file registry-tags-lab8-hl7.env up -d --force-recreate app additional
docker compose --env-file registry-tags-lab8-hl7.env ps
```

Проверки (подождите **10–30 с** после `up`, иначе возможны **connection reset** или **500** до прогрева JVM):

```bash
curl -sS -o /dev/null -w "app %{http_code}\n" http://127.0.0.1:8083/stats
curl -sS -o /dev/null -w "additional %{http_code}\n" http://127.0.0.1:8084/additional/stats
```

Ожидается **`200`** на обе строки. При ошибке повторите `curl` через минуту и при необходимости смотрите `docker compose --env-file registry-tags-lab8-hl7.env logs app additional --tail 50`.

Если **additional** на **другой ВМ**, задайте `MAIN_SERVICE_BASE_URL=http://<внутренний_IP_узла_с_app>:8083`, а `curl` к **8084** выполняйте на той ВМ, где слушает additional (см. [LAB9_MANUAL_FULL_RU.md](LAB9_MANUAL_FULL_RU.md), часть 3А).

---

## 6. Нагрузка k6: переменная `BASE_URL`

Сценарий `load-lab8-s2s.js` читает **`BASE_URL`** — это **полный URL до additional** (порт **8084**), **без** завершающего слэша.

### 6.1. Какой адрес подставлять

1. **k6 запускаете на той же ВМ, где уже крутится `docker compose` (app + additional)** — как на **hl07** в одном сеансе:

```bash
export BASE_URL="http://127.0.0.1:8084"
```

2. **k6 на отдельной ВМ** (например узел нагрузки `10.60.3.8`, SSH `2311`) — нужен **внутренний IP ВМ, где слушает порт 8084** (часто сеть курса `10.60.3.0/24`). На ВМ с compose выполните:

```bash
hostname -I
# или: ip -4 -br addr show scope global
```

Возьмите адрес вида **`10.60.3.x`**, доступный с k6-ВМ по `curl` (не `127.0.0.1` — это только «сама машина»). Пример (подставьте **свой** IP вместо `10.60.3.7`):

```bash
export BASE_URL="http://10.60.3.7:8084"
```

3. Проверка **с той же машины, где будет `k6 run`**:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" "${BASE_URL}/additional/stats"
```

Должно быть **`200`**.

### 6.2. Полный пример на ВМ k6 (отдельный узел)

```bash
ssh -p 2311 hl@hlssh.zil.digital
cd ~/Labs_hls/zil/k6
git pull

export BASE_URL="http://10.60.3.7:8084"
export TARGET_VUS=20
export DURATION=3m
export STATS_SHARE=0

mkdir -p reports-lab10-s2s
k6 run --summary-export reports-lab10-s2s/s2s_cpu05_mix00.json load-lab8-s2s.js
```

Замените **`10.60.3.7`** на IP вашей ВМ с контейнером **additional** (см. п. 6.1).

### 6.3. Если k6 с того же хоста, что и compose

```bash
cd ~/Labs_hls/zil/k6
export BASE_URL="http://127.0.0.1:8084"
export TARGET_VUS=20
export DURATION=3m
export STATS_SHARE=0

mkdir -p reports-lab10-s2s
k6 run --summary-export reports-lab10-s2s/s2s_cpu05_mix00.json load-lab8-s2s.js
```

Для смеси `/additional/stats` и availability, как в LAB8: `export STATS_SHARE=0.5` и имя файла, например `s2s_cpu05_mix50.json`.

---

## 7. Сохранить логи

Сразу после прогона на ВМ с compose:

```bash
cd ~/Labs_hls/zil
mkdir -p reports-lab10-logs
docker compose --env-file registry-tags-lab8-hl7.env logs --no-color app additional \
  > reports-lab10-logs/run_lab10_cpu05_app_additional.log
```

Ищите в файле строки вида **`Client cache size=…`**. Если **app** и **additional** на разных ВМ — сохраните два лога отдельно (см. часть 9 в [LAB9_MANUAL_FULL_RU.md](LAB9_MANUAL_FULL_RU.md)).

---

## 8. Второй прогон: CPU **1.0**

На ВМ с Docker:

```bash
export APP_CPUS=1.0
export ADDITIONAL_CPUS=1.0
docker compose --env-file registry-tags-lab8-hl7.env up -d --force-recreate app additional
sleep 30
```

На ВМ k6:

```bash
k6 run --summary-export reports-lab10-s2s/s2s_cpu10_mix00.json load-lab8-s2s.js
```

Снова сохранить логи, например `run_lab10_cpu10_app_additional.log`.

---

## 9. Графики

Из каталога `zil/k6`:

```bash
pip install matplotlib
python3 plot_lab8_reports.py reports-lab10-s2s
```

Скрипт ожидает имена файлов по шаблонам вроде `*cpu05_mix*.json` / `*cpu10_mix*.json` (см. [plot_lab8_reports.py](../k6/plot_lab8_reports.py)). При необходимости переименуйте JSON.

В отчёт приложите:

- PNG из скрипта;
- фрагменты логов с размером кеша за нагрузку для **0.5** и **1.0**;
- два summary JSON k6.

---

## 10. Типичные ошибки

| Симптом | Что сделать |
|---------|-------------|
| Нет строк `@Scheduled` в логах | Добавить `@EnableScheduling`; проверить старт бина |
| k6: connection refused | Исправить `BASE_URL` — хост с **8084**, доступный с k6 |
| CPU не меняется | Перед `up` выполнить `export APP_CPUS=…` / `ADDITIONAL_CPUS=…` в том же shell |
| Старый код в контейнере | Обновить `ZIL_ADDITIONAL_IMAGE`, `pull`, `up --force-recreate` |

---

## 11. См. также

- [LAB9_MANUAL_FULL_RU.md](LAB9_MANUAL_FULL_RU.md) — Observability, k6, логи, разнесённые ВМ.
- [LAB8_PLAN_RU.md](LAB8_PLAN_RU.md) — Additional, образы, контракт API.
- [README_K6_LABS_RU.md](README_K6_LABS_RU.md) — сценарии k6 и графики.
