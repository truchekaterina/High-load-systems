# LAB4 — k6 (Windows, PowerShell)

Скрипты в **`zil\k6`**: один сценарий **`rental-mixed.js`** (два параллельных пула: `POST /clients` и `GET /stats`), свип точек VU — **`run-sweep.ps1`**, график **avg** по двум линиям — **`plot_avg_vs_vus.py`**.

API по умолчанию: `http://localhost:8083`. Подробный план по смыслу задания: **`zil/documentation/LAB4_PLAN.md`**.

---

## 1. Что установить

1. **k6** — в PowerShell, например:
   - `winget install grafana.k6`, **или**
   - установщик с [k6 — Installation](https://k6.io/docs/get-started/installation/) (Windows).
2. **Python 3** + matplotlib для графика:
   - `py -m pip install matplotlib`  
   (или `python -m pip install matplotlib`, если в PATH только `python`).

Проверка: `k6 version`, `py --version` или `python --version`.

---

## 2. Поднять бэкенд

Из папки **`zil`** (Docker):

```powershell
cd <корень_репозитория>\zil
docker compose up --build -d
```

Проверка: `Invoke-RestMethod http://localhost:8083/cars` и `Invoke-RestMethod http://localhost:8083/stats`.

Перед нагрузкой **не держите** второй экземпляр приложения на **8083** (например Run из IDE вместе с `zil-app` в compose).

---

## 3. Один прогон k6

В **PowerShell**:

```powershell
cd zil\k6
k6 run rental-mixed.js
```

С **числом VU** и отчётом (метрики Trend: `k6_post_clients_ms`, `k6_get_stats_ms`):

```powershell
$env:TARGET_VUS = "40"
$env:POST_SHARE = "0.5"   # доля VU на POST, остальное на GET
k6 run --summary-export reports\summary-vus-40.json rental-mixed.js
```

Переменные можно задавать и через `-e`: `k6 run -e TARGET_VUS=40 -e POST_SHARE=0.5 --summary-export reports\summary-vus-40.json rental-mixed.js`.

---

## 4. Серия точек + PNG (как у коллеги)

Скрипт по умолчанию гоняет VU: **10, 20, 40, 80, 160**, пишет `reports\summary-vus-*.json`, затем строит **`reports\avg_vs_vus.png`**.

```powershell
cd zil\k6
.\run-sweep.ps1
```

Опции через переменные среды:

| Переменная | Назначение |
|------------|------------|
| `BASE_URL` | База API (по умолчанию `http://localhost:8083`) |
| `POST_SHARE` | Доля VU на POST, `0..1` (по умолчанию `0.5`) |
| `VUS_LIST` | Свои точки, через пробел, например `"5 10 20 40"` |
| `NO_PLOT=1` | Только JSON, без вызова Python |
| `NO_CLEAN=1` | Не удалять старые `summary-vus-*.json` и `avg_vs_vus.png` в `reports\` перед прогоном |

Пример:

```powershell
$env:VUS_LIST = "5 10 20 40 80"
$env:BASE_URL = "http://localhost:8083"
.\run-sweep.ps1
```

Только перерисовать график по уже снятым JSON:

```powershell
cd zil\k6
py plot_avg_vs_vus.py reports
```

(или `python plot_avg_vs_vus.py reports`.)

---

## 5. Что лежит в репозитории

- `rental-mixed.js` — сценарий k6 (ramping-vus, два сценария, Trend для графика).
- `run-sweep.ps1` — цикл прогонов + вызов `plot_avg_vs_vus.py`.
- `plot_avg_vs_vus.py` — две кривые (POST / GET) по `reports\summary-vus-<N>.json`.
- `reports\.gitkeep` — чтобы папка `reports` существовала; сами JSON/PNG в git обычно не кладут (см. `k6/.gitignore`).

---

## 6. Типичные проблемы

| Симптом | Что сделать |
|---------|-------------|
| `k6` не найден | Установить k6, перезапустить терминал, проверить PATH. |
| `connection refused` / 8083 | Поднять `docker compose`, проверить, что порт не занят другим процессом. |
| Нет графика | Установить Python + `matplotlib`; при `NO_PLOT=1` график не строится. |
| Старые точки в PNG | `NO_CLEAN=1` или вручную очистить `reports\` и снова `.\run-sweep.ps1`. |
