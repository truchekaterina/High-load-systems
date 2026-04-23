# LAB4: нагрузочное тестирование (k6) в проекте `zil` — пошагово

Эта папка (`zil/k6`) содержит сценарии [k6](https://k6.io/), скрипты прогонов и построения графиков. Ниже — **что за что отвечает** и **как запускать** на Windows и в Linux/macOS (Git Bash).

---

## 1. Что тестируется

Бэкенд (Spring Boot) на порту **8083** (см. `application.properties`):

| Метод | Путь        | Смысл в сценариях k6        |
|-------|------------|-----------------------------|
| POST  | `/clients` | создаётся клиент (запись в БД) |
| GET   | `/stats`   | чтение агрегированной статистики |

Сценарии **намеренно разделены** на два параллельных пула: один бьёт только в POST, второй — только в GET, чтобы на графике были **две линии** (средняя задержка POST vs GET).

---

## 2. Два «поколения» файлов (оба валидны)

### Вариант A — `load.js` + `sweep_plot.py` (как у вас было ранее)

- **`load.js`**: если **не** задан `TARGET_VUS` — сценарии с **ramping-vus** (фиксированные ступени).  
  Если задан `TARGET_VUS` — режим **constant-vu** на время `DURATION` (нужен для **одной точки** на графике «avg vs VU»).
- **`sweep_plot.py`**: в цикле вызывает `k6 run -e TARGET_VUS=... -e DURATION=... load.js`, пишет `summary-<N>.json` **в папку `k6`**, строит PNG (две линии по метрикам `post_req_duration` и `get_req_duration`).

**Когда удобно:** один Python-скрипт «всё в одном», контроль длительности `--duration` на точку.

### Вариант B — как у коллеги: `rental-mixed.js` + `reports/` + `plot_avg_vs_vus.py`

- **`rental-mixed.js`**: **всегда** `ramping-vus`; пик VU в каждом сценарии выводится из `TARGET_VUS` и `POST_SHARE` (см. комментарии в файле).  
  Метрики Trend: **`k6_post_clients_ms`**, **`k6_get_stats_ms`** (имена важны для JSON и графика).
- **`run-sweep.sh`** (Git Bash / Linux / macOS) или **`run-sweep.ps1`** (PowerShell): несколько прогонов, отчёты в **`k6/reports/summary-vus-<N>.json`**, затем (если не отключено) **`plot_avg_vs_vus.py`** → `reports/avg_vs_vus.png`.

**Когда удобно:** повторяемая структура «как в референсной лабе», отчёты лежат отдельно в `reports/`.

---

## 3. Переменные окружения (кратко)

| Переменная    | Где используется      | Смысл |
|---------------|------------------------|--------|
| `BASE_URL`    | оба варианта           | База API, по умолчанию `http://localhost:8083` |
| `TARGET_VUS`  | `load.js` (sweep), `rental-mixed.js` | Суммарное число VU для **разбиения** на пулы |
| `DURATION`    | только `load.js` + `sweep_plot.py` | Длительность **constant-vu** на одну точку (например `45s`) |
| `POST_SHARE`  | только `rental-mixed.js` | Доля VU на POST, `0..1` (по умолчанию `0.5`) |

**Разбиение VU (оба варианта с TARGET_VUS):** из суммы `targetVus` делается целочисленно, например при `0.5`: половина на POST, половина на GET (см. формулы в `rental-mixed.js` и раньше в `load.js`).

---

## 4. Пошагово: вариант B (коллега) на Windows

1. Поднять API и БД (например, из `zil`: `docker compose up -d` или только БД + `gradlew bootRun` на 8083).
2. Установить [k6](https://k6.io/docs/get-started/installation/) и убедиться, что `k6 version` в PATH.
3. В PowerShell:
   ```powershell
   cd C:\Users\1\Desktop\neurohelp\first_laba\zil\k6
   .\run-sweep.ps1
   ```
4. В каталоге `k6\reports\` появятся `summary-vus-10.json`, … и при установленном Python + matplotlib — `avg_vs_vus.png`.
5. Только график из уже готовых JSON (без k6):
   ```powershell
   python plot_avg_vs_vus.py .\reports
   ```

**Без графика:** `$env:NO_PLOT = "1"; .\run-sweep.ps1`  
**Не очищать reports перед прогоном:** `$env:NO_CLEAN = "1"; .\run-sweep.ps1`  
**Свой набор точек VU:** `$env:VUS_LIST = "5 10 20"; .\run-sweep.ps1`

---

## 5. Пошагово: вариант B в Git Bash (как `run-sweep.sh`)

```bash
cd zil/k6
chmod +x run-sweep.sh   # один раз, на Linux/macOS
./run-sweep.sh
```

Docker-k6: `USE_DOCKER_K6=1 ./run-sweep.sh` (на Linux к хосту: `BASE_URL=http://host.docker.internal:8083` при необходимости).

---

## 6. Пошагово: вариант A (Python `sweep_plot.py`)

```powershell
cd zil\k6
python sweep_plot.py
python sweep_plot.py --duration 30s --base-url http://localhost:8083
```

Только перерисовать график по уже снятым `summary-*.json`: `python sweep_plot.py --plot-only`

---

## 7. Как устроен `rental-mixed.js` (логика)

1. Считываются `BASE_URL`, `POST_SHARE`, `TARGET_VUS`.
2. Вычисляются **`postVuPool`** и **`getVuPool`** (целые, в сумме = `TARGET_VUS`).
3. Функция **`rampStages(peak)`** задаёт три фазы: разгон к `peak`, плато, сход к 0.
4. Два сценария **`ramping-vus`**: у каждого свой `peak` (размер пула) и своя `exec`-функция.
5. В `postClients` / `getStats` после запроса в **`Trend`** записывается `res.timings.duration` (мс) — эти имена метрик читает `plot_avg_vs_vus.py`.
6. `thresholds` ограничивает долю неуспешных HTTP-запросов (как в референсе у коллеги).

---

## 8. Как устроен `plot_avg_vs_vus.py`

1. Сканирует каталог (по умолчанию `k6/reports/`) на файлы `summary-vus-<число>.json`.
2. Для каждого файла пытается взять **средние** (`avg`) по `k6_post_clients_ms` и `k6_get_stats_ms`.
3. Если обе кривые доступны — рисует **две линии**; иначе fallback на старый агрегат **`http_req_duration`**, если накоплено ≥2 точек.

---

## 9. Git и артефакты

В `k6/.gitignore` обычно **не** коммитят тяжёлые/личные JSON и PNG в `reports/` (см. сам файл). Папка `reports/` в репозитории держится пустой через `.gitkeep`, чтобы путь существовал.

---

## 10. Частые проблемы

| Симптом | Что проверить |
|--------|----------------|
| `connection refused` | Запущено ли приложение на `BASE_URL` |
| 0 успешных checks | 404/500 на `/clients` или `/stats` — совпадают ли пути с `StatsController` |
| Пустой график / ошибка «нет avg» | Запускали ли k6 с тем же сценарием, что пишет нужные Trend-метрики |
| k6 не найден | Установка k6 или `USE_DOCKER_K6=1` в `run-sweep.sh` |

---

## 11. Сопоставление с коллегой (кино → аренда)

| Коллега (cinema)   | У вас (zil)        |
|--------------------|--------------------|
| `cinema-mixed.js`  | `rental-mixed.js`  |
| POST `/api/films`  | POST `/clients`    |
| GET tickets analytics | GET `/stats`   |
| `k6_post_film_ms`  | `k6_post_clients_ms` |
| `k6_get_analytics_ms` | `k6_get_stats_ms` |
| порт 8080          | 8083               |

Итог: **структура та же** (два пула, ramping, sweep, график), **пути и метрики** — под ваш REST.
