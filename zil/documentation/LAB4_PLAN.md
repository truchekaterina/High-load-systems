# LAB4 — k6: пошагово под ваше ТЗ (проект `zil`)

Файл плана: **`zil/documentation/LAB4_PLAN.md`**. Скрипты нагрузки: **`zil/k6/`**.

Порт API: **8083**. Установка k6: [https://k6.io/docs/get-started/installation/](https://k6.io/docs/get-started/installation/)

---

## Смысл лабы

**k6** многократно вызывает ваш REST API с разным числом виртуальных пользователей (**VU**). Вы смотрите, как меняется **среднее время ответа** и строите **график avg от VU** (несколько точек, удобно удваивать нагрузку: 5 → 10 → 20 → 40 → 80).

В репозиторий по ТЗ кладёте **JS-профиль** (`load.js` и при необходимости `load-sweep.js`) и **генератор графика** (`plot.py`). Сам k6 график не рисует — только сохраняет метрики в JSON (`--summary-export`).

---

## Требования из методички (чеклист)

| Требование | Как закрываем |
|------------|----------------|
| Развернуть k6 | `k6 version` в терминале |
| Простейшее получение данных одной таблицы | **`GET /cars`** (или `/clients`) — добавите в сценарий на шаге 3 |
| `executor: 'ramping-vus'`, `k6/http` | Только в **`load.js`** |
| POST одной «простой» сущности (без ссылок) | Сейчас: **`POST /clients`** |
| GET «дополнительно», статистика | **`GET /stats`** в бэкенде (`StatsController`) — добавите вызов в k6 на шаге 2 |
| Пропорция **50/50** | Два **параллельных** сценария k6: одни VU только `POST /clients`, другие только `GET /stats` (см. шаг 2) |
| График **avg** от **VU**, **4–5 точек**, удвоение | Прогоны **`load-sweep.js`** + **`plot.py`** |
| Git: js-конфиг + генератор графика | `load.js`, `load-sweep.js`, `plot.py` |

«Киносеанс, пользователь…» в задании — примеры; у нас аналог простой сущности — **клиент** (`/clients`).

---

## Шаг 0. Поднять сервис

Из папки **`zil`**:

```text
docker compose up --build -d
```

Проверка: `http://localhost:8083/cars` открывается. Для шагов со статистикой: `http://localhost:8083/stats` (если в проекте есть `StatsController`).

---

## Шаг 1. Самый базовый сценарий (уже в репозитории)

Файл **`zil/k6/load.js`**:

- только **`executor: 'ramping-vus'`**;
- только **`import http from 'k6/http'`**;
- в каждой итерации один запрос: **`POST /clients`** с уникальными `driverLicense` / телефоном (через `uuid` и номер итерации).

Запуск:

```text
cd zil\k6
k6 run load.js
```

Опционально сохранить сводку:

```text
k6 run --summary-export summary-ramping.json load.js
```

Пока вы **не добавляете** второй эндпойнт — так и задумано: сначала «потыкать» один POST.

---

## Шаг 2. GET статистики + пропорция 50/50 (два пула, без рандома)

Смысл: **две группы** виртуальных пользователей работают **одновременно** — у одной только `POST /clients`, у другой только `GET /stats`. В сумме нагрузка **~50/50** (в `load.js` на первом «плато» 3+2=5, дальше 5+5=10, 10+10=20).

В **`load.js`**: в `options` два **сценария** (`scenarios: { post_clients: …, get_stats: … }`), у каждого:

- `executor: 'ramping-vus'`;
- `exec: 'postClients'` или `exec: 'getStats'`;
- `stages` с **своим** `target` (суммарно нужное число VU, пополам).

В коде — две **именованные** функции `export function postClients()` и `export function getStats()` (см. текущий `load.js`).

Запуск:

```text
k6 run load.js
```

**`load-sweep.js`:** тот же принцип (два сценария, те же `exec`), но `constant-vus`; `TARGET_VUS` — **суммарно**; пополам делится между пулами (`Math.floor/2` и остаток).

---

## Шаг 3. Простейшее чтение таблицы

В конец каждой итерации (после POST или GET `/stats`) добавьте, например:

```javascript
http.get(`${BASE_URL}/cars`, { tags: { endpoint: 'list_cars' } });
```

и `check` на статус 200. Так вы явно нагружаете **получение данных одной таблицы**.

Снова синхронизируйте **`load-sweep.js`** с **`load.js`**.

---

## Шаг 4. График avg vs VU (4–5 точек)

1. Используйте **`load-sweep.js`**: там **`constant-vus`**, число VU задаётся **`TARGET_VUS`**, длительность **`DURATION`**.

2. Из **`zil/k6`** в **cmd** несколько прогонов (пример для 5, 10, 20, 40, 80):

   ```text
   k6 run -e TARGET_VUS=5 -e DURATION=45s --summary-export summary-5.json load-sweep.js
   k6 run -e TARGET_VUS=10 -e DURATION=45s --summary-export summary-10.json load-sweep.js
   k6 run -e TARGET_VUS=20 -e DURATION=45s --summary-export summary-20.json load-sweep.js
   k6 run -e TARGET_VUS=40 -e DURATION=45s --summary-export summary-40.json load-sweep.js
   k6 run -e TARGET_VUS=80 -e DURATION=45s --summary-export summary-80.json load-sweep.js
   ```

3. Установите **matplotlib** и постройте картинку:

   ```text
   pip install matplotlib
   python plot.py --out avg_vs_vus.png 5 summary-5.json 10 summary-10.json 20 summary-20.json 40 summary-40.json 80 summary-80.json
   ```

Файлы **`summary-*.json`** в `.gitignore` папки `k6` — в git обычно не коммитят; в отчёт приложите **`avg_vs_vus.png`** и опишите оси.

---

## Шаг 5. Что коммитить в git

- `zil/k6/load.js` — профиль **ramping-vus** для методички  
- `zil/k6/load-sweep.js` — тот же сценарий приёма, но **constant-vus** для точек графика  
- `zil/k6/plot.py` — генератор графика  
- по желанию: `zil/k6/.gitignore`  
- этот файл: `zil/documentation/LAB4_PLAN.md`  
- бэкенд **`GET /stats`**, если добавляли под лабу: `zil/src/main/java/rental/controller/StatsController.java`

---

## Частые проблемы

| Симптом | Действие |
|---------|----------|
| `connection refused` на 8083 | Не запущен Docker / приложение |
| Ошибки после изменения только `load.js` | Обновите **`load-sweep.js`**, иначе график будет по старой логике |
| `plot.py` падает | `pip install matplotlib` |

---

## Ссылки

- [k6 docs](https://k6.io/docs/)  
- [ramping-vus](https://k6.io/docs/using-k6/scenarios/executors/#ramping-vus)  
- [HTTP requests](https://k6.io/docs/using-k6/http-requests/)  
- [JSON summary](https://k6.io/docs/results-output/end-of-test/json-summary/)
