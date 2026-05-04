# k6 и отчёты: LAB6, LAB7, LAB8, LAB9

Краткая карта: какие скрипты и папки относятся к нагрузочным лабам после выноса стенда на ВМ и удалённую БД.

---

## 1. Общие правила

| Элемент | Правило |
| -------- | -------- |
| Имена метрик в k6 | Везде используются **`post_ms`** и **`get_ms`** (Trend в JS). Так **`plot_k6_reports.py`** и **`plot_lab8_reports.py`** читают один и тот же формат summary JSON. |
| Порт основного сервиса **`app`** | По умолчанию **`8083`** (`BASE_URL`: `http://<хост>:8083`). Для LAB8 сценарий против **additional** часто смотрит на **`8084`** — см. ниже. |
| Туннель с ПК | **`ssh -p <порт_ВМ> -L 8080:127.0.0.1:8083 ...`** → в браузере **`http://localhost:8080`**. |
| Лимит CPU контейнера `app` | Перед **`docker compose --env-file … up`**: **`export APP_CPUS=0.5`** (или `1.0`). См. [`docker-compose.yml`](../docker-compose.yml). |

Сценарий **`load.js`** без `LAB6_CONST` (ось X — число VU, ramping) используется в ранних этапах курса; подробности — в **`zil/k6/README_LAB4_RU.md`**.

---

## 2. LAB6 — время отклика от **CPU** (шаг 0.5), **VU = const**, смеси 5/95, 50/50, 95/5

| Что | Значение |
| ----- | -------- |
| Сценарий | [`load.js`](../k6/load.js) с **`LAB6_CONST=1`**, **`TARGET_VUS`**, **`POST_SHARE`**, **`DURATION`**. Endpoints: **`POST /clients`**, **`GET /stats`**. |
| Имена файлов отчётов | **`*cpu<NN>_mix<MM>.json`**, например `pc_cpu10_mix50.json`. **`cpu05` → 0.5 ядра**, **`cpu10` → 1.0**. |
| Папки | **`reports-lab6-pc`**, **`reports-lab6-s2s`**. |
| График | `py plot_k6_reports.py --lab6 [папка]` → **`lab6_latency_vs_cpu.png`**. |
| Старый вид | `py plot_k6_reports.py --lab6-legacy`. |

Образ **`app`**: **`ZIL_APP_IMAGE`** — см. [LAB6_PLAN_RU.md](LAB6_PLAN_RU.md).

---

## 3. LAB7 — та же нагрузка k6, удалённая БД

Меняется только JDBC (**`DBHOST`**, **`DBPORT`**, **`DBNAME`**, **`SCHEMANAME`**, учётка приложения — обычно **`registry-tags-lab8-hl7.env`**). Формат отчётов LAB6 можно **повторить** для сравнения «до/после» выноса PostgreSQL.

Подробно по повторному сиды / pgAdmin — [LAB7_REPEAT_MANUAL_PGADMIN_SEED_K6_RU.md](LAB7_REPEAT_MANUAL_PGADMIN_SEED_K6_RU.md).

---

## 4. LAB8 — Additional на **8084**

| Что | Значение |
| ----- | -------- |
| Сценарий | **`load-lab8-s2s.js`**, **`BASE_URL`** по умолчанию **`http://localhost:8084`**. |
| Отчёты | **`reports-lab8-s2s`**, имена вроде **`s2s_cpu05_mix05.json`**. |
| Графики | **`plot_lab8_reports.py`** → **`lab8_latency_vs_cpu.png`** (+ при наличии данных **`lab8_availability_cpu_avg_p95.png`**). |

Образы **`ZIL_APP_IMAGE`**, **`ZIL_ADDITIONAL_IMAGE`** — [LAB8_PLAN_RU.md](LAB8_PLAN_RU.md).

---

## 5. LAB9 — наблюдаемость в приложениях, тот же k6 против **8084**

**Сценарий и метрики** те же, что в LAB8: **`load-lab8-s2s.js`**, тренды **`post_ms`** / **`get_ms`**.

| Что | Значение |
| ----- | -------- |
| Сценарий | **`load-lab8-s2s.js`**, **`BASE_URL`** — IP узла на **8084** (часто **hl07** или **hl13**, если добав. сервис там). CPU: **`APP_CPUS`** (на узле **`app`**), **`ADDITIONAL_CPUS`** (на узле **`additional`**) — см. [LAB9_MANUAL_FULL_RU.md](LAB9_MANUAL_FULL_RU.md), **части 3А и 8**. |
| Отчёты | Удобно отдельная папка **`reports-lab9-s2s`**, имена по аналогии LAB8 (`s2s_cpu05_*.json`, `s2s_cpu10_*.json`). |
| Логи | **`docker compose … logs app additional`** — сводки **`ObservabilityService`**. |
| Графики | Обычно тот же **`plot_lab8_reports.py`** (те же поля в summary JSON). |

---

## 6. Сводная таблица

| Лаба | Скрипт k6 | Папка JSON | Python | Типичный PNG |
| ---- | ----------- | ---------- | ------ | ------------- |
| LAB6 | `load.js` + `LAB6_CONST=1` | `reports-lab6-pc`, `reports-lab6-s2s` | `plot_k6_reports.py --lab6` | `lab6_latency_vs_cpu.png` |
| LAB8 | `load-lab8-s2s.js` | `reports-lab8-s2s` | `plot_lab8_reports.py` | `lab8_latency_vs_cpu.png` |
| LAB9 | `load-lab8-s2s.js` | `reports-lab9-s2s` (реком.) | `plot_lab8_reports.py` | см. LAB8 PNG / свой префикс |

---

## 7. `docker-compose.yml` и лабы

В актуальном репозитории **локального `postgres` в compose нет**: сервис **`app`** (и **`additional`** в LAB8) получает переменные через **`--env-file`** (см. шапку файла).

| Лаба | База для `app` | Образы |
| ---- | ---------------- | ------ |
| LAB6 | Удалённая БД по env (как в **`registry-tags-*`**) | **`ZIL_APP_IMAGE`** |
| LAB7 | То же; выделенный узел БД (**hl12** и т.п.) | То же |
| LAB8 | То же + второй сервис **`additional`** (**8084**) | **`ZIL_APP_IMAGE`**, **`ZIL_ADDITIONAL_IMAGE`** |
| LAB9 | То же, образы со встроенной наблюдаемостью LAB9 | **`ZIL_APP_IMAGE`**, **`ZIL_ADDITIONAL_IMAGE`** |

Если график не строится — проверьте наличие **`post_ms`/`get_ms`** в JSON и совпадение имён файлов с regex в `plot_*.py`.
