# Руководство по лабораторным работам (LAB1 → LAB3): модуль `zil`

Сервис аренды автомобилей на **Spring Boot 4**, пакет **`rental`**. Этот документ — **единая точка входа**: история этапов по ТЗ курса, соответствие **LAB3**, команды запуска и сценарий сдачи преподавателю.

**Дополнительные материалы в репозитории:** [README.md](README.md) (обзор проекта), [LAB2_PLAN.md](LAB2_PLAN.md) (пошагово LAB2 + кратко LAB3), [LAB3_PLAN.md](LAB3_PLAN.md) (подробно только LAB3).

---

## Оглавление

1. [Краткая карта этапов (LAB1 → LAB3)](#1-краткая-карта-этапов-lab1--lab3)
2. [LAB1 — контекст (выполнено ранее)](#2-lab1--контекст-выполнено-ранее)
3. [LAB2 — контекст (выполнено ранее)](#3-lab2--контекст-выполнено-ранее)
4. [LAB3 — требования ТЗ и соответствие проекту](#4-lab3--требования-тз-и-соответствие-проекту)
5. [Что установить (перед любым запуском)](#5-что-установить-перед-любым-запуском)
6. [Порты и URL (важно запомнить)](#6-порты-и-url-важно-запомнить)
7. [Сценарий A: только PostgreSQL в Docker, приложение из IntelliJ / Gradle](#7-сценарий-a-только-postgresql-в-docker-приложение-из-intellij--gradle)
8. [Сценарий B: полный стенд LAB3 (приложение + БД в Docker)](#8-сценарий-b-полный-стенд-lab3-приложение--бд-в-docker)
9. [Проверка API (curl, PowerShell, Postman)](#9-проверка-api-curl-powershell-postman)
10. [Сдача преподавателю: чеклист демонстрации](#10-сдача-преподавателю-чеклист-демонстрации)
11. [Git: перед отправкой в GitHub](#11-git-перед-отправкой-в-github)
12. [Типичные проблемы и решения](#12-типичные-проблемы-и-решения)
13. [Быстрый старт LAB3 (шпаргалка)](#13-быстрый-старт-lab3-шпаргалка)

---

## 1. Краткая карта этапов (LAB1 → LAB3)

| Этап | Суть по ТЗ | В текущем коде `zil` |
|------|------------|----------------------|
| **LAB1** | Шаблон Spring Boot; своя бизнес-постановка; репозитории на **статических коллекциях** (HashMap), данные в памяти | Заменено: данных в памяти больше нет, используется **PostgreSQL + JPA** |
| **LAB2** | PostgreSQL (Docker Compose или локально); репозитории — **Spring Data JPA**; наполнение БД для тестов | Репозитории — интерфейсы `JpaRepository`; тесты на **H2** без Docker; начальные данные в продакшен-контуре задаются **Flyway (LAB3)** |
| **LAB3** | **Dockerfile**; **Flyway**: DDL + DML в `db/migration`; **docker compose**: приложение + БД; показать стенд | См. раздел [4](#4-lab3--требования-тз-и-соответствие-проекту) — всё на месте |

---

## 2. LAB1 — контекст (выполнено ранее)

**По ТЗ:** взять за основу код из ветки курса (`feature/spring-boot-test`), переделать под свою предметную область (аренда авто), репозитории реализовать через **статические поля-коллекции** (например HashMap), закоммитить и показать преподавателю.

**Зачем так делали:** быстро получить работающий REST без установки СУБД; данные теряются при перезапуске JVM.

**Что дальше:** в LAB2 коллекции заменены на обращение к **таблицам PostgreSQL** через JPA; в LAB3 схема и начальные данные фиксируются **SQL-миграциями Flyway**, а приложение дополнительно **упаковывается в Docker-образ**.

---

## 3. LAB2 — контекст (выполнено ранее)

**По ТЗ:** развернуть **PostgreSQL** (статья с Docker / pgAdmin или локальная установка); переделать репозитории на работу с БД по аналогии с веткой `feature/spring-boot-data-jpa`; наполнить БД тестовыми данными; коммит и показ.

**В проекте сейчас:**

- Слой доступа к данным: интерфейсы `CarRepository`, `ClientRepository`, `RentRepository` расширяют **`JpaRepository<…, UUID>`**.
- Подключение к PostgreSQL настраивается в **`src/main/resources/application.properties`** (по умолчанию с хоста: `jdbc:postgresql://localhost:5433/car_rental`, пользователь `rental`, пароль `rental_pass` — **учебные** значения).
- **Тесты** (`src/test/resources/application.properties`): **H2** в памяти, **`spring.flyway.enabled=false`**, Hibernate создаёт схему для тестов (`ddl-auto=create-drop`). Команда: из папки `zil` выполнить **`gradlew.bat test`** (или `./gradlew test` на Linux/macOS).

**Переход к LAB3:** начальные данные для «боевого» профиля не обязательно задавать Java-кодом — в текущей версии они приходят из миграции **`V2__seed_data.sql`**, а Hibernate только **проверяет** схему (`ddl-auto=validate`).

---

## 4. LAB3 — требования ТЗ и соответствие проекту

ТЗ LAB3:

1. Написать **Dockerfile** для контейнеризации приложения.  
2. В **`src/main/resources/db/migration`** — инициализация схемы (**DDL**) и начальных данных (**DML**, INSERT).  
3. Развернуть **приложение и БД** в **docker compose**.  
4. **Продемонстрировать** развёрнутый стенд преподавателю.

### Чеклист соответствия

| Пункт ТЗ | Где в репозитории | Проверка |
|----------|-------------------|----------|
| Dockerfile | [`Dockerfile`](Dockerfile) — многостадийная сборка: **JDK 25 Alpine** (Gradle `bootJar` через wrapper JAR), **JRE 25 Alpine**, `EXPOSE 8083`, запуск `java -jar app.jar` | `docker compose build app` |
| DDL | [`src/main/resources/db/migration/V1__init_schema.sql`](src/main/resources/db/migration/V1__init_schema.sql) | Логи Flyway при старте, таблицы в БД |
| DML (INSERT) | [`src/main/resources/db/migration/V2__seed_data.sql`](src/main/resources/db/migration/V2__seed_data.sql) | `GET /cars` и др. возвращают JSON с данными |
| Docker Compose (app + DB) | [`docker-compose.yml`](docker-compose.yml) — сервисы **`postgres`**, **`app`**, healthcheck, том для данных | `docker compose up --build -d`, `docker compose ps` |
| Демонстрация | Раздел [10](#10-сдача-преподавателю-чеклист-демонстрации) ниже | Команды + URL |

**Важно:** в **`application.properties`** включены **`spring.flyway.enabled=true`** и **`spring.jpa.hibernate.ddl-auto=validate`** — таблицы создаёт **Flyway**, Hibernate только сверяет модель с БД.

---

## 5. Что установить (перед любым запуском)

1. **JDK 25** (например Eclipse Temurin). Проверка: `java -version`.  
2. **Docker Desktop** (для LAB3 и для PostgreSQL в LAB2-стиле). Проверка: `docker version`, при необходимости `docker compose version`.  
3. Все команды Gradle и Docker ниже выполняются из папки **`zil`**:

   `C:\Users\1\Desktop\neurohelp\first_laba\zil`  
   (у вас путь может отличаться — используйте свой каталог с `build.gradle` и `gradlew.bat`).

Дополнительные **bat/ps1-скрипты** для сдачи **не обязательны**: достаточно **`gradlew.bat`** и **`docker compose`**.

---

## 6. Порты и URL (важно запомнить)

| Назначение | Значение |
|------------|----------|
| HTTP API приложения | **http://localhost:8083** (параметр `server.port` в `application.properties`) |
| PostgreSQL с **вашего компьютера** (IntelliJ, psql, DBeaver) | **localhost:5433** (в `docker-compose.yml` проброс `5433:5432`) |
| PostgreSQL **внутри Docker-сети** (из контейнера `app`) | хост **`postgres`**, порт **5432** (строка подключения задаётся в compose через `SPRING_DATASOURCE_URL`) |

**Конфликт порта 8083:** нельзя одновременно держать **два** процесса приложения на одном порту — например контейнер **`zil-app`** и **Run** в IntelliJ. Либо остановите приложение в Docker (`docker compose stop app`) и запускайте из IDE, либо наоборот — пользуйтесь только контейнером.

---

## 7. Сценарий A: только PostgreSQL в Docker, приложение из IntelliJ / Gradle

Удобно для отладки в IDE.

1. Запустите **Docker Desktop**.  
2. В PowerShell:

   ```powershell
   cd C:\Users\1\Desktop\neurohelp\first_laba\zil
   docker compose up -d postgres
   docker compose ps
   ```

   Должен быть **Up (healthy)** контейнер **`zil-postgres`**.

3. Запуск приложения:
   - либо в IntelliJ: класс **`rental.Application`**, **Run**;
   - либо в терминале: **`.\gradlew.bat bootRun`**

4. Убедитесь в логах: подключение к **`jdbc:postgresql://localhost:5433/car_rental`**, Flyway отработал, строка вида **`Started Application`**.

5. Проверка API: [раздел 9](#9-проверка-api-curl-powershell-postman).

---

## 8. Сценарий B: полный стенд LAB3 (приложение + БД в Docker)

Именно этот сценарий соответствует формулировке ТЗ «развернуть приложение и DB в docker compose».

1. Запустите **Docker Desktop**.  
2. В PowerShell:

   ```powershell
   cd C:\Users\1\Desktop\neurohelp\first_laba\zil
   docker compose down
   docker compose up --build -d
   ```

   Первая сборка может занять несколько минут (Gradle внутри образа скачивает дистрибутив и собирает проект).

3. Проверка:

   ```powershell
   docker compose ps
   docker compose logs app --tail 60
   ```

   Ожидается: **`zil-postgres`** — **healthy**, **`zil-app`** — **Up**; в логах **Flyway** и **`Started Application`**.

4. Проверка API: [раздел 9](#9-проверка-api-curl-powershell-postman) (базовый URL **http://localhost:8083**).

**Сброс данных БД** (новый «чистый» том PostgreSQL):

```powershell
docker compose down -v
docker compose up --build -d
```

---

## 9. Проверка API (curl, PowerShell, Postman)

Примеры для **полного стенда** или сценария A (приложение слушает **8083**):

**cmd / PowerShell (curl):**

```bat
curl.exe http://localhost:8083/cars
curl.exe http://localhost:8083/clients
curl.exe http://localhost:8083/rents
```

**PowerShell:**

```powershell
Invoke-RestMethod http://localhost:8083/cars
Invoke-RestMethod "http://localhost:8083/rents/availability?model=Toyota%20Camry&date=2026-03-12&city=Moscow"
```

**Postman:** импорт файла **[`postman_collection.json`](postman_collection.json)**; переменная **`baseUrl`** должна быть **`http://localhost:8083`**.

Корень **`http://localhost:8083/`** может вернуть **404** — это нормально, если нет контроллера на `/`.

---

## 10. Сдача преподавателю: чеклист демонстрации

1. Показать в репозитории файлы: **`Dockerfile`**, **`docker-compose.yml`**, **`db/migration/V1__…`**, **`V2__…`**.  
2. Выполнить при преподавателе (из **`zil`**):

   ```powershell
   docker compose up --build -d
   docker compose ps
   docker compose logs app --tail 40
   ```

3. Открыть в браузере или через curl:  
   **http://localhost:8083/cars** (и при желании `/clients`, `/rents`).  
4. Кратко объяснить: **Flyway** применяет миграции; **Hibernate** в режиме **`validate`**; в Docker приложение ходит в БД по имени **`postgres:5432`**, с хоста — **`localhost:5433`**.

---

## 11. Git: перед отправкой в GitHub

```powershell
cd C:\Users\1\Desktop\neurohelp\first_laba
git status
git branch
```

- Коммитьте осмысленными сообщениями; ветку уточняйте у преподавателя (**`lab3-docker-flyway`**, **`main`** и т.д.).  
- **Не коммитьте** личные секреты: используйте игнорируемые файлы (см. корневой **`.gitignore`**: `.env`, `application-local.properties`, ключи `*.pem` и т.д.).  
- Учебные **`rental` / `rental_pass`** в `docker-compose` и properties — это не ваш личный пароль от внешних сервисов; для публичного репозитория это обычная учебная схема.

---

## 12. Типичные проблемы и решения

| Симптом | Что сделать |
|---------|-------------|
| **`Port 8083 already in use`** | Остановите второй экземпляр: `docker compose stop app` или завершите локальный Java-процесс; либо временно смените `server.port` (и не забудьте обновить compose, если меняете порт в контейнере). |
| **`Connection refused` к `localhost:5433`** | Не запущен Postgres: `docker compose up -d postgres` или полный `docker compose up -d`. |
| **Сборка Docker: `exec java: input/output error`** (Windows) | Часто лечится образами **Alpine** (как в текущем `Dockerfile`); перезапуск Docker Desktop, `wsl --shutdown`; в крайнем случае — Troubleshoot → Reset. |
| **Flyway / validate ошибка** | Несовпадение схемы и сущностей: проверьте `V1__init_schema.sql` и аннотации `@Entity`; не смешивайте ручные правки БД без миграций. |
| **Пустые или странные данные** | Полный сброс тома: `docker compose down -v`, затем снова `up --build -d`. |
| **`gradlew` / тесты: не найден JDK 25** | Установите JDK 25, задайте **`JAVA_HOME`**, перезапустите терминал и IntelliJ. |

---

## 13. Быстрый старт LAB3 (шпаргалка)

```powershell
cd <путь>\first_laba\zil
docker compose up --build -d
docker compose ps
curl.exe http://localhost:8083/cars
```

Остановка без удаления данных:

```powershell
docker compose down
```

Проверка тестов без Docker:

```powershell
cd <путь>\first_laba\zil
.\gradlew.bat test
```

---

## Проверка работоспособности (на момент подготовки гайда)

- Выполнено: **`gradlew.bat test`** — сборка успешна, тесты проходят.  
- Выполнено: **`docker compose build app`** — образ собирается (multi-stage Dockerfile).

Если у вас после `git pull` что-то из этого падает — смотрите [раздел 12](#12-типичные-проблемы-и-решения) и актуальный **`README.md`**.

---

*Документ согласован с ТЗ LAB1–LAB3 курса и с фактической структурой модуля `zil`. Детальные пошаговые планы: [LAB2_PLAN.md](LAB2_PLAN.md), [LAB3_PLAN.md](LAB3_PLAN.md).*
