# LAB7 — пошаговая демонстрация на защите (очень подробно)

Используй этот сценарий, чтобы **показать каждый пункт ТЗ**. Где писать команды: **Windows** (PowerShell), **DB-нода `hl12`**, **app-нода `hl07`**.

Перед защитой открой актуальную [таблицу курса](https://docs.google.com/spreadsheets/d/1CoubOXgx3PPpACLwhk_1lJ7QfoCFjmLf9jEzhSnu0qM/edit?gid=0#gid=0) и сверь **имя БД** и **порты** для своей строки.

---

## Схема «где я сейчас»

| Место | Как понять | Зачем |
|-------|------------|--------|
| **Твой ПК, PowerShell** | Приглашение вида `PS C:\...>` | Туннели в браузер, второе окно PowerShell |
| **DB-нода** | После SSH видно `hl@hl12:~$` | Docker с PostgreSQL и pgAdmin |
| **App-нода** | После SSH видно `hl@hl07:~$` | Контейнер приложения, логи, `curl` |

**SSH с ПК:**

```powershell
# DB-нода (PostgreSQL + pgAdmin на hl12)
ssh -p 2312 hl@hlssh.zil.digital

# App-нода (Spring Boot на hl07)
ssh -p 2307 hl@hlssh.zil.digital
```

Пароль — тот же учебный `hl`, что в методичке (не озвучивай вслух пароль в записи).

---

## Пункты ТЗ и что показать преподавателю

### ТЗ 1. «БД на отдельном узле hl12.zil, в контейнере»

**Где:** сначала **SSH на `hl12`**, потом команды.

```bash
hostname
```

Ожидаешь: `hl12`.

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Ожидаешь контейнеры вроде `lab7-postgres`, `lab7-pgadmin`.

**Что сказать:** PostgreSQL крутится на DB-ноде `hl12`, не на той же машине, где приложение.

---

### ТЗ 2. «Запуск через docker compose: контейнер БД + контейнер pgAdmin»

**Где:** на **`hl12`**, в каталоге, где лежит compose (у тебя в диалоге это было `~/katya`).

```bash
cd ~/katya
docker compose ps
```

Ожидаешь: сервисы `postgres` и `pgadmin` в состоянии `running` / `healthy`.

**Что сказать:** Оба сервиса подняты одним `docker compose`.

---

### ТЗ 3. «В команде postgres: max_connections=1000»

**Где:** на **`hl12`**.

**Вариант А — показать compose (если спросят файл):**

```bash
cd ~/katya
grep -A2 "command:" docker-compose.yml
```

Должна быть строка вида: `postgres -c max_connections=1000`.

**Вариант Б — показать живую БД:**

```bash
docker exec -it lab7-postgres psql -U hl7 -d hl7 -c "SHOW max_connections;"
```

Ожидаешь: `1000`.

---

### ТЗ 4. «Приложение использует hl12.zil и имя БД из таблицы»

**Где:** на **`hl07`**, в папке проекта.

```bash
cd ~/work/Labs_hls/zil
git branch --show-current
```

Ожидаешь: `lab7` (или та ветка, куда залит LAB7).

```bash
docker exec -it zil-app env | grep -E 'DBHOST|DBPORT|DBNAME|SCHEMANAME|SPRING_DATASOURCE'
```

Ожидаешь примерно:

- `DBHOST=hl12.zil`
- `DBPORT=5437` (см. пояснение ниже про порт)
- `DBNAME=hl7`
- `SCHEMANAME=hl7`
- логин/пароль приложения к БД

**Логи (главное доказательство JDBC):**

```bash
cd ~/work/Labs_hls/zil
docker compose logs app --tail 80 | grep -E 'jdbc:postgresql|Flyway|hl7'
```

Должна быть строка с `jdbc:postgresql://hl12.zil:5437/hl7?currentSchema=hl7` и упоминанием миграций Flyway.

**Что сказать про методичку:** В задании пример с `${DBPORT:5432}` и `hl5`. У меня в таблице БД **`hl7`**, в `application.properties` формат тот же, через `DBHOST`, `DBPORT`, `DBNAME`, `SCHEMANAME`. Порт **`5437`**, потому что на `hl12` порт хоста `5432` был занят, сделали проброс **`5437:5432`**: снаружи подключаемся к **5437**, внутри контейнера PostgreSQL всё равно **5432**.

---

### ТЗ 5. «application.properties в форме из методички»

**Где:** на **своём ноутбуке** в репозитории (или на `hl07` через `cat`).

На ВМ:

```bash
grep -E '^spring.datasource' ~/work/Labs_hls/zil/src/main/resources/application.properties
```

Должно быть что-то в духе:

```properties
spring.datasource.url=jdbc:postgresql://${DBHOST:localhost}:${DBPORT:5437}/${DBNAME:hl7}?currentSchema=${SCHEMANAME:hl7}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME:hl7}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD:hl7}
```

---

## Прокинуть pgAdmin на твой компьютер (браузер = «локальный» доступ)

pgAdmin у тебя **в контейнере на `hl12`**, веб-интерфейс на порту **8081** этой машины. Чтобы открыть его **как будто локально**, делается **SSH-туннель**.

### Шаг 1. На ПК открой **новое** окно PowerShell

**Не закрывай** это окно, пока показываешь pgAdmin в браузере.

```powershell
ssh -p 2312 -L 8081:127.0.0.1:8081 hl@hlssh.zil.digital
```

Введи пароль. Дальше в этом окне может висеть «пустой» SSH — это нормально.

### Шаг 2. Открой браузер на ПК (Chrome и т.д.)

В адресной строке:

```text
http://localhost:8081
```

Войди в pgAdmin (email и пароль из твоего `.env` на `hl12`, в учебном варианте из диалога: email `ekaterinatryuh@yandex.ru`, пароль как задавала для pgAdmin).

### Шаг 3. Показать таблицы и данные

В дереве слева: **Servers → твой сервер → Databases → hl7 → Schemas → hl7 → Tables**.

Должны быть `cars`, `clients`, `rents`, `flyway_schema_history`.

Можно открыть таблицу **View/Edit Data → All Rows** или выполнить в Query Tool:

```sql
SET search_path TO hl7;
SELECT COUNT(*) FROM cars;
SELECT COUNT(*) FROM clients;
SELECT COUNT(*) FROM rents;
```

Ожидаешь по **4** строки в каждой (после сидов Flyway).

---

## Альтернатива: настольный pgAdmin / DBeaver на ПК (не обязательно)

Если преподаватель хочет именно **клиент на Windows**, а не веб:

1. В **отдельном** PowerShell подними туннель на **порт PostgreSQL на hl12** (у тебя с хоста это **5437**):

```powershell
ssh -p 2312 -L 5437:127.0.0.1:5437 hl@hlssh.zil.digital
```

2. В DBeaver / pgAdmin Desktop:

- Host: `127.0.0.1`
- Port: `5437`
- Database: `hl7`
- User / Password: как в таблице курса / твоём `.env` (в учебном варианте `hl7` / `hl7`)

Окно SSH с туннелем не закрывать.

---

## Показать, что API ходит в эту же БД

**Где:** на **`hl07`**.

```bash
curl -s http://localhost:8083/cars | head -c 200
curl -s http://localhost:8083/clients | head -c 200
curl -s http://localhost:8083/rents | head -c 200
```

Должен вернуться JSON с массивами (не пустой, не ошибка).

**Swagger с твоего ПК (через туннель):**

Новое PowerShell:

```powershell
ssh -p 2307 -L 8080:127.0.0.1:8083 hl@hlssh.zil.digital
```

Браузер:

```text
http://localhost:8080/swagger-ui/index.html
```

**Важно:** строки `http://localhost:8080/...` **не вводить в bash** на сервере — только в браузере или через `curl` с нужным портом.

---

## Что перепроверить, если что-то «не взлетело»

Сделай по порядку на нужной машине.

| Симптом | Где смотреть | Команда / действие |
|---------|--------------|-------------------|
| Не открывается `localhost:8081` | ПК | Туннель `2312` запущен? Окно SSH не закрыто? |
| pgAdmin не пускает | hl12 | `docker compose logs pgadmin --tail 50` в `~/katya` |
| Приложение не стартует | hl07 | `docker compose logs app --tail 150` |
| Нет таблиц | hl12 | Приложение хоть раз успешно стартовало с Flyway? Логи app на `hl07` |
| `DBHOST` не hl12 | hl07 | Пересборка: `docker compose up --build -d --force-recreate app` в `~/work/Labs_hls/zil`, ветка `lab7` |
| Порт 5437 недоступен с hl07 | hl07 | `nc -vz hl12.zil 5437` |
| Имя БД не то | Таблица курса | Сверить `DBNAME` / `POSTGRES_DB` / схему |

---

## Минимальный чеклист перед выходом к преподавателю

- [ ] На `hl12`: `docker compose ps` — postgres + pgadmin.
- [ ] На `hl12`: `SHOW max_connections` → `1000`.
- [ ] С ПК: туннель 8081 → браузер → pgAdmin → схема `hl7` → таблицы и строки.
- [ ] На `hl07`: env контейнера `zil-app` — `DBHOST=hl12.zil`, правильные `DBNAME` / `DBPORT`.
- [ ] На `hl07`: в логах есть JDBC на `hl12.zil` и успешный Flyway.
- [ ] На `hl07` или с ПК через туннель: Swagger или `curl` `/cars`.

---

*Если пути на сервере отличаются (`~/katya` vs `~/lab7-db`), подставь свой каталог, где лежит `docker-compose.yml` для LAB7.*
