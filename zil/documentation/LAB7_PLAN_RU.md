# LAB7 — вынос PostgreSQL на отдельную ноду `hl12.zil`

Документ для подготовки и защиты LAB7 по проекту `zil`. Цель лабораторной: приложение Spring Boot остаётся на прикладной ВМ, а PostgreSQL переносится на отдельную DB-ноду `hl12.zil`. На DB-ноде поднимаются PostgreSQL и pgAdmin через Docker Compose, а приложение подключается к БД по сетевому имени/адресу этой ноды.

Важно: точные значения из таблицы курса всегда проверяйте в живой Google-таблице перед сдачей. По приложенному скриншоту для строки **Трюх Екатерины** актуальные данные выглядят так: SSH-порт прикладной ВМ `2307`, SSH-порт DB-ноды `2312`, имя базы `hl7`, email `ekaterinatryuh@yandex.ru`. Перед финальной отправкой всё равно сверяйте эти значения с живым листом курса. В старых документах проекта для LAB6 могло встречаться другое учебное имя БД; для LAB7 используйте именно значение из вашей актуальной строки.

---

## 0. Связь с LAB6: образ приложения и реестр

LAB7 логично делать **сразу после LAB6** на той же прикладной ВМ: те же Docker, те же приёмы деплоя. На LAB7 меняется главным образом **куда ходит JDBC** — на удалённую БД **`hl12.zil`**, а не в локальный контейнер `postgres`.

**Образ основного приложения (`app`):**

- Если вы уже публикуете образ в **Docker Hub** (без Harbor) — продолжайте так же: **`docker login`** на hub.docker.com с **PAT**, тег **`docker.io/<DOCKER_ID>/zil-app:<тег>`**, на ВМ **`export ZIL_APP_IMAGE=...`** и **`docker compose pull app`**. Пошагово это расписано в **[LAB6_PLAN_RU §15](LAB6_PLAN_RU.md#15-лаб-6-образы-только-из-docker-hub-без-harbor-пошагово-для-новичка)**.
- Если курс требует **Harbor** (`hlssh.zil.digital:2313`) — используйте **`docker login`** к Harbor и **`ZIL_APP_IMAGE`** с полным путём проекта в Harbor (как в LAB6/LAB8-доках).

Образ **`postgres:16-alpine`** для контейнера БД на **DB-ноде** по-прежнему подтягивается с публичного Docker Hub; отдельный **`docker login`** на Hub для него обычно не нужен, если не упёрлись в лимиты анонимного pull.

После смены кода под LAB7 не забудьте **пересобрать и запушить** образ `app` с новым тегом (например `:lab7`), затем на ВМ **`pull`** и **`up`**.

**Чтобы не путать k6-отчёты и настройки compose между лабами:** см. **[README_K6_LABS_RU.md](../k6/README_K6_LABS_RU.md)** в папке `zil/k6`.

---

## 1. Что уже есть в проекте

Перед LAB7 полезно понимать, от чего мы отталкиваемся.

### `zil/docker-compose.yml`

Текущий compose поднимает два сервиса на одной машине:

- `postgres` на образе `postgres:16-alpine`;
- `app`, который собирается из `zil/Dockerfile`;
- локальная БД называется `car_rental`;
- контейнерный пользователь БД: `rental`;
- пароль: `rental_pass`;
- порт PostgreSQL проброшен наружу как `5433:5432`;
- приложение внутри Docker подключается к БД так:

```yaml
SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/car_rental
SPRING_DATASOURCE_USERNAME: rental
SPRING_DATASOURCE_PASSWORD: rental_pass
```

Для LAB7 такая схема уже не подходит как финальная, потому что PostgreSQL должен быть не рядом с приложением в этом же compose, а на отдельной DB-ноде `hl12.zil`.

### `zil/src/main/resources/application.properties`

Сейчас в проекте URL подключения задан через `SPRING_DATASOURCE_URL` с локальным значением по умолчанию:

```properties
spring.datasource.url=${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5433/car_rental}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME:rental}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD:rental_pass}
```

Для LAB7 в методичке нужен более гибкий URL через отдельные переменные:

```properties
spring.datasource.url=jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5437}/${DBNAME:hl7}?currentSchema=${SCHEMANAME:hl7}
```

Смысл такой:

- `DBHOST` — где находится PostgreSQL, для LAB7 это DB-нода `hl12.zil` или её внутренний IP/DNS;
- `DBPORT` — внешний порт PostgreSQL на DB-ноде. В этой LAB7 используйте `5437`, потому что `5432` на `hl12` уже занят;
- `DBNAME` — имя базы из таблицы курса, для Трюх Екатерины по скриншоту это `hl7`, но проверьте в живой таблице;
- `SCHEMANAME` — схема внутри базы, обычно совпадает с именем базы/строки, для этой строки `hl7`;
- значения после `:` — defaults, если переменные окружения не заданы.

### Flyway migrations

В проекте есть две миграции:

- `src/main/resources/db/migration/V1__init_schema.sql` создаёт таблицы `cars`, `clients`, `rents`;
- `src/main/resources/db/migration/V2__seed_data.sql` добавляет стартовые данные для демо и тестов API.

Hibernate настроен как `spring.jpa.hibernate.ddl-auto=validate`, то есть таблицы создаёт не Hibernate, а Flyway. Поэтому при первом старте приложения на новой БД Flyway должен успешно применить `V1`, затем `V2`.

### Документация

В `zil/documentation` уже есть подробные планы LAB2-LAB6 (включая **[LAB6_PLAN_RU — Docker Hub vs Harbor](LAB6_PLAN_RU.md)**). LAB7 продолжает эту же линию: Docker, удалённые ВМ, переменные окружения, Flyway и проверка через Swagger/API; к LAB7 добавляется только вынос PostgreSQL на **`hl12.zil`** и JDBC через **`DBHOST`/`DBPORT`/`DBNAME`/`SCHEMANAME`**.

---

## 2. Итоговая архитектура LAB7

В финальном состоянии должно быть так:

```text
Ваш ПК
  |
  | ssh / браузер / curl
  v
Прикладная ВМ с приложением Spring Boot
  |
  | JDBC: jdbc:postgresql://hl12.zil:5437/<DBNAME>?currentSchema=<SCHEMANAME>
  v
DB-нода hl12.zil
  ├── PostgreSQL в Docker
  └── pgAdmin в Docker
```

Главная идея: приложение больше не хранит данные в локальном контейнере `postgres` рядом с собой. Оно ходит по сети на DB-ноду.

---

## 3. Данные, которые нужно взять из таблицы курса

Перед настройкой выпишите в черновик:

| Что | Где взять | Пример/заметка |
| --- | --- | --- |
| SSH-порт вашей прикладной ВМ | таблица курса | порт для входа на ВМ с приложением |
| SSH-порт DB-ноды | таблица курса | нода `hl12.zil` / порт через gateway |
| SSH-пользователь | таблица курса | часто `hl` |
| SSH-host/gateway | таблица курса | например общий gateway курса |
| Имя базы `DBNAME` | ваша строка таблицы | для Трюх Екатерины по скриншоту `hl7`, проверьте live sheet |
| Имя схемы `SCHEMANAME` | методичка/таблица | обычно такое же, как `DBNAME`, для этой строки `hl7` |
| Пароль PostgreSQL | задаёте сами или берёте из методички | не коммитьте реальные секреты |
| Email/пароль pgAdmin | задаёте сами | нужны только для входа в веб-интерфейс pgAdmin |

По приложенному скриншоту для вашей строки:

| Поле | Значение |
| --- | --- |
| ФИО | `Трюх Екатерина` |
| Git repo | `https://github.com/truchekaterina/Labs_hls` |
| SSH-порт прикладной ВМ | `2307` |
| SSH-порт DB-ноды | `2312` |
| DB name / `DBNAME` | `hl7` |
| `SCHEMANAME` | `hl7` |
| Email | `ekaterinatryuh@yandex.ru` |

В отчёте и на защите значения должны совпадать с тем, что реально запущено.

---

## 4. Подключение к DB-ноде `hl12.zil`

С Windows используйте PowerShell. Конкретный порт берите из таблицы курса.

```powershell
ssh -p 2312 hl@hlssh.zil.digital
```

После входа проверьте, что вы именно на DB-ноде:

```bash
hostname
ip addr
docker --version
docker compose version
```

Если Docker не установлен, установите его по инструкции курса или официальной инструкции Docker для вашей ОС на ВМ. После добавления пользователя в группу `docker` нужно выйти из SSH и зайти снова:

```bash
sudo usermod -aG docker $USER
exit
```

Потом проверьте:

```bash
docker ps
```

---

## 5. Docker Compose для PostgreSQL и pgAdmin на DB-ноде

На DB-ноде создайте отдельный каталог, например:

```bash
mkdir -p ~/lab7-db
cd ~/lab7-db
```

Создайте файл `docker-compose.yml`:

```bash
nano docker-compose.yml
```

Пример compose для LAB7:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: lab7-postgres
    command: postgres -c max_connections=1000
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-hl7}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-change_me_strong_password}
      POSTGRES_DB: ${POSTGRES_DB:-hl7}
    ports:
      - "5437:5432"
    volumes:
      - lab7_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-hl7} -d ${POSTGRES_DB:-hl7}"]
      interval: 5s
      timeout: 5s
      retries: 10
    restart: unless-stopped

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: lab7-pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL:-ekaterinatryuh@yandex.ru}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD:-change_me_pgadmin_password}
    ports:
      - "8081:80"
    volumes:
      - lab7_pgadmin:/var/lib/pgadmin
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped

volumes:
  lab7_pgdata:
  lab7_pgadmin:
```

Проброс `5437:5432` означает: с прикладной ВМ приложение подключается к `hl12.zil:5437`, а внутри контейнера PostgreSQL всё равно слушает стандартный порт `5432`. Это нужно потому, что на `hl12` внешний порт `5432` уже занят другим сервисом.

Обязательный пункт LAB7 здесь:

```yaml
command: postgres -c max_connections=1000
```

Он запускает PostgreSQL с увеличенным лимитом подключений. Это важно для лабораторных с нагрузкой: приложение, пул соединений, pgAdmin и тесты не должны быстро упереться в маленький дефолтный лимит.

### Лучше вынести секреты в `.env`

В том же каталоге `~/lab7-db` можно создать `.env`:

```bash
nano .env
```

Пример:

```dotenv
POSTGRES_USER=hl7
POSTGRES_PASSWORD=<ВАШ_ПАРОЛЬ_БД>
POSTGRES_DB=hl7
PGADMIN_DEFAULT_EMAIL=ekaterinatryuh@yandex.ru
PGADMIN_DEFAULT_PASSWORD=<ВАШ_ПАРОЛЬ_PGADMIN>
```

Замените `hl7` на актуальное имя из таблицы, если в живом листе указано другое значение. Файл `.env` на сервере не нужно публиковать в GitHub.

Важно: `POSTGRES_DB`, `POSTGRES_USER` и `POSTGRES_PASSWORD` используются образом PostgreSQL только при первом создании пустого volume. Если вы уже запускали контейнер и потом поменяли эти значения в `.env`, старая база/пользователь внутри `lab7_pgdata` автоматически не пересоздадутся. Для учебного стенда можно удалить volume командой `docker compose down -v`, но это полностью удалит данные БД, поэтому делайте так только если данные не нужны.

Запуск:

```bash
docker compose up -d
docker compose ps
docker compose logs postgres --tail 80
```

Ожидается:

- `lab7-postgres` в состоянии `healthy`;
- `lab7-pgadmin` в состоянии `running`;
- в логах PostgreSQL нет ошибок; внутри контейнера сервер слушает `5432`, а снаружи DB-ноды доступен порт `5437`.

---

## 6. Проверка PostgreSQL на DB-ноде

Проверьте подключение внутри контейнера:

```bash
docker exec -it lab7-postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

Если переменные из `.env` не подставились в shell, используйте реальные значения:

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7
```

Внутри `psql`:

```sql
SELECT current_database();
SELECT current_user;
SHOW max_connections;
\dn
\dt
\q
```

`SHOW max_connections;` должен показать `1000`.

Если схема ещё не создана, создайте её вручную. Обычно имя схемы совпадает с именем базы:

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7
```

```sql
CREATE SCHEMA IF NOT EXISTS hl7 AUTHORIZATION hl7;
\dn
\q
```

Важно: если `spring.datasource.url` содержит `currentSchema=hl7`, то Flyway и Hibernate будут работать в схеме `hl7`. Если схема не существует, приложение может упасть при старте.

---

## 7. Доступ к pgAdmin

pgAdmin запущен на DB-ноде в контейнере и слушает порт `8081` на этой ноде.

### Вариант A: через SSH-туннель с Windows

В отдельном PowerShell-окне на вашем ПК:

```powershell
ssh -p 2312 -L 8081:127.0.0.1:8081 hl@hlssh.zil.digital
```

Окно с туннелем оставьте открытым. В браузере:

```text
http://localhost:8081
```

Логин и пароль берутся из:

```dotenv
PGADMIN_DEFAULT_EMAIL=...
PGADMIN_DEFAULT_PASSWORD=...
```

### Вариант B: если порт pgAdmin открыт во внутренней сети

Если преподаватель разрешает доступ напрямую из учебной сети, pgAdmin можно открыть по адресу DB-ноды и порту `8081`. Но безопаснее и обычно правильнее для лабораторной использовать SSH-туннель.

### Добавление сервера PostgreSQL в pgAdmin

После входа в pgAdmin:

1. Нажмите `Add New Server`.
2. Вкладка `General`: имя, например `LAB7 PostgreSQL`.
3. Вкладка `Connection`:
   - `Host name/address`: `postgres`, если pgAdmin и PostgreSQL в одном compose;
   - `Port`: `5432`;
   - `Maintenance database`: `hl7` или ваше актуальное имя БД;
   - `Username`: `hl7` или ваш `POSTGRES_USER`;
   - `Password`: пароль из `POSTGRES_PASSWORD`.
4. Сохраните.

Почему host именно `postgres`: внутри одного Docker Compose сервисы видят друг друга по имени сервиса. Для pgAdmin контейнер `postgres` — это сетевое имя контейнера PostgreSQL.

В pgAdmin проверьте:

- база существует;
- схема `hl7`/ваша схема существует;
- после старта приложения появились таблицы `cars`, `clients`, `rents` и таблица `flyway_schema_history`.

---

## 8. Настройка приложения Spring Boot для удалённой БД

Для LAB7 приложение должно подключаться к DB-ноде через переменные окружения.

### Рекомендуемая строка в `application.properties`

Для вашей строки используйте такой формат:

```properties
spring.datasource.url=jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5437}/${DBNAME:hl7}?currentSchema=${SCHEMANAME:hl7}
```

Для конкретной сдачи defaults уже можно поставить под вашу строку, а на сервере всё равно лучше задавать реальные значения через environment. Например:

```properties
spring.datasource.url=jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5437}/${DBNAME:hl7}?currentSchema=${SCHEMANAME:hl7}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME:hl7}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD:change_me}
```

Если преподаватель строго проверяет дословную строку из методички, можно оставить её шаблонный default, а реальные `DBNAME` и `SCHEMANAME` задать переменными окружения. Но для вашей сдачи по таблице фактические значения должны быть `hl7`.

### Environment для сервиса `app`

В compose на прикладной ВМ для сервиса `app` нужно задать:

```yaml
environment:
  DBHOST: hl12.zil
  DBPORT: "5437"
  DBNAME: hl7
  SCHEMANAME: hl7
  SPRING_DATASOURCE_USERNAME: hl7
  SPRING_DATASOURCE_PASSWORD: <ВАШ_ПАРОЛЬ_БД>
  SPRING_JPA_SHOW_SQL: "false"
```

Если `hl12.zil` не резолвится с прикладной ВМ, используйте внутренний IP DB-ноды из таблицы/методички:

```yaml
DBHOST: 10.60.x.y
```

Проверка DNS/сети с прикладной ВМ:

```bash
getent hosts hl12.zil
nc -vz hl12.zil 5437
```

Если `nc` не установлен:

```bash
sudo apt install -y netcat-openbsd
```

---

## 9. Что менять в `zil/docker-compose.yml` на прикладной ВМ

Есть два подхода.

### Подход 1. Для LAB7 убрать локальный `postgres` из запуска приложения

Финальный compose на прикладной ВМ может оставить только `app`, потому что БД уже работает на `hl12.zil`.

Пример идеи:

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: zil-app
    environment:
      DBHOST: hl12.zil
      DBPORT: "5437"
      DBNAME: hl7
      SCHEMANAME: hl7
      SPRING_DATASOURCE_USERNAME: hl7
      SPRING_DATASOURCE_PASSWORD: <ВАШ_ПАРОЛЬ_БД>
      SPRING_JPA_SHOW_SQL: "false"
      SERVER_TOMCAT_THREADS_MAX: "50"
    ports:
      - "8083:8083"
    cpus: "${APP_CPUS:-1.0}"
    mem_limit: "${APP_MEM:-768m}"
```

В этом варианте `depends_on: postgres` нужно убрать, потому что сервиса `postgres` в этом compose больше нет.

Если **`app`** не собираете **`build:`** на ВМ, а тянете готовый образ (**как после LAB6**), задайте образ и переменные так же, как в актуальном [`docker-compose.yml`](../docker-compose.yml): **`image: ${ZIL_APP_IMAGE:-...}`** и те же **`environment`** с **`DBHOST`/`DBPORT`/…**. Пример:

```yaml
services:
  app:
    image: ${ZIL_APP_IMAGE:-docker.io/truchekaterina/zil-app:lab7}
    container_name: zil-app
    environment:
      DBHOST: hl12.zil
      DBPORT: "5437"
      DBNAME: hl7
      SCHEMANAME: hl7
      SPRING_DATASOURCE_USERNAME: hl7
      SPRING_DATASOURCE_PASSWORD: <ВАШ_ПАРОЛЬ_БД>
      SPRING_JPA_SHOW_SQL: "false"
      SERVER_TOMCAT_THREADS_MAX: "50"
    ports:
      - "8083:8083"
    cpus: "${APP_CPUS:-1.0}"
    mem_limit: "${APP_MEM:-768m}"
```

На ВМ перед **`docker compose pull app && docker compose up -d`**:

```bash
export ZIL_APP_IMAGE=docker.io/<ВАШ_DOCKER_ID>/zil-app:lab7
```

(Подставьте свой Docker ID и тег; при **приватном** репозитории на Hub сначала **`docker login`** на этой же ВМ.)

### Подход 2. Оставить локальный `postgres` для разработки, но не запускать его в LAB7

Можно оставить текущий `postgres` в файле как dev-вариант, но для LAB7 запускать только `app` с переменными на удалённую БД:

```bash
docker compose up --build -d app
```

Минус: если в `app` остаётся `depends_on: postgres`, compose всё равно будет пытаться поднять локальную БД. Поэтому для чистого LAB7 лучше убрать зависимость `app -> postgres` или сделать отдельный override-файл для LAB7.

Пример отдельного `docker-compose.lab7.yml`:

```yaml
services:
  app:
    depends_on: !reset []
    environment:
      DBHOST: hl12.zil
      DBPORT: "5437"
      DBNAME: hl7
      SCHEMANAME: hl7
      SPRING_DATASOURCE_USERNAME: hl7
      SPRING_DATASOURCE_PASSWORD: <ВАШ_ПАРОЛЬ_БД>
```

Но `!reset` поддерживается не во всех версиях Docker Compose, поэтому проще для защиты иметь понятный compose без локального `postgres`.

---

## 10. Flyway на новой БД

При первом старте приложения на новой пустой БД произойдёт:

1. Spring Boot создаёт подключение к PostgreSQL.
2. Flyway проверяет таблицу истории `flyway_schema_history`.
3. Если истории нет, Flyway применяет:
   - `V1__init_schema.sql`;
   - `V2__seed_data.sql`.
4. Hibernate проверяет соответствие Entity и таблиц, потому что стоит `ddl-auto=validate`.
5. Приложение стартует на `8083`.

Проверка в логах приложения:

```bash
docker compose logs app --tail 120
```

Ищите строки примерно такого смысла:

```text
Flyway Community Edition
Migrating schema "hl7" to version "1 - init schema"
Migrating schema "hl7" to version "2 - seed data"
Successfully applied 2 migrations
```

Проверка в PostgreSQL:

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7
```

```sql
SET search_path TO hl7;
\dt
SELECT * FROM flyway_schema_history;
SELECT COUNT(*) FROM cars;
SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM rents;
\q
```

Ожидаемо после `V2`:

- `cars` содержит 4 строки;
- `clients` содержит 4 строки;
- `rents` содержит 4 строки.

---

## 11. Полный порядок выполнения LAB7

### Шаг 1. Подготовить DB-ноду

На DB-ноде:

```bash
mkdir -p ~/lab7-db
cd ~/lab7-db
nano docker-compose.yml
nano .env
docker compose up -d
docker compose ps
```

Проверить:

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "SHOW max_connections;"
```

Должно быть:

```text
1000
```

### Шаг 2. Создать схему

Если схема нужна явно:

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "CREATE SCHEMA IF NOT EXISTS hl7 AUTHORIZATION hl7;"
```

### Шаг 3. Проверить pgAdmin

С ПК:

```powershell
ssh -p 2312 -L 8081:127.0.0.1:8081 hl@hlssh.zil.digital
```

В браузере:

```text
http://localhost:8081
```

Добавить сервер `postgres:5432` внутри pgAdmin.

### Шаг 4. Настроить приложение

В `application.properties` должна быть строка формата:

```properties
spring.datasource.url=jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5437}/${DBNAME:hl7}?currentSchema=${SCHEMANAME:hl7}
```

На прикладной ВМ в compose/environment задать:

```yaml
DBHOST: hl12.zil
DBPORT: "5437"
DBNAME: hl7
SCHEMANAME: hl7
SPRING_DATASOURCE_USERNAME: hl7
SPRING_DATASOURCE_PASSWORD: <ВАШ_ПАРОЛЬ_БД>
```

Перед сдачей замените `hl7`, если в живой таблице курса для вашей строки указано другое имя.

### Шаг 5. Проверить сеть с прикладной ВМ

На прикладной ВМ:

```bash
getent hosts hl12.zil
nc -vz hl12.zil 5437
```

Если проверка успешна, будет что-то вроде:

```text
Connection to hl12.zil 5437 port [tcp/postgresql] succeeded!
```

### Шаг 6. Запустить приложение

На прикладной ВМ в каталоге `zil`:

```bash
docker compose up --build -d
docker compose ps
docker compose logs app --tail 120
```

В логах должны быть:

- успешное подключение к PostgreSQL;
- успешные миграции Flyway или сообщение, что миграции уже применены;
- старт приложения на порту `8083`.

### Шаг 7. Проверить API

Если приложение доступно через SSH-туннель:

```powershell
ssh -p 2307 -L 8080:127.0.0.1:8083 hl@hlssh.zil.digital
```

В браузере:

```text
http://localhost:8080/swagger-ui/index.html
http://localhost:8080/cars
http://localhost:8080/clients
http://localhost:8080/rents
```

Или на самой прикладной ВМ:

```bash
curl http://localhost:8083/cars
curl http://localhost:8083/clients
curl http://localhost:8083/rents
```

---

## 12. Команды для быстрой защиты

На DB-ноде:

```bash
cd ~/lab7-db
docker compose ps
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "SHOW max_connections;"
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "\dn"
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "\dt hl7.*"
```

На прикладной ВМ:

```bash
cd ~/work/Labs_hls/zil
docker compose ps
docker compose logs app --tail 80
docker exec -it zil-app env | grep -E 'DBHOST|DBPORT|DBNAME|SCHEMANAME|SPRING_DATASOURCE'
curl http://localhost:8083/cars
```

С Windows:

```powershell
ssh -p 2307 -L 8080:127.0.0.1:8083 hl@hlssh.zil.digital
```

Браузер:

```text
http://localhost:8080/swagger-ui/index.html
```

Что сказать преподавателю:

- PostgreSQL вынесен на отдельную ноду `hl12.zil`;
- PostgreSQL и pgAdmin запущены через Docker Compose на DB-ноде;
- PostgreSQL стартует с `max_connections=1000`;
- приложение подключается к удалённой БД через `DBHOST`, `DBPORT`, `DBNAME`, `SCHEMANAME`;
- схема создаётся заранее, таблицы и тестовые данные накатывает Flyway;
- pgAdmin доступен через SSH-туннель и показывает базу/схему/таблицы.

---

## 13. Частые ошибки и диагностика

### Приложение пишет `Connection refused`

Причины:

- PostgreSQL не запущен;
- приложение смотрит не на тот `DBHOST`;
- внешний порт `5437` закрыт firewall;
- compose на DB-ноде пробросил другой порт.

Проверки:

```bash
docker compose ps
nc -vz hl12.zil 5437
docker compose logs postgres --tail 80
```

### Ошибка `database "hl7" does not exist`

Значит `DBNAME` в приложении не совпадает с `POSTGRES_DB` на DB-ноде.

Проверьте на DB-ноде:

```bash
docker exec -it lab7-postgres psql -U hl7 -d postgres -c "\l"
```

Исправьте либо `POSTGRES_DB`, либо переменную `DBNAME`.

### Ошибка `schema "hl7" does not exist`

Создайте схему:

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "CREATE SCHEMA IF NOT EXISTS hl7 AUTHORIZATION hl7;"
```

И перезапустите приложение:

```bash
docker compose restart app
```

### Flyway применил миграции не в ту схему

Проверьте URL:

```bash
docker exec -it zil-app env | grep -E 'DBHOST|DBPORT|DBNAME|SCHEMANAME'
```

В PostgreSQL:

```sql
\dn
\dt *.*
SELECT * FROM hl7.flyway_schema_history;
```

Если миграции ушли в `public`, значит `currentSchema` не был задан или был задан неверно.

### `FATAL: sorry, too many clients already`

Проверьте, что PostgreSQL реально стартовал с нужной командой:

```bash
docker inspect lab7-postgres --format '{{json .Config.Cmd}}'
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "SHOW max_connections;"
```

Должно быть `1000`. Если нет, проверьте строку:

```yaml
command: postgres -c max_connections=1000
```

### pgAdmin не открывается

Проверьте контейнер и порт:

```bash
docker compose ps
docker compose logs pgadmin --tail 80
```

Проверьте SSH-туннель:

```powershell
ssh -p 2312 -L 8081:127.0.0.1:8081 hl@hlssh.zil.digital
```

Если локальный порт `8081` занят на Windows, используйте другой локальный порт:

```powershell
ssh -p 2312 -L 18081:127.0.0.1:8081 hl@hlssh.zil.digital
```

И откройте:

```text
http://localhost:18081
```

### Приложение всё ещё подключается к локальному `car_rental`

Проверьте, что переменные окружения реально попали в контейнер:

```bash
docker exec -it zil-app env | grep -E 'DBHOST|DBPORT|DBNAME|SCHEMANAME|SPRING_DATASOURCE'
```

Если в `application.properties` осталась старая строка:

```properties
spring.datasource.url=${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5433/car_rental}
```

то переменные `DBHOST`, `DBPORT`, `DBNAME`, `SCHEMANAME` не будут использоваться. Для LAB7 нужна строка:

```properties
spring.datasource.url=jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5437}/${DBNAME:hl7}?currentSchema=${SCHEMANAME:hl7}
```

---

## 14. Чеклист перед сдачей

- DB-нода `hl12.zil` доступна по SSH.
- На DB-ноде есть compose с сервисами `postgres` и `pgadmin`.
- PostgreSQL запущен с `command: postgres -c max_connections=1000`.
- `SHOW max_connections;` возвращает `1000`.
- Имя базы `DBNAME` взято из актуальной таблицы курса. По скриншоту для строки Трюх Екатерины указано `hl7`, но перед сдачей это нужно перепроверить.
- Схема `SCHEMANAME` создана и совпадает с `currentSchema` в JDBC URL.
- В приложении используется URL формата `jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5437}/${DBNAME:hl7}?currentSchema=${SCHEMANAME:hl7}`.
- На прикладной ВМ заданы `DBHOST`, `DBPORT`, `DBNAME`, `SCHEMANAME`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD`.
- Локальный `postgres` из старого `zil/docker-compose.yml` не используется как основная БД для LAB7.
- Flyway создал таблицы `cars`, `clients`, `rents` и `flyway_schema_history`.
- Swagger/API открываются и возвращают данные из удалённой БД.
- pgAdmin открывается через туннель и показывает нужную БД/схему.
- В репозиторий не попали реальные пароли, `.env`, приватные ключи и другие секреты.
- Образ **`app`**: либо **`docker compose build`**, либо **`ZIL_APP_IMAGE`** из **Docker Hub** или **Harbor** — согласовано с LAB6; перед **`pull`** выполнен **`docker login`** к нужному реестру (если образ приватный или нужен обход лимитов Hub).

---

## 15. Мини-шпаргалка по переменным

| Переменная | Где задаётся | Для чего |
| --- | --- | --- |
| `ZIL_APP_IMAGE` | `.env` на ВМ или `export` | Полный путь к образу основного сервиса в Harbor или Docker Hub (как в LAB6). |
| `DBHOST` | compose приложения | адрес DB-ноды, например `hl12.zil` |
| `DBPORT` | compose приложения | внешний порт PostgreSQL на DB-ноде, для этой LAB7 `5437` |
| `DBNAME` | compose приложения и `POSTGRES_DB` на DB-ноде | имя базы из таблицы курса |
| `SCHEMANAME` | compose приложения | схема, куда Flyway создаёт таблицы |
| `SPRING_DATASOURCE_USERNAME` | compose приложения | пользователь PostgreSQL |
| `SPRING_DATASOURCE_PASSWORD` | compose приложения | пароль PostgreSQL |
| `POSTGRES_USER` | `.env` DB-ноды | пользователь, создаваемый образом PostgreSQL |
| `POSTGRES_PASSWORD` | `.env` DB-ноды | пароль пользователя PostgreSQL |
| `POSTGRES_DB` | `.env` DB-ноды | база, создаваемая при первом старте контейнера |
| `PGADMIN_DEFAULT_EMAIL` | `.env` DB-ноды | логин в pgAdmin |
| `PGADMIN_DEFAULT_PASSWORD` | `.env` DB-ноды | пароль в pgAdmin |

Главное правило: `DBNAME` в приложении должен совпадать с `POSTGRES_DB` на DB-ноде, а `SPRING_DATASOURCE_USERNAME`/`SPRING_DATASOURCE_PASSWORD` должны совпадать с `POSTGRES_USER`/`POSTGRES_PASSWORD`.

