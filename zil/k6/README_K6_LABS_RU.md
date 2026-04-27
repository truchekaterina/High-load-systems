# k6 и отчёты: LAB4, LAB6, LAB8 — одна логика

Здесь сведено вместе, **что с чем стыкуется**, чтобы не путать папки с JSON, скрипты построения графиков и настройки `docker-compose`.

---

## 1. Общие правила

| Элемент | Правило |
| -------- | -------- |
| Имена метрик в k6 | Везде используются **`post_ms`** и **`get_ms`** (Trend в JS). Так **`plot_k6_reports.py`** и (на ветке LAB8) **`plot_lab8_reports.py`** читают один и тот же формат summary JSON. |
| Порт основного CRUD | По умолчанию **`8083`** (`BASE_URL` без туннеля: `http://<хост>:8083`). |
| Туннель с ПК | **`ssh -p <порт_ВМ> -L 8080:127.0.0.1:8083 ...`** → в браузере **`http://localhost:8080`**. |
| Лимит CPU контейнера `app` | На хосте перед `docker compose up`: **`export APP_CPUS=0.5`** (или `1.0`, и т.д.). См. комментарии в [`docker-compose.yml`](../docker-compose.yml). |

---

## 2. LAB4 — задержка от числа VU

| Что | Значение |
| ----- | -------- |
| Сценарий | [`load.js`](load.js) без `LAB6_CONST` (режим ramping-vus). |
| Обёртка (Windows) | [`run-lab4.ps1`](run-lab4.ps1) |
| Куда кладутся JSON | **`reports/summary-vus-<N>.json`** |
| График | `py plot_k6_reports.py` (без `--lab6`) → **`reports/avg_vs_vus.png`** |
| Ось X | **TARGET_VUS** |

Подробнее — [`README_LAB4_RU.md`](README_LAB4_RU.md).

---

## 3. LAB6 — время отклика от **CPU** (шаг 0.5), **VU = const**, смеси 5/95, 50/50, 95/5

| Что | Значение |
| ----- | -------- |
| Сценарий | [`load.js`](load.js) с **`LAB6_CONST=1`**, **`TARGET_VUS`**, **`POST_SHARE`**, **`DURATION`**. Endpoints: **`POST /clients`**, **`GET /stats`**. |
| Имена файлов отчётов | **`*cpu<NN>_mix<MM>.json`**, например `pc_cpu10_mix50.json`, `s2s_cpu05_mix05.json`. Здесь **`cpu05` → 0.5 ядра**, **`cpu10` → 1.0**, **`mix05`** ≈ сценарий 5/95 и т.д. |
| Папки | **`reports-lab6-pc`** (нагрузка с ПК через туннель или как задал курс), **`reports-lab6-s2s`** (нагрузка «сервер–сервер»). |
| График (формат ТЗ) | `py plot_k6_reports.py --lab6 [папка]` → **`lab6_latency_vs_cpu.png`** (три панели по смесям, по оси X — **CPU**). |
| Старый вид графиков | `py plot_k6_reports.py --lab6-legacy` — четыре отдельных PNG «смесь по оси X». |

Образ **`app`**: Harbor или **Docker Hub** через **`ZIL_APP_IMAGE`** — см. [LAB6_PLAN_RU §15](../documentation/LAB6_PLAN_RU.md).

---

## 4. LAB7 — та же нагрузка k6, другая БД

LAB7 **не меняет** формат отчётов k6 и скриптов LAB6: меняется только то, куда приложение подключается по JDBC (**удалённый PostgreSQL на `hl12.zil`**, переменные **`DBHOST`/`DBPORT`/`DBNAME`/`SCHEMANAME`**). После развёртывания LAB7 можно **повторить** те же прогоны LAB6 и положить JSON в те же структуры **`reports-lab6-*`**, если преподаватель просит сравнение до/после выноса БД.

**Compose:** на ветке **`lab7`** у сервиса **`app`** задан блок **`environment`** с **`DBHOST: hl12.zil`** и т.д.; локальный контейнер **`postgres`** в файле может оставаться для IDE, но рабочая цепочка LAB7 — приложение → **сеть** → БД на DB-ноде. Подробно — [LAB7_PLAN_RU.md](../documentation/LAB7_PLAN_RU.md).

---

## 5. LAB8 — Additional service на **8084**, графики «как LAB6», только CPU **0.5 и 1.0**

| Что | Значение |
| ----- | -------- |
| Ветка кода | Обычно **`lab8-ads`** (основной сервис + отдельный образ Additional). |
| Сценарий | **`load-lab8-s2s.js`** — бьёт в **`BASE_URL`** (по умолчанию **`http://localhost:8084`**): **`/additional/cars/availability`** → метрика **`post_ms`**, **`/additional/stats`** → **`get_ms`**. |
| Отчёты | Папка **`reports-lab8-s2s`**, имена вроде **`s2s_cpu05_mix05.json`**, **`s2s_cpu10_availability.json`** (только **0.5** и **1.0** CPU по ТЗ). |
| Графики | На ветке LAB8: **`plot_lab8_reports.py`** → **`lab8_availability_cpu_avg_p95.png`** (задержка vs CPU для availability) и опционально **`lab8_cpu_*_availability_stats.png`** (смеси на фиксированном CPU — вспомогательный вид). |

Образы **`app`** и **`additional`**: как в LAB6/LAB8-доке — **Harbor или Docker Hub**, переменные **`ZIL_APP_IMAGE`** / отдельный тег для additional.

Подробно — [LAB8_PLAN_RU.md](../documentation/LAB8_PLAN_RU.md).

---

## 6. Сводная таблица «лаба → файл → график»

| Лаба | Скрипт k6 | Папка JSON | Скрипт Python | Итоговый PNG (типично) |
| ---- | ----------- | ---------- | ------------- | ------------------------ |
| LAB4 | `load.js` | `reports/` | `plot_k6_reports.py` | `avg_vs_vus.png` |
| LAB6 | `load.js` + `LAB6_CONST=1` | `reports-lab6-pc`, `reports-lab6-s2s` | `plot_k6_reports.py --lab6` | `lab6_latency_vs_cpu.png` |
| LAB8 | `load-lab8-s2s.js` | `reports-lab8-s2s` | `plot_lab8_reports.py` | `lab8_availability_cpu_avg_p95.png`, … |

---

## 7. `docker-compose.yml` и лабы

| Лаба | База для `app` | Образ `app` |
| ---- | ---------------- | ------------- |
| LAB6 | Часто **локальный** сервис **`postgres`** в том же compose (`SPRING_DATASOURCE_*` на **`postgres:5432`**). | **`image:` + `ZIL_APP_IMAGE`** (Harbor или Docker Hub). |
| LAB7 | **Удалённая** БД: **`DBHOST`/`DBPORT`/`DBNAME`/`SCHEMANAME`** (см. **`application.properties`** на ветке **`lab7`**). Локальный `postgres` не обязателен для боевого сценария. | То же: сборка или **`ZIL_APP_IMAGE`**. |
| LAB8 | Как LAB7 к БД + второй сервис **additional** на **8084** (ветка **`lab8-ads`**). | Два образа в compose или два тега в Hub/Harbor. |

Если что-то из отчётов не строится — проверьте, что имена **`post_ms`/`get_ms`** в JSON есть и что имена файлов совпадают с regex в соответствующем `plot_*.py`.
