# -*- coding: utf-8 -*-
"""
LAB8: графики по summary JSON k6 для Additional service S2S.

По умолчанию читает ./reports-lab8-s2s рядом со скриптом.
Можно передать каталог первым аргументом или через K6_LAB8_DIR.

Поддерживаемые файлы:
  *cpu05_availability.json, *cpu10_availability.json
    -> lab8_availability_cpu_avg_p95.png

  *cpu05_mix05.json, *cpu05_mix50.json, *cpu05_mix95.json
  *cpu10_mix05.json, *cpu10_mix50.json, *cpu10_mix95.json
    -> lab8_cpu_0.5_availability_stats.png
    -> lab8_cpu_1.0_availability_stats.png

Зависимости: python3 -m pip install matplotlib
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError:
    print("Python:", sys.executable, file=sys.stderr)
    print("Установите зависимость: python3 -m pip install matplotlib", file=sys.stderr)
    print("На Windows также можно: py -m pip install matplotlib", file=sys.stderr)
    sys.exit(1)


CPU_STEPS: tuple[float, ...] = (0.5, 1.0)
MIX_ORDER: tuple[str, ...] = ("05", "50", "95")
MIX_TICK: dict[str, str] = {
    "05": "5% stats",
    "50": "50% stats",
    "95": "95% stats",
}

_AVAILABILITY_NAME = re.compile(r"cpu(\d+)_availability\.json$", re.IGNORECASE)
_MIX_NAME = re.compile(r"cpu(\d+)_mix(\d+)\.json$", re.IGNORECASE)


def get_avg(metric: dict | None) -> float | None:
    """Достаёт avg из metric.values или из корня metric."""
    if not metric:
        return None
    values = metric.get("values")
    if isinstance(values, dict) and values.get("avg") is not None:
        return float(values["avg"])
    if metric.get("avg") is not None:
        return float(metric["avg"])
    return None


def get_p95(metric: dict | None) -> float | None:
    """Достаёт p(95) из metric.values или из корня metric."""
    if not metric:
        return None
    values = metric.get("values")
    if isinstance(values, dict) and values.get("p(95)") is not None:
        return float(values["p(95)"])
    if metric.get("p(95)") is not None:
        return float(metric["p(95)"])
    return None


def cpu_code_to_float(code: str) -> float:
    """05 -> 0.5, 10 -> 1.0."""
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


def plot_availability(root: Path) -> bool:
    points: dict[float, tuple[float, float]] = {}

    for path in sorted(root.glob("*.json")):
        match = _AVAILABILITY_NAME.search(path.name)
        if not match:
            continue

        cpu = cpu_code_to_float(match.group(1))
        if cpu not in CPU_STEPS:
            warn(f"{path.name}: CPU {cpu:g} пропущен, для LAB8 ожидаются только 0.5 и 1.0")
            continue

        metrics = read_metrics(path)
        post_ms = metrics.get("post_ms") or {}
        avg = get_avg(post_ms)
        p95 = get_p95(post_ms)
        if avg is None or p95 is None:
            warn(f"{path.name}: нет post_ms avg и/или p(95), файл пропущен")
            continue
        points[cpu] = (avg, p95)

    if not points:
        print(
            "Ошибка: не найдены файлы availability вида *cpu05_availability.json "
            "или *cpu10_availability.json с метрикой post_ms.",
            file=sys.stderr,
        )
        return False

    missing = [cpu for cpu in CPU_STEPS if cpu not in points]
    for cpu in missing:
        warn(f"нет availability-файла для CPU {cpu:g}")

    cpus = [cpu for cpu in CPU_STEPS if cpu in points]
    avg_values = [points[cpu][0] for cpu in cpus]
    p95_values = [points[cpu][1] for cpu in cpus]

    plt.figure(figsize=(8, 5))
    plt.plot(cpus, avg_values, "o-", color="#1f77b4", linewidth=2, markersize=7, label="post_ms avg")
    plt.plot(cpus, p95_values, "s-", color="#d62728", linewidth=2, markersize=7, label="post_ms p(95)")
    plt.xticks(cpus, [f"{cpu:g}" for cpu in cpus])
    plt.xlabel("CPU")
    plt.ylabel("Задержка availability (ms)")
    plt.title("LAB8: /additional/cars/availability по CPU")
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    out = root / "lab8_availability_cpu_avg_p95.png"
    plt.savefig(out, dpi=150)
    plt.close()
    print("Saved:", out)
    return True


def collect_mix(root: Path) -> dict[float, dict[str, tuple[float, float]]]:
    by_cpu: dict[float, dict[str, tuple[float, float]]] = {}

    for path in sorted(root.glob("*.json")):
        match = _MIX_NAME.search(path.name)
        if not match:
            continue

        cpu = cpu_code_to_float(match.group(1))
        mix = match.group(2)
        if cpu not in CPU_STEPS:
            warn(f"{path.name}: CPU {cpu:g} пропущен, для LAB8 ожидаются только 0.5 и 1.0")
            continue
        if mix not in MIX_ORDER:
            warn(f"{path.name}: неизвестный mix{mix}, ожидаются mix05/mix50/mix95")
            continue

        metrics = read_metrics(path)
        post_avg = get_avg(metrics.get("post_ms") or {})
        get_avg_value = get_avg(metrics.get("get_ms") or {})
        if post_avg is None or get_avg_value is None:
            warn(f"{path.name}: нет post_ms и/или get_ms avg, файл пропущен")
            continue

        by_cpu.setdefault(cpu, {})[mix] = (post_avg, get_avg_value)

    return by_cpu


def plot_mix(root: Path) -> None:
    by_cpu = collect_mix(root)
    if not by_cpu:
        warn("mix-файлы вида *cpu05_mix50.json не найдены; mix-графики не построены")
        return

    for cpu in CPU_STEPS:
        mixes = by_cpu.get(cpu, {})
        if not mixes:
            warn(f"нет mix-файлов для CPU {cpu:g}; график не построен")
            continue

        missing = [mix for mix in MIX_ORDER if mix not in mixes]
        for mix in missing:
            warn(f"нет mix{mix}-файла для CPU {cpu:g}")

        available_mix = [mix for mix in MIX_ORDER if mix in mixes]
        x = list(range(len(available_mix)))
        post_values = [mixes[mix][0] for mix in available_mix]
        get_values = [mixes[mix][1] for mix in available_mix]
        ticks = [MIX_TICK[mix] for mix in available_mix]

        plt.figure(figsize=(8, 5))
        plt.plot(
            x,
            post_values,
            "o-",
            color="#1f77b4",
            linewidth=2,
            markersize=7,
            label="availability post_ms avg",
        )
        plt.plot(
            x,
            get_values,
            "s-",
            color="#ff7f0e",
            linewidth=2,
            markersize=7,
            label="stats get_ms avg",
        )
        plt.xticks(x, ticks)
        plt.xlabel("Доля запросов /additional/stats")
        plt.ylabel("Средняя задержка (ms)")
        plt.title(f"LAB8: availability vs stats, CPU = {cpu:g}")
        plt.legend()
        plt.grid(True, alpha=0.3)
        plt.tight_layout()

        out = root / f"lab8_cpu_{cpu:.1f}_availability_stats.png"
        plt.savefig(out, dpi=150)
        plt.close()
        print("Saved:", out)


def main() -> int:
    here = Path(__file__).resolve().parent
    default_dir = here / "reports-lab8-s2s"

    parser = argparse.ArgumentParser(description="LAB8: графики по k6 summary JSON.")
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
        ok = plot_availability(root)
        plot_mix(root)
    except ValueError as exc:
        print(f"Ошибка: {exc}", file=sys.stderr)
        return 1

    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
