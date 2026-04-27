# -*- coding: utf-8 -*-
"""
k6: графики по summary JSON (экспорт --summary-trend-stats / стандартный summary).

LAB4 (по умолчанию)
  K6_REPORTS_DIR — папка с summary-vus-10.json, summary-vus-20.json, …
  (если нет: ./reports рядом со скриптом). Ось X: TARGET_VUS. Кривые: post_ms, get_ms.
  Файл: reports/avg_vs_vus.png

LAB6 (ТЗ: время отклика от числа CPU, шаг 0.5; const VU задаётся прогонами k6)
  py plot_k6_reports.py --lab6
  py plot_k6_reports.py --lab6 reports-lab6-s2s
  Имена JSON: *cpu<NN>_mix<MM>.json (напр. pc_cpu10_mix50.json)
  Выход: lab6_latency_vs_cpu.png — три subplot (5/95 | 50/50 | 95/5), ось X = CPU, Y = avg.

LAB6 — прежний вид (четыре PNG: фиксированный CPU, смесь по оси X): --lab6-legacy

Зависимости: pip install matplotlib
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

from matplotlib.lines import Line2D

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


_LAB6_NAME = re.compile(r"cpu(\d+)_mix(\d+)\.json$", re.IGNORECASE)
MIX_TICK: dict[str, str] = {
    "05": "5/95",
    "50": "50/50",
    "95": "95/5",
}
CPU_STEPS: tuple[float, ...] = (0.5, 1.0, 1.5, 2.0)


def cpu_code_to_float(c: str) -> float:
    """05→0.5, 10→1.0, 15→1.5, 20→2.0 (как в именах pc_cpu10_…)."""
    return int(c, 10) / 10.0


def _load_lab6_matrix(root: Path) -> dict[float, dict[str, tuple[float, float]]]:
    """by_cpu[cpu][mix] = (post_avg, get_avg)."""
    by_cpu: dict[float, dict[str, tuple[float, float]]] = {}
    for f in root.glob("*.json"):
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
    return by_cpu


def _ensure_lab6_complete(
    by_cpu: dict[float, dict[str, tuple[float, float]]],
    root: Path,
) -> None:
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


def plot_lab6_cpu_axis(root: Path, title_suffix: str = "") -> None:
    """Ось X = CPU; три панели по смесям write/read (формулировка ТЗ LAB6)."""
    by_cpu = _load_lab6_matrix(root)
    _ensure_lab6_complete(by_cpu, root)

    mix_order = ("05", "50", "95")
    subtitles = (
        "write/read = 5/95",
        "write/read = 50/50",
        "write/read = 95/5",
    )
    xs = list(CPU_STEPS)

    fig, axes = plt.subplots(1, 3, figsize=(14, 5), sharey=True)
    supt = "Avg response time (ms) vs CPU cores"
    if title_suffix:
        supt += f" ({title_suffix})"
    fig.suptitle(supt, fontsize=12, y=1.02)

    for ax, mix, sub in zip(axes, mix_order, subtitles, strict=True):
        posts = [by_cpu[c][mix][0] for c in CPU_STEPS]
        gets = [by_cpu[c][mix][1] for c in CPU_STEPS]
        ax.plot(xs, posts, "o-", color="#1f77b4", linewidth=2, markersize=7)
        ax.plot(xs, gets, "o-", color="#ff7f0e", linewidth=2, markersize=7)
        for x, p in zip(xs, posts, strict=True):
            ax.annotate(
                f"{p:.1f}",
                (x, p),
                textcoords="offset points",
                xytext=(0, 8),
                ha="center",
                fontsize=8,
            )
        for x, g in zip(xs, gets, strict=True):
            ax.annotate(
                f"{g:.1f}",
                (x, g),
                textcoords="offset points",
                xytext=(0, -14),
                ha="center",
                fontsize=8,
                color="#555555",
            )
        ax.set_xticks(xs)
        ax.set_xlabel("CPU cores")
        ax.set_title(sub, fontsize=10)
        ax.grid(True, linestyle=":", alpha=0.55)

    axes[0].set_ylabel("Avg response time (ms)")
    legend_elem = [
        Line2D([0], [0], color="#1f77b4", marker="o", linestyle="-", linewidth=2, label="POST /clients"),
        Line2D([0], [0], color="#ff7f0e", marker="o", linestyle="-", linewidth=2, label="GET /stats"),
    ]
    fig.legend(
        handles=legend_elem,
        loc="upper center",
        ncol=2,
        bbox_to_anchor=(0.5, 1.08),
        frameon=False,
    )
    fig.tight_layout()
    out = root / "lab6_latency_vs_cpu.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    plt.close()
    print("Saved:", out)


def plot_lab6_legacy(root: Path) -> None:
    """Четыре PNG: фиксированный CPU, по оси X три смеси (старый вид отчёта)."""
    by_cpu = _load_lab6_matrix(root)
    _ensure_lab6_complete(by_cpu, root)

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
        help="LAB6 (ТЗ): ось X = CPU, три панели → lab6_latency_vs_cpu.png",
    )
    ap.add_argument(
        "--lab6-legacy",
        action="store_true",
        help="LAB6 старый вид: 4 PNG по CPU",
    )
    ap.add_argument(
        "--title-suffix",
        default="",
        help="Подзаголовок к фигуре LAB6 (напр. pc / s2s)",
    )
    ap.add_argument(
        "dir",
        nargs="?",
        default="",
        help="Папка с JSON (по умолчанию reports или reports-lab6-pc)",
    )
    args = ap.parse_args()

    if args.lab6 or args.lab6_legacy:
        default_l6 = here / "reports-lab6-pc"
        root = Path(args.dir) if args.dir else Path(
            os.environ.get("K6_LAB6_DIR", str(default_l6))
        )
        if not root.is_dir():
            print("Нет папки:", root, file=sys.stderr)
            sys.exit(1)
        suffix = args.title_suffix.strip()
        if not suffix:
            if "reports-lab6-pc" in root.parts:
                suffix = "local PC → server"
            elif "reports-lab6-s2s" in root.parts:
                suffix = "server → server"
        if args.lab6_legacy:
            plot_lab6_legacy(root)
        else:
            plot_lab6_cpu_axis(root, title_suffix=suffix)
        return

    default_dir = here / "reports"
    root = Path(args.dir) if args.dir else Path(
        os.environ.get("K6_REPORTS_DIR", str(default_dir))
    )

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
