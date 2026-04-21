# LAB3: Dockerfile + Flyway + Docker Compose — подробный пошаговый план для проекта `zil`

Этот документ сделан в том же стиле, что `LAB2_PLAN.md`: максимально подробно, простыми словами и с командами под Windows.

Проект: сервис аренды авто (`rental`) в модуле `zil`, Spring Boot приложение с REST API:

- `GET /cars`
- `GET /clients`
- `GET /rents`
- `GET /rents/availability?model=...&date=YYYY-MM-DD&city=...`

Порт приложения: `8083`.

---

## Словарь LAB3 (без сложных терминов)

| Термин | Простыми словами |
|--------|------------------|
| Dockerfile | Инструкция, как собрать Docker-образ вашего приложения. |
| Docker image | Готовый «слепок» приложения с нужной Java/зависимостями. |
| Container | Запущенный экземпляр image (как процесс, но в изоляции). |
| docker compose | Способ одной командой запустить сразу несколько контейнеров (например, `app` + `postgres`). |
| Flyway | Механизм миграций: SQL-файлы `V1`, `V2`, ... применяются по порядку. |
| DDL | SQL для структуры БД (таблицы, ключи, ограничения). |
| DML | SQL для данных (INSERT/UPDATE/DELETE). |
| `ddl-auto=validate` | Hibernate не создаёт таблицы, а только проверяет, что схема уже совпадает с `@Entity`. |

---

## Что уже есть в проекте и что значит для LAB3

По текущему состоянию `zil` у вас уже есть ключевые части LAB3:

- В `build.gradle` уже добавлены JPA, PostgreSQL и Flyway зависимости.
- В `application.properties` уже настроены переменные окружения (`SPRING_DATASOURCE_*`) и `spring.jpa.hibernate.ddl-auto=validate`.
- В `src/main/resources/db/migration` уже есть:
  - `V1__init_schema.sql` (DDL),
  - `V2__seed_data.sql` (DML).
- В `zil/Dockerfile` уже есть multi-stage сборка.
- В `zil/docker-compose.yml` уже описаны `postgres` и `app`.
- В коде нет активного `DataInitializer` (это правильно для Flyway seed).

То есть фактически вам остаётся:
1) проверить/понимать каждую часть,  
2) уметь поднять стенд,  
3) показать преподавателю демонстрацию.

---

## Цель LAB3 (как трактовать задание)

В LAB3 нужно уметь объяснить и показать 4 пункта:

1. **Dockerfile для контейнеризации приложения**.  
2. **Инициализация БД миграциями Flyway** (`db/migration`: DDL + DML).  
3. **Развёртывание app + db через docker compose**.  
4. **Рабочая демонстрация стенда преподавателю** (контейнеры подняты, API отвечает, данные в БД есть).

---

## Подготовка перед началом

### 1) Переключиться на рабочую ветку

Откройте PowerShell в корне репозитория:

```powershell
cd C:\Users\1\Desktop\neurohelp\first_laba
git checkout -b lab3-docker-compose
git status
```

Если ветка уже есть:

```powershell
git checkout lab3-docker-compose
git status
```

### 2) Проверить Docker Desktop

1. Запустите Docker Desktop.
2. Дождитесь статуса типа `Engine running`.
3. В PowerShell проверьте:

```powershell
docker version
docker compose version
docker info
```

Если `docker info` не отвечает, демонстрацию не начинайте — сначала исправьте Docker.

---

## Этап A. `build.gradle` — зависимости Flyway/JPA/PostgreSQL

Файл: `C:\Users\1\Desktop\neurohelp\first_laba\zil\build.gradle`

### Что должно быть в `dependencies { }`

```gradle
implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
runtimeOnly 'org.postgresql:postgresql'
implementation 'org.springframework.boot:spring-boot-starter-flyway'
implementation 'org.flywaydb:flyway-database-postgresql'
```

### Зачем это нужно

- `data-jpa` + `postgresql` — работа приложения с PostgreSQL.
- `starter-flyway` + `flyway-database-postgresql` — автоматическое выполнение миграций Flyway при старте.

### Проверка

```powershell
cd C:\Users\1\Desktop\neurohelp\first_laba\zil
.\gradlew.bat dependencies > deps.txt
```

Если сборка проходит, зависимости подключены корректно.

---

## Этап B. `application.properties` — env-переменные и `ddl-auto=validate`

Файл: `C:\Users\1\Desktop\neurohelp\first_laba\zil\src\main\resources\application.properties`

### Должно быть так (ключевые строки)

```properties
server.port=8083

spring.datasource.url=${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5433/car_rental}
spring.datasource.username=${SPRING_DATASOURCE_USERNAME:rental}
spring.datasource.password=${SPRING_DATASOURCE_PASSWORD:rental_pass}
spring.datasource.driver-class-name=org.postgresql.Driver

spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
spring.jpa.open-in-view=false

spring.flyway.enabled=true
```

### Почему важно

- Локально (IDE/хост): по умолчанию подключение к `localhost:5433`.
- В контейнере app: те же параметры переопределяются через `SPRING_DATASOURCE_*`.
- `ddl-auto=validate` заставляет соблюдать архитектуру LAB3: схема создаётся миграциями, а не Hibernate.

---

## Этап C. Миграции Flyway в `db/migration`

Папка: `C:\Users\1\Desktop\neurohelp\first_laba\zil\src\main\resources\db\migration`

Внутри должны быть 2 файла:

- `V1__init_schema.sql` (DDL),
- `V2__seed_data.sql` (DML).

### 1) `V1__init_schema.sql` — создание таблиц

Используйте имена таблиц/полей ровно под текущие сущности `Car`, `Client`, `Rent`:

```sql
CREATE TABLE cars (
    id UUID PRIMARY KEY,
    vin VARCHAR(255) NOT NULL UNIQUE,
    model VARCHAR(255) NOT NULL,
    color VARCHAR(255) NOT NULL,
    rental_cost_per_day NUMERIC(19, 2) NOT NULL,
    city VARCHAR(255) NOT NULL,
    salon_name VARCHAR(255) NOT NULL
);

CREATE TABLE clients (
    id UUID PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    driver_license VARCHAR(255) NOT NULL,
    phone VARCHAR(255) NOT NULL
);

CREATE TABLE rents (
    id UUID PRIMARY KEY,
    car_id UUID NOT NULL,
    client_id UUID NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_cost NUMERIC(19, 2) NOT NULL,
    CONSTRAINT fk_rents_car FOREIGN KEY (car_id) REFERENCES cars (id),
    CONSTRAINT fk_rents_client FOREIGN KEY (client_id) REFERENCES clients (id),
    CONSTRAINT chk_rents_dates CHECK (end_date >= start_date)
);
```

### 2) `V2__seed_data.sql` — начальные INSERT

Вставляйте согласованные UUID и корректные FK.

Минимальный пример структуры:

```sql
INSERT INTO cars (id, vin, model, color, rental_cost_per_day, city, salon_name) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'WVWZZZ3CZWE123456', 'Toyota Camry', 'Black', 50.00, 'Moscow', 'Salon A');

INSERT INTO clients (id, full_name, driver_license, phone) VALUES
('6ba7b810-9dad-11d1-80b4-00c04fd430c1', 'Иван Иванов', 'DL123456', '+79001234567');

INSERT INTO rents (id, car_id, client_id, start_date, end_date, total_cost) VALUES
('a1b2c3d4-e5f6-7890-abcd-ef1234567890', '550e8400-e29b-41d4-a716-446655440001', '6ba7b810-9dad-11d1-80b4-00c04fd430c1', '2026-03-01', '2026-03-10', 500.00);
```

Если у вас уже заполненный `V2`, не дублируйте одинаковые UUID.

---

## Этап D. Что делать с `DataInitializer`

Для LAB3 seed должен идти через Flyway (`V2__seed_data.sql`), а не через Java-инициализатор.

### Правильный вариант

- Либо класса `DataInitializer` нет (как сейчас в проекте) — это отлично.
- Либо, если он есть в другой ветке, его нужно отключить:
  - удалить класс,
  - или убрать `@Component`,
  - или закомментировать запуск `CommandLineRunner`.

### Почему

Если оставить и Flyway seed, и `DataInitializer`, получите дубли, ошибки уникальности (`vin`) и непредсказуемые данные.

---

## Этап E. `Dockerfile` для Spring Boot приложения

Файл: `C:\Users\1\Desktop\neurohelp\first_laba\zil\Dockerfile`

Рекомендуемое содержимое (соответствует текущему проекту):

```dockerfile
FROM eclipse-temurin:25-jdk-alpine AS builder
WORKDIR /app

COPY gradlew .
COPY gradle gradle
COPY gradle.properties .
COPY settings.gradle .
COPY build.gradle .
COPY src src

RUN ["java", "-classpath", "gradle/wrapper/gradle-wrapper.jar", "org.gradle.wrapper.GradleWrapperMain", "clean", "bootJar", "-x", "test", "--no-daemon"]

FROM eclipse-temurin:25-jre-alpine
WORKDIR /app

COPY --from=builder /app/build/libs/module1-1.0-SNAPSHOT.jar app.jar

EXPOSE 8083
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### Пояснение

- Stage `builder` собирает jar внутри контейнера.
- Stage runtime запускает только готовый jar (образ легче).
- `EXPOSE 8083` совпадает с `server.port=8083`.

---

## Этап F. `.dockerignore`

Файл: `C:\Users\1\Desktop\neurohelp\first_laba\zil\.dockerignore`

Минимально полезное содержимое:

```dockerignore
.git
.gradle
build
out
.idea
*.iml
docker
```

### Зачем

Чтобы в build context не отправлялись тяжёлые и ненужные файлы, сборка образа будет быстрее.

---

## Этап G. `docker-compose.yml` (Postgres + App)

Файл: `C:\Users\1\Desktop\neurohelp\first_laba\zil\docker-compose.yml`

Пример рабочего варианта:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: zil-postgres
    environment:
      POSTGRES_USER: rental
      POSTGRES_PASSWORD: rental_pass
      POSTGRES_DB: car_rental
    ports:
      - "5433:5432"
    volumes:
      - zil_pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U rental -d car_rental"]
      interval: 5s
      timeout: 5s
      retries: 10

  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: zil-app
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/car_rental
      SPRING_DATASOURCE_USERNAME: rental
      SPRING_DATASOURCE_PASSWORD: rental_pass
    ports:
      - "8083:8083"

volumes:
  zil_pgdata:
```

Ключевая мысль:

- с хоста БД доступна как `localhost:5433`,
- внутри compose сетью приложение видит БД как `postgres:5432`.

---

## Запуск стенда (пошагово для Windows)

Откройте PowerShell:

```powershell
cd C:\Users\1\Desktop\neurohelp\first_laba\zil
docker compose down
docker compose up --build -d
docker compose ps
```

Проверка логов:

```powershell
docker compose logs postgres
docker compose logs app
```

В логах `app` ищите успешный старт Spring Boot и применение Flyway миграций (`V1`, `V2`).

---

## Проверка API после запуска

### Вариант 1: браузер/Postman

- [http://localhost:8083/cars](http://localhost:8083/cars)
- [http://localhost:8083/clients](http://localhost:8083/clients)
- [http://localhost:8083/rents](http://localhost:8083/rents)
- [http://localhost:8083/rents/availability?model=Toyota%20Camry&date=2026-03-05&city=Moscow](http://localhost:8083/rents/availability?model=Toyota%20Camry&date=2026-03-05&city=Moscow)

### Вариант 2: PowerShell

```powershell
Invoke-RestMethod http://localhost:8083/cars
Invoke-RestMethod http://localhost:8083/clients
Invoke-RestMethod http://localhost:8083/rents
Invoke-RestMethod "http://localhost:8083/rents/availability?model=Toyota%20Camry&date=2026-03-05&city=Moscow"
```

---

## Сценарий демонстрации преподавателю (готовый скрипт)

1. Показать структуру файлов LAB3:
   - `Dockerfile`
   - `.dockerignore`
   - `docker-compose.yml`
   - `src/main/resources/db/migration/V1__init_schema.sql`
   - `src/main/resources/db/migration/V2__seed_data.sql`
   - `application.properties`

2. Запустить стенд:

```powershell
cd C:\Users\1\Desktop\neurohelp\first_laba\zil
docker compose up --build -d
docker compose ps
```

3. Показать, что контейнеры живы:

```powershell
docker compose logs app
docker compose logs postgres
```

4. Показать API-ответы (`/cars`, `/clients`, `/rents`, `/rents/availability`).

5. Коротко объяснить:
   - схему создаёт Flyway (`V1`),
   - данные добавляет Flyway (`V2`),
   - Hibernate только валидирует (`ddl-auto=validate`),
   - приложение и БД поднимаются одной командой `docker compose up`.

---

## Коммиты и push (после проверки)

Из корня репозитория:

```powershell
cd C:\Users\1\Desktop\neurohelp\first_laba
git status
git add zil/LAB3_PLAN.md
git commit -m "LAB3: add detailed deployment and migration guide"
git push -u origin lab3-docker-compose
```

Если работаете в другой ветке, замените имя ветки в `git push`.

---

## Быстрая самопроверка перед сдачей

- `docker compose up --build -d` запускается без ошибок.
- `docker compose ps` показывает `postgres` и `app` в состоянии Up/healthy.
- `GET /cars`, `GET /clients`, `GET /rents` возвращают JSON.
- `GET /rents/availability` возвращает `true/false`.
- В `application.properties` стоит `spring.jpa.hibernate.ddl-auto=validate`.
- Нет активного `DataInitializer`, который дублирует seed.

---

## Частые проблемы и как быстро исправить

| Проблема | Причина | Что сделать |
|---------|---------|-------------|
| `Connection refused` в `app` | БД не готова или неверный URL | Проверить `depends_on` + `healthcheck`, URL `jdbc:postgresql://postgres:5432/car_rental`. |
| Flyway ругается на SQL | Опечатка в DDL/DML | Проверить имена таблиц/колонок: `cars`, `clients`, `rents`, `rental_cost_per_day`, `full_name`, `car_id` и т.д. |
| `ddl-auto=validate` падает | Схема в БД не совпала с `@Entity` | Исправить `V1__init_schema.sql` или очистить volume и поднять заново. |
| `duplicate key` / `unique` ошибка | Дублируется seed (Flyway + DataInitializer) | Отключить `DataInitializer`, оставить только Flyway. |
| Порт `8083` занят | На хосте уже что-то слушает порт | Освободить порт, остановить второй экземпляр приложения или в compose сменить маппинг, например `8084:8083` (снаружи 8084, в контейнере 8083). |
| Порт `5433` занят | Локальный Postgres уже занял порт | Сменить хост-порт в compose, например `5434:5432`, и поправить локальный URL при запуске с IDE. |
| Старые данные мешают проверке | persisted volume хранит прежнее состояние | `docker compose down -v` и снова `docker compose up --build -d`. |

---

## Полезные команды на сдаче (коротко)

```powershell
cd C:\Users\1\Desktop\neurohelp\first_laba\zil
docker compose up --build -d
docker compose ps
docker compose logs app
Invoke-RestMethod http://localhost:8083/cars
docker compose down
```

Если нужно полностью «с нуля»:

```powershell
docker compose down -v
docker compose up --build -d
```

---

С таким планом вы закрываете LAB3 полностью: контейнеризация, миграции, compose-стенд и демонстрация рабочего результата.
