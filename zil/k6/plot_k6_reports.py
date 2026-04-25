# -*- coding: utf-8 -*-
"""
k6: графики по summary JSON (экспорт --summary-trend-stats / стандартный summary).

LAB4 (по умолчанию)
  K6_REPORTS_DIR — папка с summary-vus-10.json, summary-vus-20.json, …
  (если нет: ./reports рядом со скриптом). Ось X: TARGET_VUS. Кривые: post_ms, get_ms.
  Файл: reports/avg_vs_vus.png

LAB6
  Команда:  py plot_k6_reports.py --lab6
  Каталог:  K6_LAB6_DIR или ./reports-lab6-pc рядом со скриптом.
  Имена:    *cpu<NN>_mix<MM>.json, например pc_cpu10_mix50.json
            cpu05 → 0.5, cpu10 → 1.0, …; mix05 / mix50 / mix95 — три сценария POST/GET.
  Файлы:    четыре графика — по одному на фиксированный CPU (0.5, 1.0, 1.5, 2.0):
            lab6_cpu_0.5_post_get.png … lab6_cpu_2.0_post_get.png
            Ось X — три смеси POST/GET; две линии: Trend post_ms (POST /clients), get_ms (GET /stats).

Зависимости: pip install matplotlib
"""

from __future__ import annotations

import argparse
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


def get_p95(m: dict | None) -> float | None:
    """p(95) из summary k6: ``values`` или корень, ключ ``p(95)``."""
    if not m:
        return None
    val = m.get("values")
    if isinstance(val, dict) and val.get("p(95)") is not None:
        return float(val["p(95)"])
    if m.get("p(95)") is not None:
        return float(m["p(95)"])
    return None


# cpu05|cpu10|… -> 0.5, 1.0, …; mix05|50|95 -> подписи смеси POST/GET
_LAB6_NAME = re.compile(r"cpu(\d+)_mix(\d+)\.json$", re.IGNORECASE)
MIX_LABELS: dict[str, str] = {
    "05": "5% POST / 95% GET",
    "50": "50% / 50%",
    "95": "95% POST / 5% GET",
}
MIX_TICK: dict[str, str] = {
    "05": "5/95",
    "50": "50/50",
    "95": "95/5",
}
CPU_STEPS: tuple[float, ...] = (0.5, 1.0, 1.5, 2.0)


def cpu_code_to_float(c: str) -> float:
    """05→0.5, 10→1.0, 15→1.5, 20→2.0 (как в именах pc_cpu10_…)."""
    return int(c, 10) / 10.0


def plot_lab6(root: Path) -> None:
    files = list(root.glob("*.json"))
    # mix -> (post_avg, get_avg) — по одной линии на POST и на GET
    by_cpu: dict[float, dict[str, tuple[float, float]]] = {}
    for f in files:
        m = _LAB6_NAME.search(f.name)
        if not m:
            continue
        cpu_key, mix_key = m.group(1), m.group(2)
        if mix_key not in ("05", "50", "95"):
            continue
        data = json.loads(f.read_text(encoding="utf-8"))
        met = data.get("metrics") or {}
        pa = get_avg(met.get("post_ms") or {})
        ga = get_avg(met.get("get_ms") or {})
        if pa is None or ga is None:
            print(
                "Нет post_ms и/или get_ms (avg) в",
                f,
                "(нужен load.js с Trend post_ms/get_ms в LAB6).",
                file=sys.stderr,
            )
            continue
        cpu = cpu_code_to_float(cpu_key)
        by_cpu.setdefault(cpu, {})[mix_key] = (pa, ga)

    if len(by_cpu) < 1:
        print(
            "LAB6: не найдено файлов вида *cpu10_mix50.json в",
            root,
            file=sys.stderr,
        )
        sys.exit(1)

    missing: list[tuple[float, str]] = []
    for cpu in CPU_STEPS:
        mixes = by_cpu.get(cpu, {})
        for mix in ("05", "50", "95"):
            if mix not in mixes:
                missing.append((cpu, mix))
    if missing:
        print("LAB6: не хватает ожидаемых файлов:", file=sys.stderr)
        for cpu, mix in missing:
            print(f"  CPU {cpu:g}, mix {mix}", file=sys.stderr)
        print("Ожидаются файлы вида *cpu10_mix50.json для всех CPU и mix.", file=sys.stderr)
        sys.exit(1)

    for cpu in CPU_STEPS:
        mixes = by_cpu[cpu]
        post_avgs: list[float] = []
        get_avgs: list[float] = []
        ticks: list[str] = []
        for mix in ("05", "50", "95"):
            row = mixes[mix]
            ticks.append(MIX_TICK.get(mix, mix))
            post_avgs.append(row[0])
            get_avgs.append(row[1])

        x = [0, 1, 2]
        plt.figure(figsize=(8, 5))
        plt.plot(
            x,
            post_avgs,
            "o-",
            color="#1f77b4",
            linewidth=2,
            markersize=8,
            label="POST /clients (post_ms avg)",
        )
        plt.plot(
            x,
            get_avgs,
            "s-",
            color="#ff7f0e",
            linewidth=2,
            markersize=7,
            label="GET /stats (get_ms avg)",
        )
        plt.xticks(x, ticks)
        plt.xlabel("Смесь POST/GET")
        plt.ylabel("Средняя задержка (ms)")
        plt.title(f"LAB6: POST vs GET, CPU = {cpu:g} (k6 Trend, avg)")
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()
        fname = f"lab6_cpu_{cpu:.1f}_post_get.png"
        out = root / fname
        plt.savefig(out, dpi=150)
        plt.close()
        print("Saved:", out)


def main() -> None:
    here = Path(__file__).resolve().parent
    ap = argparse.ArgumentParser(description="Графики по k6 summary JSON (LAB4 или LAB6).")
    ap.add_argument(
        "--lab6",
        action="store_true",
        help="Режим LAB6: *cpuNN_mixMM.json, 4 графика по CPU (0.5–2.0), смеси на оси X",
    )
    ap.add_argument(
        "dir",
        nargs="?",
        default="",
        help="Папка с JSON (по умолчанию: из env или reports / reports-lab6-pc)",
    )
    args = ap.parse_args()

    if args.lab6:
        default_l6 = here / "reports-lab6-pc"
        root = Path(args.dir) if args.dir else Path(
            os.environ.get("K6_LAB6_DIR", str(default_l6))
        )
        if not root.is_dir():
            print("Нет папки:", root, file=sys.stderr)
            sys.exit(1)
        plot_lab6(root)
        return

    # LAB4: из env (run-lab4.ps1) или ./reports
    default_dir = here / "reports"
    root = Path(args.dir) if args.dir else Path(
        os.environ.get("K6_REPORTS_DIR", str(default_dir))
    )

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
