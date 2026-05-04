# -*- coding: utf-8 -*-
"""
LAB8: графики по summary JSON k6 (Additional service, server→server).

По умолчанию читает ./reports-lab8-s2s рядом со скриптом.
Можно передать каталог первым аргументом или через K6_LAB8_DIR.

Основной график (как в LAB6 по форме ТЗ): три панели по смесям 5/95, 50/50, 95/5,
ось X = CPU **только 0.5 и 1.0**, ось Y = avg для post_ms и get_ms.

  *cpu05_mix05.json … *cpu10_mix95.json  →  lab8_latency_vs_cpu.png

Дополнительно (если есть отдельные прогоны только availability):

  *cpu05_availability.json, *cpu10_availability.json  →  lab8_availability_cpu_avg_p95.png

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

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError:
    print("Python:", sys.executable, file=sys.stderr)
    print("Установите: py -m pip install matplotlib", file=sys.stderr)
    sys.exit(1)


# ТЗ LAB8: графики «как LAB6», но только эти два шага CPU (сервер–сервер).
CPU_STEPS: tuple[float, ...] = (0.5, 1.0)
MIX_ORDER: tuple[str, ...] = ("05", "50", "95")

_AVAILABILITY_NAME = re.compile(r"cpu(\d+)_availability\.json$", re.IGNORECASE)
_MIX_NAME = re.compile(r"cpu(\d+)_mix(\d+)\.json$", re.IGNORECASE)


def get_avg(metric: dict | None) -> float | None:
    if not metric:
        return None
    values = metric.get("values")
    if isinstance(values, dict) and values.get("avg") is not None:
        return float(values["avg"])
    if metric.get("avg") is not None:
        return float(metric["avg"])
    return None


def get_p95(metric: dict | None) -> float | None:
    if not metric:
        return None
    values = metric.get("values")
    if isinstance(values, dict) and values.get("p(95)") is not None:
        return float(values["p(95)"])
    if metric.get("p(95)") is not None:
        return float(metric["p(95)"])
    return None


def cpu_code_to_float(code: str) -> float:
    return int(code, 10) / 10.0


def read_metrics(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"не удалось прочитать JSON {path}: {exc}") from exc
    metrics = data.get("metrics")
    if not isinstance(metrics, dict):
        raise ValueError(f"в файле {path} нет объекта metrics")
    return metrics


def warn(message: str) -> None:
    print(f"Предупреждение: {message}", file=sys.stderr)


def collect_mix(root: Path) -> dict[float, dict[str, tuple[float, float]]]:
    """by_cpu[cpu][mix] = (post_avg, get_avg); только CPU 0.5 и 1.0."""
    by_cpu: dict[float, dict[str, tuple[float, float]]] = {}

    for path in sorted(root.glob("*.json")):
        match = _MIX_NAME.search(path.name)
        if not match:
            continue

        cpu = cpu_code_to_float(match.group(1))
        mix = match.group(2)
        if cpu not in CPU_STEPS:
            warn(f"{path.name}: CPU {cpu:g} пропущен (для LAB8 нужны только 0.5 и 1.0)")
            continue
        if mix not in MIX_ORDER:
            warn(f"{path.name}: неизвестный mix{mix}")
            continue

        metrics = read_metrics(path)
        post_avg = get_avg(metrics.get("post_ms") or {})
        get_avg_value = get_avg(metrics.get("get_ms") or {})
        if post_avg is None or get_avg_value is None:
            warn(f"{path.name}: нет post_ms и/или get_ms avg")
            continue

        by_cpu.setdefault(cpu, {})[mix] = (post_avg, get_avg_value)

    return by_cpu


def plot_lab8_like_lab6(root: Path) -> bool:
    """
    Тот же смысл, что график LAB6 «три панели по смесям, ось X = CPU»:
    три subplot по смесям, ось X = CPU (здесь только 0.5 и 1.0).
    Легенда — эндпоинты Additional (не /clients и /stats).
    """
    by_cpu = collect_mix(root)
    missing: list[tuple[float, str]] = []
    for cpu in CPU_STEPS:
        for mix in MIX_ORDER:
            if mix not in by_cpu.get(cpu, {}):
                missing.append((cpu, mix))

    if missing:
        print("LAB8: не хватает JSON для основного графика (нужны все пары CPU×mix):", file=sys.stderr)
        for cpu, mix in missing:
            print(f"  CPU {cpu:g}, mix {mix}", file=sys.stderr)
        print(
            "Ожидаются файлы вида *cpu05_mix50.json для cpu05/cpu10 и mix05/mix50/mix95.",
            file=sys.stderr,
        )
        return False

    mix_order = MIX_ORDER
    subtitles = (
        "write/read = 5/95",
        "write/read = 50/50",
        "write/read = 95/5",
    )
    xs = list(CPU_STEPS)

    fig, axes = plt.subplots(1, 3, figsize=(12, 5), sharey=True)
    fig.suptitle(
        "Avg response time (ms) vs CPU cores (LAB8 Additional, server→server)",
        fontsize=12,
        y=1.02,
    )

    for ax, mix, sub in zip(axes, mix_order, subtitles, strict=True):
        posts = [by_cpu[c][mix][0] for c in CPU_STEPS]
        gets = [by_cpu[c][mix][1] for c in CPU_STEPS]
        ax.plot(xs, posts, "o-", color="#1f77b4", linewidth=2, markersize=8)
        ax.plot(xs, gets, "o-", color="#ff7f0e", linewidth=2, markersize=8)
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
        Line2D(
            [0],
            [0],
            color="#1f77b4",
            marker="o",
            linestyle="-",
            linewidth=2,
            label="POST /additional/cars/availability",
        ),
        Line2D(
            [0],
            [0],
            color="#ff7f0e",
            marker="o",
            linestyle="-",
            linewidth=2,
            label="GET /additional/stats",
        ),
    ]
    fig.legend(
        handles=legend_elem,
        loc="upper center",
        ncol=1,
        bbox_to_anchor=(0.5, 1.12),
        frameon=False,
        fontsize=9,
    )
    fig.tight_layout()
    out = root / "lab8_latency_vs_cpu.png"
    plt.savefig(out, dpi=150, bbox_inches="tight")
    plt.close()
    print("Saved:", out)
    return True


def plot_availability(root: Path) -> bool:
    """Дополнительный график: только метрика post_ms (availability) vs CPU, avg и p95."""
    points: dict[float, tuple[float, float]] = {}

    for path in sorted(root.glob("*.json")):
        match = _AVAILABILITY_NAME.search(path.name)
        if not match:
            continue

        cpu = cpu_code_to_float(match.group(1))
        if cpu not in CPU_STEPS:
            warn(f"{path.name}: CPU {cpu:g} пропущен")
            continue

        metrics = read_metrics(path)
        post_ms = metrics.get("post_ms") or {}
        avg = get_avg(post_ms)
        p95 = get_p95(post_ms)
        if avg is None or p95 is None:
            warn(f"{path.name}: нет post_ms avg и/или p(95)")
            continue
        points[cpu] = (avg, p95)

    if not points:
        warn(
            "нет файлов *cpu05_availability.json / *cpu10_availability.json — "
            "пропускаем lab8_availability_cpu_avg_p95.png",
        )
        return True

    cpus = [c for c in CPU_STEPS if c in points]
    avg_values = [points[c][0] for c in cpus]
    p95_values = [points[c][1] for c in cpus]

    plt.figure(figsize=(8, 5))
    plt.plot(cpus, avg_values, "o-", color="#1f77b4", linewidth=2, markersize=7, label="post_ms avg")
    plt.plot(cpus, p95_values, "s-", color="#d62728", linewidth=2, markersize=7, label="post_ms p(95)")
    plt.xticks(cpus, [f"{c:g}" for c in cpus])
    plt.xlabel("CPU cores")
    plt.ylabel("Задержка availability (ms)")
    plt.title("LAB8: /additional/cars/availability по CPU (доп.)")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    out = root / "lab8_availability_cpu_avg_p95.png"
    plt.savefig(out, dpi=150)
    plt.close()
    print("Saved:", out)
    return True


def main() -> int:
    here = Path(__file__).resolve().parent
    default_dir = here / "reports-lab8-s2s"

    parser = argparse.ArgumentParser(description="LAB8: графики по k6 summary JSON (формат как LAB6).")
    parser.add_argument(
        "dir",
        nargs="?",
        default="",
        help="Папка с JSON (по умолчанию: K6_LAB8_DIR или ./reports-lab8-s2s)",
    )
    args = parser.parse_args()

    root = Path(args.dir) if args.dir else Path(os.environ.get("K6_LAB8_DIR", str(default_dir)))
    if not root.is_dir():
        print(f"Ошибка: нет папки с LAB8 отчётами: {root}", file=sys.stderr)
        return 1

    try:
        ok = plot_lab8_like_lab6(root)
        plot_availability(root)
    except ValueError as exc:
        print(f"Ошибка: {exc}", file=sys.stderr)
        return 1

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
