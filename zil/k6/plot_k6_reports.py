# -*- coding: utf-8 -*-
"""
LAB4: строит график средней задержки (POST /clients и GET /stats) по отчётам k6.

Откуда брать json:
  Переменная окружения K6_REPORTS_DIR — папка с файлами summary-vus-10.json, summary-vus-20.json, …
  Если не задана, используется подпапка ``reports`` рядом с этим скриптом (удобно запускать вручную из zil\\k6).

Зависимости: pip install matplotlib
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

# Рисуем без окна (подходит для сервера и для запуска из PowerShell без GUI).
try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError:
    print("Python:", sys.executable, file=sys.stderr)
    print("Установите: py -m pip install matplotlib", file=sys.stderr)
    sys.exit(1)


def get_avg(m: dict | None) -> float | None:
    """
    Достаёт среднее время (avg) из блока одной метрики в summary JSON k6.

    В разных версиях k6 поле может быть:
    - ``values.avg`` (типичный вариант);
    - либо ``avg`` в корне объекта метрики (старый вид).
    """
    if not m:
        return None
    val = m.get("values")
    if isinstance(val, dict) and val.get("avg") is not None:
        return float(val["avg"])
    if m.get("avg") is not None:
        return float(m["avg"])
    return None


def main() -> None:
    # Папка отчётов: из env (её задаёт run-lab4.ps1) или по умолчанию ./reports рядом со скриптом
    default_dir = Path(__file__).resolve().parent / "reports"
    root = Path(os.environ.get("K6_REPORTS_DIR", str(default_dir)))

    # Имя файла summary-vus-80.json: число — это TARGET_VUS того прогона
    name_pat = re.compile(r"^summary-vus-(\d+)\.json$")
    post_pts: list[tuple[int, float]] = []
    get_pts: list[tuple[int, float]] = []

    for f in sorted(root.glob("summary-vus-*.json")):
        m = name_pat.match(f.name)
        if not m:
            continue
        vus = int(m.group(1))
        data = json.loads(f.read_text(encoding="utf-8"))
        met = data.get("metrics") or {}
        # Имена post_ms и get_ms совпадают с Trend() в load.js
        a = get_avg(met.get("post_ms") or {})
        b = get_avg(met.get("get_ms") or {})
        if a is not None:
            post_pts.append((vus, a))
        if b is not None:
            get_pts.append((vus, b))

    if len(post_pts) < 1 or len(get_pts) < 1:
        print(
            "Нужны метрики post_ms и get_ms в JSON (запустите k6 с load.js и --summary-export).",
            file=sys.stderr,
        )
        sys.exit(1)

    post_pts.sort(key=lambda t: t[0])
    get_pts.sort(key=lambda t: t[0])
    vp = [a[0] for a in post_pts]
    yp = [a[1] for a in post_pts]
    vg = [a[0] for a in get_pts]
    yg = [a[1] for a in get_pts]

    plt.figure(figsize=(9, 5.5))
    # Две кривые: запись клиентов и чтение статистики
    plt.plot(vp, yp, "o-", label="POST /clients", color="#1f77b4", linewidth=2, markersize=7)
    plt.plot(vg, yg, "s-", label="GET /stats", color="#ff7f0e", linewidth=2, markersize=7)
    plt.legend()
    plt.xlabel("TARGET_VUS")
    plt.ylabel("Avg time (ms)")
    plt.title("k6: latency vs TARGET_VUS")
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    out = root / "avg_vs_vus.png"
    plt.savefig(out, dpi=150)
    print("Saved:", out)


if __name__ == "__main__":
    main()
