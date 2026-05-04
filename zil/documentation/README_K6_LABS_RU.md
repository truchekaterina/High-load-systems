# k6 и отчёты — LAB8 и LAB9 (Additional, **8084**)

Сценарии и папки для **LAB4–LAB7** при необходимости ищите в **других ветках** репозитория на GitHub.

---

## Общие правила

| Элемент | Значение |
| -------- | -------- |
| Метрики в k6 | **`post_ms`** и **`get_ms`** (Trend) — тот же формат, что читает **`plot_lab8_reports.py`**. |
| Порт **`app`** | **`8083`**. Для LAB8/LAB9 нагрузка идёт в **additional** — **`8084`**. |
| Лимиты CPU | Перед **`docker compose --env-file … up`**: **`APP_CPUS`**, **`ADDITIONAL_CPUS`** — см. [`docker-compose.yml`](../docker-compose.yml). |

---

## LAB8

| Что | Значение |
| ----- | -------- |
| Сценарий | [`k6/load-lab8-s2s.js`](../k6/load-lab8-s2s.js), **`BASE_URL`** на узел с **8084**. |
| JSON | **`zil/k6/reports-lab8-s2s`**, имена вроде **`s2s_cpu05_mix05.json`**. |
| Графики | `python3 plot_lab8_reports.py reports-lab8-s2s` → **`lab8_latency_vs_cpu.png`**, при наличии `*_availability.json` — **`lab8_availability_cpu_avg_p95.png`**. |

Подробнее — [LAB8_PLAN_RU.md](LAB8_PLAN_RU.md).

---

## LAB9

Тот же сценарий **`load-lab8-s2s.js`**, те же тренды. Отчёты удобно класть в **`reports-lab9-s2s`**; графики — тем же **`plot_lab8_reports.py`** (указать каталог с JSON).

Логи **`ObservabilityService`**, CPU, разнесённые ВМ — [LAB9_MANUAL_FULL_RU.md](LAB9_MANUAL_FULL_RU.md).

---

## Сводка

| Лаба | k6 | Папка JSON | График |
| ---- | ----- | ---------- | ------ |
| LAB8 | `load-lab8-s2s.js` | `reports-lab8-s2s` | `plot_lab8_reports.py` |
| LAB9 | `load-lab8-s2s.js` | `reports-lab9-s2s` (реком.) | `plot_lab8_reports.py` |

Если PNG не строится — проверьте **`post_ms`/`get_ms`** в JSON и шаблоны имён в [`plot_lab8_reports.py`](../k6/plot_lab8_reports.py).
