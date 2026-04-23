# LAB4 — k6: пошагово под ТЗ (проект `zil`, Windows)

Файл плана: **`zil/documentation/LAB4_PLAN.md`**. Скрипты нагрузки: **`zil/k6/`** (основной сценарий — **`rental-mixed.js`**, свип — **`run-sweep.ps1`**, график — **`plot_avg_vs_vus.py`**).

Порт API: **8083**. Установка k6: [k6 — Installation](https://k6.io/docs/get-started/installation/) (Windows: winget, MSI с сайта и т.д.).

---

## Смысл лабы

**k6** многократно вызывает REST API с разным числом виртуальных пользователей (**VU**). Смотрите, как меняется **среднее время ответа**, и строите **график avg от VU** (несколько точек, удобно удваивать: 10 → 20 → 40 → 80 → 160).

В репозиторий кладёте **один JS-профиль** — **`rental-mixed.js`** (два параллельных `ramping-vus`-сценария, Trend `k6_post_clients_ms` / `k6_get_stats_ms`) — и **генератор графика** — **`plot_avg_vs_vus.py`**. Серию прогонов с разными `TARGET_VUS` удобно запускать из **`run-sweep.ps1`**. Сам k6 график не рисует — метрики сохраняются в JSON (`--summary-export`).

---

## Требования из методички (чеклист)

| Требование | Как закрываем |
|------------|----------------|
| Развернуть k6 | `k6 version` в PowerShell |
| Простейшее получение данных одной таблицы | Можно добавить в сценарий **`GET /cars`** (см. шаг 3) |
| `executor: 'ramping-vus'`, `k6/http` | В **`rental-mixed.js`** (оба сценария) |
| POST «простой» сущности | **`POST /clients`** |
| GET статистики | **`GET /stats`** (`StatsController`) |
| Пропорция **50/50** | `POST_SHARE=0.5` — два пула, POST и GET (см. `rental-mixed.js`) |
| График **avg** от **VU**, **4–5 точек**, **две линии** (POST / GET) | **`run-sweep.ps1`** + **`plot_avg_vs_vus.py`** (читает `reports/summary-vus-*.json`) |
| Git: js-конфиг + генератор графика | `rental-mixed.js`, `plot_avg_vs_vus.py` |
| Windows | **`run-sweep.ps1`**, команды в PowerShell |

---

## Шаг 0. Поднять сервис

Из папки **`zil`**:

```text
cd zil
docker compose up --build -d
```

Проверка: `http://localhost:8083/cars`, при необходимости `http://localhost:8083/stats`.

---

## Шаг 1. Сценарий: `rental-mixed.js`

Файл **`zil/k6/rental-mixed.js`**:

- всегда **`ramping-vus`**, два сценария: **`postClients`** (POST `/clients`) и **`getStats`** (GET `/stats`);
- пик VU в каждом сценарии задаётся из **`TARGET_VUS`** и **`POST_SHARE`** (суммарно `TARGET_VUS`, разбиение на целочисленные пулы);
- Trend-метрики: **`k6_post_clients_ms`**, **`k6_get_stats_ms`** (используются в **`plot_avg_vs_vus.py`**).

Запуск:

```text
cd zil\k6
k6 run rental-mixed.js
```

Сохранение сводки (пример):

```text
$env:TARGET_VUS = "40"
k6 run --summary-export reports\summary-vus-40.json rental-mixed.js
```

---

## Шаг 2. Пропорция 50/50 (два пула)

**Две группы** VU работают **параллельно** — первая только `POST /clients`, вторая только `GET /stats`. Пропорция задаётся **`POST_SHARE`** (по умолчанию `0.5` ≈ 50/50). Подробности — в комментариях в **`rental-mixed.js`**.

---

## Шаг 3. Простейшее чтение таблицы (опционально)

В тело итерации можно добавить, например:

```javascript
http.get(`${baseUrl}/cars`, { tags: { endpoint: 'list_cars' } });
```

и `check` на 200. Правки — в **`rental-mixed.js`**.

---

## Шаг 4. График avg vs VU (несколько точек)

1. Поставьте **Python** и **`matplotlib`**: `py -m pip install matplotlib` (или `python -m pip`).

2. Из **`zil\k6`** в PowerShell:

   ```text
   .\run-sweep.ps1
   ```

   По умолчанию точки VU: 10, 20, 40, 80, 160; JSON — **`reports\summary-vus-<N>.json`**, график — **`reports\avg_vs_vus.png`**.

3. Вручную: несколько вызовов `k6 run` с разными `TARGET_VUS` и `--summary-export`, затем:

   ```text
   py plot_avg_vs_vus.py reports
   ```

Файлы в **`reports/`** и **`summary*.json`** в корне k6 в `.gitignore` — в git обычно не коммитят; в отчёт приложите **`avg_vs_vus.png`**.

---

## Шаг 5. Что коммитить в git

- **`zil/k6/rental-mixed.js`**
- **`zil/k6/plot_avg_vs_vus.py`**
- **`zil/k6/run-sweep.ps1`**
- **`zil/k6/README_LAB4_RU.md`**
- **`zil/k6/.gitkeep`** в `reports/` (по желанию) и **`zil/k6/.gitignore`**
- **`zil/documentation/LAB4_PLAN.md`**
- бэкенд **`GET /stats`**, если добавляли: **`zil/src/main/java/rental/controller/StatsController.java`**

---

## Частые проблемы

| Симптом | Действие |
|---------|----------|
| `connection refused` на 8083 | Не запущен Docker / приложение; освободить порт |
| Логика POST/GET | Правки в **`rental-mixed.js`**, `POST_SHARE` |
| `plot_avg_vs_vus.py` падает | `pip install matplotlib`; пересоберите JSON свежим **`k6 run`**, чтобы в summary были Trend-метрики |
| k6 не в PATH | Установка k6, перезапуск терминала |

---

## Ссылки

- [k6 docs](https://k6.io/docs/)
- [ramping-vus](https://k6.io/docs/using-k6/scenarios/executors/#ramping-vus)
- [HTTP requests](https://k6.io/docs/using-k6/http-requests/)
- [JSON summary](https://k6.io/docs/results-output/end-of-test/json-summary/)
