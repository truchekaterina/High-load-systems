# LAB2: Spring Data JPA + PostgreSQL — пошаговый план для проекта `zil`

> **Текущий код (ветка LAB3):** схема и seed в **Flyway** (`db/migration`), стартовые данные **без** `DataInitializer`; Hibernate **`ddl-auto=validate`**. Полный стенд: **`docker compose --profile local-db up --build -d`**. Подробности — в разделе **[LAB3 — дополнение](#lab3-flyway--docker-compose)** в конце документа.

Этот документ написан для **новичка** и описывает **пошаговый путь LAB2**: пакет `rental`, переход с in-memory репозиториев на **JPA**, контроллеры в `zil/src/main/java/rental/`. Отдельные шаги про `DataInitializer` и `ddl-auto=update` относятся к **историческому** сценарию LAB2; в финальном проекте их заменяют миграции Flyway (см. LAB3).

Внешний репозиторий с курса (Bitbucket) можно **не клонировать** — делаете **по смыслу то же**: JPA + таблицы + Spring Data.

---

## Словарь (чтобы не путаться)

| Термин | Простыми словами |
|--------|------------------|
| **PostgreSQL** | Программа-сервер базы данных; данные лежат в файлах на диске и переживают перезапуск приложения. |
| **Docker / Compose** | Способ **одной командой** поднять PostgreSQL в изолированном «контейнере». Альтернатива — поставить PostgreSQL **напрямую на Windows**. |
| **JPA** | Стандарт Java: объекты в коде ↔ строки в таблицах. |
| **Hibernate** | Реализация JPA в Spring Boot; по аннотациям создаёт/обновляет таблицы (в учебном режиме). |
| **Spring Data JPA** | Вы пишете **интерфейс** `JpaRepository<Сущность, Id>` — Spring сам даёт `save`, `findById`, `findAll` и т.д. |
| **`ddl-auto`** | Режим: создавать/обновлять таблицы автоматически или только проверять. Для лабы часто `update` или `create-drop` на время разработки. |

---

## Что у вас сейчас (LAB1) и что станет (LAB2)

| Сейчас | После LAB2 |
|--------|------------|
| `CarRepository` — класс с `static HashMap` | Интерфейс `CarRepository extends JpaRepository<CarEntity, UUID>` (имя сущности уточните при рефакторинге) |
| Данные только в памяти | Данные в таблицах PostgreSQL |
| `DataInitializer` кладёт объекты в HashMap | Тот же сценарий, но **`repository.save(...)`** в реальную БД |

---

## Подготовка: Git

1. Откройте терминал в папке **`first_laba`** (родитель `zil`).
2. Убедитесь, что вы на ветке для второй лабы (у вас уже есть **`lab2-spring-data-jpa`**):

   ```bat
   git checkout lab2-spring-data-jpa
   git status
   ```

3. Все изменения LAB2 коммитьте **в этой ветке**. В конце — `git push origin lab2-spring-data-jpa` (или merge в `main` по требованию преподавателя).

---

## Этап 1. Развернуть PostgreSQL

У вас в **`zil/docker-compose.yml`** уже заданы параметры (если Docker работает):

| Параметр | Значение |
|----------|----------|
| Хост | `localhost` |
| Порт | `5433` на хосте (в `docker-compose.yml` проброс `5433:5432`; внутри контейнера и pgAdmin — `5432`) |
| БД | `car_rental` |
| Пользователь | `rental` |
| Пароль | `rental_pass` |

### Вариант A — Docker (как в ТЗ)

1. Запустите **Docker Desktop** (должен быть зелёным / «Engine running»).
2. В папке **`zil`**:

   ```bat
   docker compose --profile local-db up --build -d
   docker compose ps
   ```

3. Если Docker не заводится (WSL и т.д.) — не застревайте: переходите к варианту B.

### Вариант B — PostgreSQL без Docker

1. Скачайте установщик с [официального сайта](https://www.postgresql.org/download/windows/).
2. При установке запомните порт (**5432**), задайте пароль суперпользователя `postgres` или создайте отдельного пользователя.
3. Через **pgAdmin** или `psql` создайте базу **`car_rental`** и пользователя **`rental`** с паролем **`rental_pass`** (или свои значения — тогда те же впишете в `application.properties`).

**Важно:** в `application.properties` должны совпасть **хост, порт, имя БД, логин, пароль** с тем, что реально создано.

---

## Этап 2. Подключить Spring Data JPA в Gradle

Откройте **`zil/build.gradle`**.

1. В **`dependencies { }`** добавьте:

   ```gradle
   implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
   runtimeOnly 'org.postgresql:postgresql'
   ```

2. Для **тестов** без живого Postgres (удобно на ноутбуке) часто добавляют:

   ```gradle
   testRuntimeOnly 'com.h2database:h2'
   ```

3. Нажмите в IntelliJ **Reload Gradle Project** (иконка слона).

**Нюанс:** после добавления JPA приложение **не запустится**, пока не настроите подключение к БД (следующий этап).

---

## Этап 3. Настроить подключение к БД

Файл **`zil/src/main/resources/application.properties`**.

Добавьте (подставьте свои значения, если отличались от Docker):

```properties
# --- PostgreSQL ---
spring.datasource.url=jdbc:postgresql://localhost:5433/car_rental
spring.datasource.username=rental
spring.datasource.password=rental_pass

# JPA / Hibernate
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.format_sql=true
```

**Нюансы:**

- **`ddl-auto=update`** — Hibernate **создаст/обновит таблицы** под ваши `@Entity` (удобно для учёбы). Для «боевого» кода чаще миграции (Flyway) + `validate`.
- **Пароль в Git** — для зачёта можно оставить учебный пароль; в реальной жизни секреты выносят в переменные окружения или `application-local.properties` (файл в `.gitignore`).

Опционально: профиль **`application-test.properties`** с H2 для `src/test` — см. этап 9.

---

## Этап 4. Превратить модели в сущности JPA

Файлы: **`rental/model/Car.java`**, **`Client.java`**, **`Rent.java`**.

Для каждого класса:

1. Добавить **`@Entity`** (и при желании **`@Table(name = "...")`** — имена таблиц латиницей, snake_case).
2. Поле **`UUID id`** пометить **`@Id`**.  
   **Варианты генерации id:**  
   - генерировать UUID в **`@PrePersist`** вручную;  
   - или использовать поддержку UUID в Hibernate 6 / настройки из примеров курса.
3. **`Rent`**: сейчас у вас **`carId`** и **`clientId`** как UUID. Можно:
   - **простой путь:** оставить колонки `car_id`, `client_id` без связей `@ManyToOne` (минимум изменений в JSON API);  
   - **путь «как в учебнике»:** связи **`@ManyToOne`** к `Car` и `Client` — тогда проверьте JSON (нет ли циклических ссылок); при необходимости **`@JsonIgnore`** или DTO.

4. Остальные поля — обычные **`@Column`** там, где нужны ограничения (не обязательно на первом шаге).

Соберите проект: **`./gradlew compileJava`**. Исправьте импорты (`jakarta.persistence.*` в новых версиях Spring).

**Переход от LAB1:** в **`Application.java`** временно задано **`excludeName`** для DataSource/JPA, чтобы приложение **стартовало без PostgreSQL**, пока код ещё на HashMap. Когда репозитории станут **`JpaRepository`** и в БД реально ходите — **удалите весь блок `excludeName`** и поднимите Docker/Postgres перед `bootRun`.

---

## Этап 5. Заменить репозитории на Spring Data JPA

Сейчас у вас **три класса** с `HashMap`:

- `rental/repository/CarRepository.java`
- `ClientRepository.java`
- `RentRepository.java`

**План действий:**

1. **Удалить** реализацию на `HashMap` (или переименовать старые файлы, чтобы не путаться, например в `...InMemory` — но проще удалить и создать заново).
2. Создать **интерфейсы** с тем же пакетом `rental.repository`:

   ```java
   public interface CarRepository extends JpaRepository<Car, UUID> {
       // методы по необходимости — см. ниже
   }
   ```

3. Метод **`findByModelAndCity`** из старого `CarRepository` оформить как **имя метода** в интерфейсе:

   ```java
   List<Car> findByModelAndCity(String model, String city);
   ```

   (имена полей в сущности `Car` должны совпадать: `model`, `city`).

4. Для **`RentRepository`** добавить запросы под логику **`RentService.isCarAvailable`**: сейчас там перебор всех аренд. В JPA лучше **один запрос** (`@Query` JPQL или native SQL), который проверяет пересечение даты с интервалом `[startDate, endDate]` для нужных машин. Это самый «сложный» кусок LAB2 — разбейте на маленькие шаги: сначала заставьте просто `findAll()` из БД работать, потом оптимизируйте запрос.

5. Аннотация **`@Repository`** на **интерфейсе** не обязательна — Spring Data сам создаёт прокси.

**Нюанс:** класс **`ServicesConfig`** создаёт бины сервисов вручную. Имена типов **`CarRepository`** должны совпадать с новыми интерфейсами — Spring подставит реализации автоматически.

---

## Этап 6. Обновить сервисы

Файлы: **`CarService`**, **`ClientService`**, **`RentService`**.

- Вместо старых методов `save`/`findById`/… используйте методы **`JpaRepository`**:  
  `save`, `findById`, `findAll`, `deleteById` и т.д.
- **`findById`** возвращает **`Optional`** — если не найдено, бросайте **`EntityException`**, как в LAB1 (`orElseThrow`).
- Обновление сущности: загрузили из БД → изменили поля → **`save`**.

Проверка: **`./gradlew compileJava`**.

---

## Этап 7. Контроллеры

Пути **`/cars`, `/clients`, `/rents`** лучше **не менять**, чтобы Postman и тесты остались валидными.

Проверьте только сериализацию **`Rent`**, если добавили связи JPA (возможны циклы — тогда **`@JsonIgnore`** на полях связи или отдельные DTO).

---

## Этап 8. Наполнение БД (`DataInitializer`)

Файл **`rental/configuration/DataInitializer.java`**.

- Логика та же: создать несколько `Car`, `Client`, `Rent`.
- Вместо вызовов старого in-memory репозитория — **`carRepository.save(...)`** и т.д.
- **Нюанс:** при каждом запуске **`save`** может пытаться вставить дубликаты по `id`. Варианты:
  - проверять **`count() == 0`** перед вставкой;
  - или один раз очистить таблицы в dev (осторожно);
  - или фиксированные UUID и **`save`** только если записи нет (через `findById`).

---

## Этап 9. Тесты

Папка **`zil/src/test/java/rental/controller/`**.

Сейчас в тестах вызывается **`repository.clear()`** — в JPA такого метода «из коробки» нет. Замените на:

- **`deleteAll()`** у соответствующих репозиториев в **`@BeforeEach`**, или  
- профиль тестов с **H2 in-memory** и **`ddl-auto=create-drop`** в **`src/test/resources/application.properties`**.

Запуск:

```bat
cd zil
gradlew.bat test
```

Все тесты должны быть **зелёными**.

---

## Этап 10. Ручная проверка

1. Поднята БД (Docker или локальный Postgres).
2. Запуск приложения: **`gradlew.bat bootRun`** или Run в IntelliJ.
3. В логах — без ошибок подключения к БД, Hibernate может показать SQL.
4. Браузер / Postman: **`GET http://localhost:8083/cars`** — JSON с данными.
5. Проверка **`/rents/availability`** — как в LAB1.

---

## Этап 11. Коммит и показ преподавателю

```bat
cd first_laba
git add .
git status
git commit -m "LAB2: Spring Data JPA, PostgreSQL, начальные данные"
git push -u origin lab2-spring-data-jpa
```

Преподавателю: ссылка на репозиторий + ветка **`lab2-spring-data-jpa`**, кратко в README что добавлено (можно обновить **`zil/README.md`** разделом LAB2).

---

## Типичные проблемы (новичок)

| Симптом | Что проверить |
|---------|----------------|
| `Failed to configure a DataSource` | Нет настроек `spring.datasource.*` или опечатка в URL/логине. |
| `Connection refused` к localhost:5433 | PostgreSQL в Docker не запущен или другой порт в `application.properties`. |
| Таблицы не создаются | Нет `@Entity` / не тот пакет для сканирования / ошибка в `ddl-auto`. |
| `could not execute statement` / constraint | Дубликаты id, нарушение FK — смотрите SQL в логе. |
| Тесты падают | Тесты всё ещё бьют в Postgres без БД — настройте H2 для тестов. |
| Docker не стартует | Используйте **локальный PostgreSQL** — по ТЗ это допустимо. |

---

## Порядок работы «от простого к сложному» (рекомендуемый)

1. БД доступна (Docker или Windows).  
2. Gradle: JPA + драйвер postgres (+ H2 для тестов).  
3. `application.properties` — datasource + `ddl-auto=update`.  
4. Одна сущность (например `Car`) + один `JpaRepository` + минимальный запуск `bootRun` — таблица появилась в pgAdmin.  
5. Остальные сущности и репозитории.  
6. Сервисы и `DataInitializer`.  
7. Запрос для `isCarAvailable`.  
8. Тесты.  
9. README + git push.

---

## Ссылки из ТЗ

- Docker Compose + pgAdmin (образец): [proghunter.ru — PostgreSQL и pgAdmin в Docker](https://proghunter.ru/articles/running-postgresql-and-pgadmin-in-docker)  
- Эталон по стилю кода (если откроете доступ): ветка `feature/spring-boot-data-jpa` в репозитории курса на Bitbucket.

Удачи: идите **маленькими коммитами** (например: «добавлен JPA и Car entity», «переведены репозитории», «обновлён DataInitializer») — так проще откатить шаг, если что-то сломалось.

---

## LAB3: Flyway + Docker Compose {#lab3-flyway--docker-compose}

**Цель ТЗ:** Dockerfile для приложения; в `src/main/resources/db/migration` — **DDL** (создание схемы) и **DML** (INSERT начальных данных); поднять **приложение и PostgreSQL** через **Docker Compose**; продемонстрировать стенд (логи, API).

### Что сделано в проекте `zil`

| Требование | Реализация |
|------------|------------|
| **DDL** | `V1__init_schema.sql` — таблицы под сущности `Car`, `Client`, `Rent` |
| **DML** | `V2__seed_data.sql` — тестовые строки (те же UUID, что удобны для Postman) |
| **Flyway** | `spring.flyway.enabled=true` в `application.properties`; зависимости `spring-boot-starter-flyway` и `flyway-database-postgresql` в `build.gradle` |
| **Hibernate** | `spring.jpa.hibernate.ddl-auto=validate` — таблицы **не** создаёт Hibernate, только сверка с `@Entity` |
| **Dockerfile** | Многостадийный: **`eclipse-temurin:25-jdk-alpine`** — сборка **`bootJar`** через **`java -classpath …/gradle-wrapper.jar … GradleWrapperMain`** (без `./gradlew`, чтобы не зависеть от CRLF); финальный образ **`eclipse-temurin:25-jre-alpine`**, `java -jar` fat-jar `module1-1.0-SNAPSHOT.jar` |
| **Compose** | `docker-compose.yml`: сервис **`postgres`** (порт хоста **5433**), сервис **`app`** (сборка из Dockerfile, порт **8083**), **`depends_on`** с **healthcheck** Postgres |

### Запуск и проверка (без доп. скриптов)

Из папки **`zil`** при запущенном Docker Desktop:

```bat
docker compose --profile local-db up --build -d
docker compose ps
docker compose logs app --tail 40
```

Ожидание: **`zil-postgres`** — healthy, **`zil-app`** — running. API: `http://localhost:8083/cars` (и `/clients`, `/rents`).

Только БД под **IntelliJ** / **`gradlew bootRun`**: `docker compose --profile local-db up -d postgres` (JDBC на хосте: `localhost:5433` — см. `application.properties`).

### Замечания для защиты

- **Почему Alpine:** на части установок Docker Desktop для Windows образ **`eclipse-temurin:25-jre`** (glibc) давал ошибку **`exec java: input/output error`**; **`-alpine`** на том же проекте обычно работает.
- **Переменные окружения в Compose** переопределяют URL БД для контейнера **`app`** (`postgres:5432`), тогда как в файле по умолчанию для хоста указан **`localhost:5433`**.

Подробнее для пользователя: **`zil/README.md`** (раздел LAB3 и таблица «чеклист ТЗ»).
