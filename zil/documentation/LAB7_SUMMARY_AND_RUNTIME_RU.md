# LAB7 — что сделано: итоги, файлы, ВМ и учебные данные

Документ фиксирует выполнение LAB7 по диалогу и текущему состоянию проекта. Перед сдачей **всегда сверяйте** имя БД, порты и строку таблицы курса с актуальным Google Sheet.

**ТЗ LAB7 (кратко):**

- PostgreSQL вынести на отдельный узел `hl12.zil`, запуск в Docker Compose вместе с pgAdmin.
- В команде запуска PostgreSQL: `command: postgres -c max_connections=1000`.
- Приложение подключается к `hl12.zil` как к основной БД; имя БД — из таблицы курса.
- В методичке пример URL:  
  `spring.datasource.url=jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5432}/${DBNAME:hl5}?currentSchema=${SCHEMANAME:hl5}`  
  У нас фактически: **другой `DBPORT` и `DBNAME`** (см. ниже).

---

## 1. Что именно сделали

1. **На DB-ноде `hl12`** подняли стек в Docker Compose:
   - контейнер PostgreSQL 16 (`lab7-postgres`);
   - контейнер pgAdmin (`lab7-pgadmin`);
   - `max_connections=1000` через `command: postgres -c max_connections=1000`.
2. **Порт хоста:** на `hl12` внешний `5432` был занят, поэтому проброс сделали **`5437:5432`** (снаружи `5437`, внутри контейнера PostgreSQL по-прежнему `5432`).
3. Создали **базу и пользователя** `hl7`, схему **`hl7`**.
4. **На app-ноде `hl07`** обновили репозиторий, ветка **`lab7`**, пересобрали и запустили приложение с переменными окружения на удалённую БД.
5. В **`application.properties`** перевели URL на формат с `DBHOST`, `DBPORT`, `DBNAME`, `SCHEMANAME`.
6. В **`zil/docker-compose.yml`** у сервиса `app` задали env для LAB7 и **убрали `depends_on: postgres`**, чтобы приложение не зависело от локального PostgreSQL.
7. Проверили: **Flyway** накатил `V1` и `V2` в схему `hl7`, API `/cars`, `/clients`, `/rents` отдают данные, **Swagger** открывается через SSH-туннель.
8. **Git:** коммит `272f817` «LAB7: подключить приложение к удаленной БД» запушен в ветку **`lab7`** на GitHub.

---

## 2. Виртуальные машины и как к ним заходить

| Роль | Хостнейм (пример) | SSH (с Windows PowerShell) |
|------|-------------------|----------------------------|
| Прикладная ВМ (приложение) | `hl07` | `ssh -p 2307 hl@hlssh.zil.digital` |
| DB-нода | `hl12` | `ssh -p 2312 hl@hlssh.zil.digital` |

**Учебный SSH-пользователь:** `hl`  
**Пароль SSH:** из таблицы/методички курса (в репозиторий не копировать).

**Внутренняя сеть (пример из диалога):**

- `hl12.zil` → `10.60.3.9`

---

## 3. Где что лежит на серверах

### DB-нода `hl12`

| Что | Путь / заметка |
|-----|----------------|
| Каталог compose LAB7 | `~/katya` (в диалоге использовали этот путь вместо `~/lab7-db`) |
| Файлы | `docker-compose.yml`, `.env` (`.env` **не** коммитить в публичный GitHub) |
| Контейнеры | `lab7-postgres`, `lab7-pgadmin` |

**Порты:**

- PostgreSQL с хоста `hl12`: **`5437`** → контейнерный **`5432`**.
- pgAdmin на `hl12`: **`8081`** (доступ с ПК через туннель).

### App-нода `hl07`

| Что | Путь |
|-----|------|
| Репозиторий | `~/work/Labs_hls` |
| Проект приложения | `~/work/Labs_hls/zil` |
| Ветка | `lab7` (отслеживает `origin/lab7`) |

---

## 4. Файлы в репозитории (локально и на ВМ после `git pull`)

| Файл | Назначение LAB7 |
|------|-----------------|
| `zil/src/main/resources/application.properties` | JDBC URL через `DBHOST`, `DBPORT`, `DBNAME`, `SCHEMANAME`; логин/пароль через `SPRING_DATASOURCE_*` |
| `zil/docker-compose.yml` | У `app`: env `DBHOST`, `DBPORT`, `DBNAME`, `SCHEMANAME`, учётные данные БД; без `depends_on: postgres` |
| `zil/documentation/LAB7_PLAN_RU.md` | План/шпаргалка (если есть в рабочей копии; может быть в `.gitignore`) |

**Коммит LAB7:** `272f817` — сообщение: «LAB7: подключить приложение к удаленной БД».

---

## 5. Учебные пароли и имена (как в диалоге)

Это **учебный стенд**. Для реальной среды используйте сложные пароли и не публикуйте их.

| Параметр | Значение в диалоге |
|----------|-------------------|
| Имя БД (`POSTGRES_DB`, `DBNAME`) | `hl7` |
| Пользователь PostgreSQL (`POSTGRES_USER`, `SPRING_DATASOURCE_USERNAME`) | `hl7` |
| Пароль PostgreSQL (`POSTGRES_PASSWORD`, `SPRING_DATASOURCE_PASSWORD`) | `hl7` |
| Схема (`SCHEMANAME`, `currentSchema`) | `hl7` |
| pgAdmin email (`PGADMIN_DEFAULT_EMAIL`) | `ekaterinatryuh@yandex.ru` |
| Пароль pgAdmin (`PGADMIN_DEFAULT_PASSWORD`) | `hl7` |

**Фактический JDBC URL приложения (из логов):**

```text
jdbc:postgresql://hl12.zil:5437/hl7?currentSchema=hl7
```

**Отличие от строки методички:** в задании default-порт `5432`; у нас с app-ноды используется **`5437`**, потому что на DB-ноде порт `5432` на хосте был занят и сделали проброс `5437:5432`.

---

## 6. SSH-туннели с Windows

**pgAdmin:**

```powershell
ssh -p 2312 -L 8081:127.0.0.1:8081 hl@hlssh.zil.digital
```

Браузер: `http://localhost:8081`  
В pgAdmin к серверу PostgreSQL: host **`postgres`**, port **`5432`** (внутри одного compose).

**Приложение / Swagger:**

```powershell
ssh -p 2307 -L 8080:127.0.0.1:8083 hl@hlssh.zil.digital
```

Браузер: `http://localhost:8080/swagger-ui/index.html`  
На самой ВМ приложение слушает **`8083`**.

URL вида `http://localhost:8080/...` **не вводить в bash на сервере** — открывать в браузере или использовать `curl` на нужном порту.

---

## 7. Быстрые проверки (уже проходили успешно)

**С app-ноды `hl07`:**

```bash
getent hosts hl12.zil
nc -vz hl12.zil 5437
docker exec -it zil-app env | grep -E 'DBHOST|DBPORT|DBNAME|SCHEMANAME|SPRING_DATASOURCE'
docker compose logs app --tail 120
curl http://localhost:8083/cars
```

**На DB-ноде `hl12`:**

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "SHOW max_connections;"
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "\dt hl7.*"
```

Ожидание после миграций: в схеме `hl7` таблицы `cars`, `clients`, `rents`, `flyway_schema_history`; по 4 строки в каждой из трёх бизнес-таблиц (после `V2`).

---

## 8. Заметки по Git

- Незакоммиченное локально (на момент диалога): изменение **`.gitignore`** (добавлено игнорирование `zil/documentation/`). При необходимости — отдельный коммит.
- Если на ВМ не видна ветка `lab7`: сначала `git push` с машины разработчика, затем на ВМ `git fetch` и `git switch lab7`.

---

*Документ сгенерирован по ходу выполнения LAB7; перед сдачей сверьте все значения с актуальной таблицей курса.*
