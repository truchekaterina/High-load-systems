# Сервис аренды автомобилей (LAB1)

Одно приложение **Spring Boot 4**: REST API для машин, клиентов и аренд. Данные хранятся **в памяти** (после перезапуска сбрасываются). Базы данных нет.

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

Сервер: **http://localhost:8082** (порт в `src/main/resources/application.properties`).

Тесты:

```bat
gradlew.bat test
```

---

## Как устроен проект (логика)

Запрос идёт сверху вниз и возвращается обратно:

```
HTTP  →  Controller  →  Service  →  Repository  →  HashMap в памяти
HTTP  ←  Controller  ←  Service  ←  Repository  ←
```

| Слой | Папка в коде | Роль |
|------|----------------|------|
| Точка входа | `rental.Application` | Запуск Spring Boot, сканирует пакет `rental` |
| REST | `rental.controller` | URL → вызов сервиса, JSON наружу |
| Бизнес-логика | `rental.service` | Правила (в т.ч. проверка доступности авто) |
| Хранение | `rental.repository` | `Map<UUID, …>` в памяти |
| Модели | `rental.model` | Car, Client, Rent |
| Ошибки | `rental.exception` | `EntityException` → через `EntityExceptionHandler` ответ **400** |
| Настройка | `rental.configuration` | `ServicesConfig` — бины сервисов; `DataInitializer` — тестовые данные при старте |

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
│   └── configuration/       ServicesConfig, DataInitializer
├── src/main/resources/
│   └── application.properties
├── src/test/java/rental/controller/   интеграционные тесты (MockMvc)
├── build.gradle
├── settings.gradle
├── gradlew / gradlew.bat
└── postman_collection.json            готовые запросы для Postman
```

Пакет один — **`rental`**, без лишней вложенности `com...`.

---

## Тестовые данные при старте

`DataInitializer` создаёт 4 автомобиля, 4 клиента, 4 аренды (фиксированные UUID — удобно для Postman).

Примеры:

| Что открыть | URL |
|-------------|-----|
| Все машины | GET http://localhost:8082/cars |
| Все клиенты | GET http://localhost:8082/clients |
| Все аренды | GET http://localhost:8082/rents |

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
3. Переменная базового URL должна указывать на `http://localhost:8082`.

Проверка доступности вручную: метод **GET**, URL `.../rents/availability`, вкладка Params — `model`, `date` (формат `YYYY-MM-DD`), `city`.

Примеры для данных из `DataInitializer` (Toyota Camry в Moscow, аренды 1–10 и 15–20 марта):

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
| Порт занят (`Port ... already in use`) | В `application.properties` смените `server.port` на свободный (например `8083`). |
| Ошибки компиляции | Из папки `zil`: `gradlew.bat clean test` |

---

## Ограничения учебного проекта

Нет БД, безопасности и сложной валидации — только то, что нужно для лабораторной.

---

## LAB2: PostgreSQL в Docker

**Подробный пошаговый план всего LAB2 (JPA, репозитории, тесты, git):** файл **[LAB2_PLAN.md](LAB2_PLAN.md)** в папке `zil`.

В папке **`zil`** есть **`docker-compose.yml`** (PostgreSQL + pgAdmin).

**Запуск у себя на ПК** (сначала откройте **Docker Desktop** и дождитесь, пока иконка перестанет «крутиться»):

```bat
cd путь\к\zil
docker compose up -d
```

Или двойной щелчок по **`docker-up.bat`** в папке `zil`.

Проверка: `docker compose ps` — контейнеры `zil-postgres`, `zil-pgadmin` в статусе **running**.  
pgAdmin: **http://localhost:5050** (логин `admin@example.com`, пароль `admin`). Подключение к серверу БД: хост **`postgres`**, порт **5432**, user **`rental`**, БД **`car_rental`**, пароль **`rental_pass`**.

Если видите **«Docker Desktop is unable to start»** — в Docker Desktop: **Troubleshoot → Restart** или включите **WSL 2** / обновите Windows; без работающего демона команды `docker` не выполняются.

---

## Git и публикация на GitHub

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
