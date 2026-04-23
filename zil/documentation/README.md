# Сервис аренды автомобилей (Spring Boot)

**Полное руководство по LAB1–LAB3, запуску и сдаче:** **[LABS_GUIDE_RU.md](LABS_GUIDE_RU.md)** (в начале — **«Два режима»**: как не получить ошибку «Port 8083 already in use» между Docker и IntelliJ).

Одно приложение **Spring Boot 4**: REST API для машин, клиентов и аренд.

**LAB1:** данные в памяти (HashMap), после перезапуска сбрасываются.  
**LAB2** (ветка **`lab2-spring-data-jpa`**): **PostgreSQL**, **Spring Data JPA**; тесты на **H2** без Docker.  
**LAB3:** схема и начальные данные — **Flyway** (`src/main/resources/db/migration`: **DDL** в `V1__…`, **DML** в `V2__…`); контейнеризация — многостадийный **`Dockerfile`** (сборка **`bootJar`** внутри образа, **Alpine Temurin**) + **`docker compose`** (сервисы **postgres** и **app**). Один запуск полного стенда из папки **`zil`**: `docker compose up --build -d`.  
**LAB4 (нагрузка k6):** в **`k6/`** — **`load.js`** (сценарий k6) и **`run-lab4.ps1`** (серия прогонов + график внутри одного скрипта). Кратко: **[k6/README_LAB4_RU.md](k6/README_LAB4_RU.md)**, план: **[documentation/LAB4_PLAN.md](documentation/LAB4_PLAN.md)**.

Пошаговый план LAB2 (история/шпаргалка): **[LAB2_PLAN.md](LAB2_PLAN.md)** — в конце файла есть **дополнение по LAB3**. Развёрнуто только про LAB3: **[LAB3_PLAN.md](LAB3_PLAN.md)**.

---

## Что нужно для запуска

- **JDK 25** (см. `java.toolchain` в `build.gradle`). Если Gradle пишет, что не находит JDK под toolchain, установите [Eclipse Temurin 25](https://adoptium.net/) или другой JDK 25 и задайте `JAVA_HOME`.
- Команды **`gradlew`** нужно запускать **из папки `zil`** (там лежат `gradlew.bat` и `build.gradle`). Если открыть терминал в `first_laba` или в другом каталоге — сборка не найдёт проект.

**Windows** (в папке `zil`):

```bat
gradlew.bat bootRun
```

Либо двойной щелчок по **`run.bat`** в папке `zil` — он сам перейдёт в нужный каталог и запустит приложение.

**Linux / macOS** (в папке `zil`):

```bash
chmod +x gradlew
./gradlew bootRun
```

Сервер: **http://localhost:8083** (порт в `src/main/resources/application.properties`). Контейнер **`zil-app`** и запуск из IntelliJ / **`gradlew bootRun`** используют **тот же** порт — одновременно два процесса API на одной машине не поднимайте; для разработки с БД в Docker достаточно `docker compose up -d postgres` и локального `bootRun`.

Тесты:

```bat
gradlew.bat test
```

---

## Как устроен проект (логика)

Запрос идёт сверху вниз и возвращается обратно:

```
HTTP  →  Controller  →  Service  →  Repository  →  PostgreSQL (JPA)
HTTP  ←  Controller  ←  Service  ←  Repository  ←
```

| Слой | Папка в коде | Роль |
|------|----------------|------|
| Точка входа | `rental.Application` | Запуск Spring Boot, сканирует пакет `rental` |
| REST | `rental.controller` | URL → вызов сервиса, JSON наружу |
| Бизнес-логика | `rental.service` | Правила (в т.ч. проверка доступности авто) |
| Хранение | `rental.repository` | `JpaRepository` → таблицы в PostgreSQL |
| Модели | `rental.model` | Car, Client, Rent |
| Ошибки | `rental.exception` | `EntityException` → через `EntityExceptionHandler` ответ **400** |
| Настройка | `rental.configuration` | `ServicesConfig` — бины сервисов; стартовые данные — миграция Flyway `V2__seed_data.sql` |

Сервисы **не** помечены `@Service`: их создаёт `ServicesConfig` вручную, репозитории Spring находит сам (`@Repository`).

---

## Структура папок (исходники)

```
zil/
├── src/main/java/rental/
│   ├── Application.java
│   ├── controller/          CarController, ClientController, RentController
│   ├── service/
│   ├── repository/
│   ├── model/
│   ├── exception/           EntityException, EntityExceptionHandler
│   └── configuration/       ServicesConfig
├── src/main/resources/
│   ├── application.properties
│   └── db/migration/        Flyway: V1__init_schema.sql (DDL), V2__seed_data.sql (INSERT)
├── src/test/java/rental/controller/   интеграционные тесты (MockMvc)
├── Dockerfile                         LAB3: builder (JDK Alpine) + runtime (JRE Alpine)
├── docker-compose.yml                 LAB3: postgres + app
├── .dockerignore
├── build.gradle
├── settings.gradle
├── gradlew / gradlew.bat              стандартный Gradle Wrapper (локально; в Docker — wrapper JAR)
├── LABS_GUIDE_RU.md                   единое руководство LAB1–LAB3 и запуск
├── LAB2_PLAN.md                       план LAB2 + дополнение LAB3
├── LAB3_PLAN.md                       подробный план только LAB3
├── documentation/
│   └── LAB4_PLAN.md                   LAB4: k6, график avg vs VU
├── k6/                                LAB4: load.js, run-lab4.ps1, README_LAB4_RU.md
└── postman_collection.json            необязательно: импорт в Postman
```

Пакет один — **`rental`**, без лишней вложенности `com...`.

---

## Тестовые данные при старте

Миграция **`V2__seed_data.sql`** создаёт 4 автомобиля, 4 клиента, 4 аренды (фиксированные UUID — удобно для Postman).

Примеры:

| Что открыть | URL |
|-------------|-----|
| Все машины | GET http://localhost:8083/cars |
| Все клиенты | GET http://localhost:8083/clients |
| Все аренды | GET http://localhost:8083/rents |

---

## REST API (кратко)

| Метод | Путь | Действие |
|-------|------|----------|
| GET | `/cars`, `/cars/{id}` | Список / одна машина |
| POST, PUT, DELETE | `/cars`, `/cars/{id}` | Создать / обновить / удалить |
| GET | `/clients`, `/clients/{id}` | Аналогично клиентам |
| POST, PUT, DELETE | `/clients`, `/clients/{id}` | |
| GET | `/rents`, `/rents/{id}` | Аналогично арендам |
| POST, PUT, DELETE | `/rents`, `/rents/{id}` | |
| **GET** | **`/rents/availability`** | Доступность авто **по названию модели** на дату в городе |
| **GET** | **`/stats`** | Сводка: число машин, клиентов, аренд (для LAB4 / k6) |

Параметры доступности (все обязательны):

```
GET /rents/availability?model=Toyota Camry&date=2026-03-12&city=Moscow
```

Ответ: JSON `true` или `false`.  
`false`, если в городе нет машины с такой моделью, либо на эту дату уже есть аренда у подходящей машины.

**Как это считается (идея):**  
`CarRepository.findByModelAndCity` → список машин; для каждой смотрятся аренды этой машины; если на выбранную дату дата попадает внутрь `[startDate, endDate]` хотя бы одной аренды — машина «занята». Если есть хотя бы одна подходящая машина без такой аренды на дату — `true`.

---

## Postman

1. Запустите приложение (`bootRun`).
2. Импортируйте **`postman_collection.json`**.
3. Переменная базового URL должна указывать на `http://localhost:8083`.

Проверка доступности вручную: метод **GET**, URL `.../rents/availability`, вкладка Params — `model`, `date` (формат `YYYY-MM-DD`), `city`.

Примеры для данных из миграции (Toyota Camry в Moscow, аренды 1–10 и 15–20 марта):

| date | Ожидание | Почему |
|------|----------|--------|
| 2026-03-12 | `true` | между двумя арендами |
| 2026-03-05 | `false` | внутри первой аренды |
| Toyota Camry + city=SPB | `false` | такой модели в SPB нет в тестовых данных |

---

## Если что-то не работает

| Симптом | Что сделать |
|---------|-------------|
| `Could not find a Java installation ... languageVersion=25` | Установите **JDK 25**, перезапустите терминал, проверьте `java -version` и переменную `JAVA_HOME`. |
| `Project directory ... may be part of a composite build` / не находит задачи | Вы не в папке **`zil`**: `cd` в каталог, где лежит `gradlew.bat`. |
| Порт занят (`Port ... already in use`) | В `application.properties` смените `server.port` на свободный (например `8084`) или остановите второй экземпляр приложения / контейнер `zil-app`. |
| Ошибки компиляции | Из папки `zil`: `gradlew.bat clean test` |

---

## Ограничения учебного проекта

Нет продакшен-безопасности и тяжёлой валидации — только то, что нужно для лабораторной.

---

## LAB2 / LAB3: Docker

**План LAB2 и кратко LAB3:** **[LAB2_PLAN.md](LAB2_PLAN.md)** (в конце — раздел про Flyway и Compose). **Только LAB3 подробно:** **[LAB3_PLAN.md](LAB3_PLAN.md)**.

**Чеклист ТЗ LAB3 (что проверяет преподаватель):**

| Требование | Где в проекте |
|------------|----------------|
| Dockerfile | `zil/Dockerfile` |
| Инициализация схемы (DDL) и начальные данные (DML) | `zil/src/main/resources/db/migration/` |
| Приложение + БД в Docker Compose | `zil/docker-compose.yml` |
| Демонстрация стенда | `docker compose ps`, логи `app`, `curl`/браузер на `http://localhost:8083/cars` и др. |

### Только PostgreSQL (приложение из IntelliJ или `gradlew bootRun`)

Откройте **Docker Desktop**, затем в папке **`zil`**:

```bat
docker compose up -d postgres
```

БД: **`localhost:5433`**, пользователь **`rental`**, БД **`car_rental`**, пароль **`rental_pass`**.

### Полный стенд LAB3: PostgreSQL + приложение в контейнере

В папке **`zil`** одной командой поднимается БД и собирается/запускается приложение (**`bootJar` выполняется внутри образа**, см. многостадийный **`Dockerfile`**):

```powershell
docker compose down -v
docker compose up --build -d
docker compose ps
```

Ожидается: **`zil-postgres`** (healthy), **`zil-app`** (running). API: **http://localhost:8083/cars**

Логи приложения: `docker compose logs app` (должны быть строки Flyway про миграции).

При сбоях сборки образа (обрыв сети): перезапуск Docker Desktop и повтор `docker compose up --build -d`.

Если **«Docker Desktop is unable to start»** — **Troubleshoot → Restart** или проверка **WSL 2**; без демона Docker команды не выполняются.

---

## LAB4: k6 (Windows, PowerShell)

1. Поднять API (`docker compose up --build -d` или `gradlew.bat bootRun` с БД; не занимайте **8083** двумя процессами).
2. В папке **`k6`**: **`.\run-lab4.ps1`** — серия прогонов k6, JSON в `k6/reports/`, картинка `avg_vs_vus.png` (нужны **k6** и **Python** + `matplotlib`).

Пошагово: **[k6/README_LAB4_RU.md](k6/README_LAB4_RU.md)**. Смысл задания: **[documentation/LAB4_PLAN.md](documentation/LAB4_PLAN.md)**.

---

## Git и публикация на GitHub

**Перед открытым репозиторием:** не коммитьте файлы с реальными секретами. Должны остаться **локально** (они в `.gitignore` в корне `first_laba` и в `zil/`): `.env`, `application-local.properties`, ключи `*.pem`, keystore, `credentials.json` и т.д. В проекте в открытом виде только **учебные** учётные данные БД (`rental` / `rental_pass`) для Docker и `bootRun`.

Репозиторий инициализирован в каталоге **`first_laba`** (ветка `main`, первый коммит уже есть).

Чтобы **выложить на GitHub**:

1. Зайдите на [github.com](https://github.com) → **New repository** → имя, без галочки «Add README» → **Create repository**.
2. В терминале (в папке `first_laba`):

```bat
git remote add origin https://github.com/ВАШ_ЛОГИН/ИМЯ_РЕПО.git
git push -u origin main
```

Если GitHub предложит только `master`, выполните: `git branch -M main` перед первым `push`.

Авторизация: Personal Access Token (Settings → Developer settings) или GitHub CLI (`gh auth login`).
