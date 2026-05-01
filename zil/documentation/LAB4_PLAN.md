# LAB4 — k6: пошагово под ТЗ (проект `zil`, Windows)

В папке **`zil/k6`**: **`load.js`** (сценарий k6), **`run-lab4.ps1`** (несколько прогонов k6 + вызов графика), **`plot_k6_reports.py`** (построение `avg_vs_vus.png` из json; комментарии в скрипте — по-русски). Подробно для «с нуля» — **[`k6/README_LAB4_RU.md`](../k6/README_LAB4_RU.md)**.

Порт API: **8083**. k6: [установка](https://k6.io/docs/get-started/installation/).

---

## Смысл лабы

**k6** зовёт REST API с разным числом **VU** (виртуальных пользователей). Смотрите **среднее время ответа** и стройте **график (avg) от VU** — в проекте это делает **`run-lab4.ps1`**: пишет `reports/summary-vus-*.json`, рисует `reports/avg_vs_vus.png`. В **load.js** две **Trend**-метрики: **`post_ms`**, **`get_ms`**.

---

## Требования из методички (чеклист)

| Требование | Как закрываем |
|------------|----------------|
| Развернуть k6 | `k6 version` в PowerShell |
| `ramping-vus`, `k6/http` | **`load.js`** (два сценария) |
| POST простой сущности | **POST /clients** |
| GET со статистикой | **GET /stats** |
| ~50/50 | **`POST_SHARE=0.5`**, пулы `vuForPost` / `vuForGet` в **`load.js`** |
| График avg vs VU, 4–5 точек, 2 линии | **`.\run-lab4.ps1`** (json + PNG) |
| Git | **`load.js`**, **`run-lab4.ps1`**, опционально **`README_LAB4_RU.md`**, **`.gitignore`**, **`reports/.gitkeep`** |

---

## Шаг 0. Поднять сервис

```text
cd zil
docker compose --profile local-db up --build -d
```

---

## Шаг 1. Один прогон

```text
cd zil\k6
k6 run load.js
```

С отчётом:

```text
$env:TARGET_VUS = "40"
k6 run --summary-export reports\summary-vus-40.json load.js
```

---

## Шаг 2. Серия точек + график

```text
cd zil\k6
py -m pip install matplotlib
.\run-lab4.ps1
```

См. **`k6/README_LAB4_RU.md`** (переменные `VUS_LIST`, `NO_PLOT`, `NO_CLEAN`, `BASE_URL`).

---

## Шаг 3. (опционально) Добавить GET /cars

В функции `doGet` или отдельным сценарием: `http.get(\`${baseUrl}/cars\`)` — если требуется нагрузить «таблицу».

---

## Что коммитить

- `zil/k6/load.js`
- `zil/k6/run-lab4.ps1`
- `zil/k6/README_LAB4_RU.md`, `zil/k6/.gitignore`, `zil/k6/reports/.gitkeep`
- `zil/documentation/LAB4_PLAN.md` (по желанию)

---

## Проблемы

| Симптом | Действие |
|---------|----------|
| Нет графика | `pip install matplotlib`, не ставь `NO_PLOT=1` |
| Нет метрик в json | прогоняй через **`load.js`**, в нём заданы `post_ms` / `get_ms` |
| 8083 занят | останови второй процесс (IDE / контейнер) |

## Ссылки

- [k6](https://k6.io/docs/) · [ramping-vus](https://k6.io/docs/using-k6/scenarios/executors/#ramping-vus) · [JSON summary](https://k6.io/docs/results-output/end-of-test/json-summary/)
