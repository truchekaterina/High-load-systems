# Счётчик доступных машин: `GET /rents/availability/count`

Краткое описание фичи, кода и готовые ссылки для Postman.

---

## Что сделано

Добавлен REST-эндпоинт, который возвращает **число машин** с заданной **моделью** (`model`) в заданном **городе** (`city`):

| Параметр `date` | Смысл поля `count` в ответе |
|-----------------|-------------------------------|
| **Указан** | Сколько машин **свободны в этот календарный день** (на машину в этот день не попадает ни одна аренда по интервалу `start_date`–`end_date`). |
| **Не указан** | Сколько **всего** таких машин в городе в парке (без проверки аренд). |

Старый эндпоинт **`GET /rents/availability`** по-прежнему отвечает **`true` / `false`**: есть ли **хотя бы одна** свободная машина. Новый эндпоинт даёт **точное количество**.

**Где в коде:**

- `src/main/java/rental/dto/AvailableCarsCountResponse.java` — формат JSON-ответа (`model`, `city`, `date`, `count`).
- `src/main/java/rental/service/RentService.java` — метод `countAvailableCars`.
- `src/main/java/rental/controller/RentController.java` — маршрут `/rents/availability/count`.
- `src/test/java/rental/controller/RentControllerTest.java` — тесты.
- `postman_collection.json` — папка **Availability (проверка доступности)** → запросы с суффиксом **count**.

Приложение должно быть запущено (например на порту **8083**). Базовый адрес в примерах: `http://localhost:8083`.

---

## Формат запроса

- **Метод:** `GET`
- **Путь:** `/rents/availability/count`
- **Обязательные query-параметры:** `model`, `city`
- **Необязательный:** `date` в формате ISO **`YYYY-MM-DD`**

---

## Ответ

Пример с датой:

```json
{
  "model": "Toyota Camry",
  "city": "Moscow",
  "date": "2026-03-12",
  "count": 1
}
```

Пример без даты (`date` в JSON будет `null`):

```json
{
  "model": "Toyota Camry",
  "city": "Moscow",
  "date": null,
  "count": 2
}
```

Значение **`model`** должно совпадать с тем, как модель записана в БД (как в Flyway и при создании машины), например **`Toyota Camry`**, а не только слово «Toyota».

---

## Postman: что куда вставлять

### 1. Импорт коллекции (по желанию)

**Import → Upload Files** — файл:

`zil/postman_collection.json`

(полный путь на вашем ПК, например: `C:\Users\1\Desktop\neurohelp\first_laba\zil\postman_collection.json`)

В коллекции откройте папку **Availability (проверка доступности)** — там есть готовые запросы **GET Availability count**.

### 2. Готовые ссылки для поля URL (вставить целиком в адресную строку запроса)

**С датой** — сколько машин данной модели в городе **свободны в этот день**:

```
http://localhost:8083/rents/availability/count?model=Toyota Camry&city=Moscow&date=2026-03-12
```

Подставьте свои **`date`**, **`model`**, **`city`**. Порт замените, если приложение не на 8083.

**Без даты** — сколько **всего** машин этой модели в городе:

```
http://localhost:8083/rents/availability/count?model=Toyota Camry&city=Moscow
```

**Другой город (пример):**

```
http://localhost:8083/rents/availability/count?model=Toyota Camry&city=SPB&date=2026-03-15
```

### 3. Если используете переменную `{{baseUrl}}` в коллекции

В **Variables** коллекции задайте:

`baseUrl` = `http://localhost:8083`

Тогда в URL можно писать:

```
{{baseUrl}}/rents/availability/count?model=Toyota Camry&city=Moscow&date=2026-03-12
```

и

```
{{baseUrl}}/rents/availability/count?model=Toyota Camry&city=Moscow
```

Метод запроса: **GET**, тело (**Body**) не нужно.

---

## Сравнение со старым эндпоинтом «да/нет»

Вставка в Postman (тоже GET, только путь **`/rents/availability`**, ответ — строка `true` или `false`):

```
http://localhost:8083/rents/availability?model=Toyota Camry&date=2026-03-12&city=Moscow
```

---

*Документ относится к коммиту с эндпоинтом `/rents/availability/count` в модуле `zil`.*
