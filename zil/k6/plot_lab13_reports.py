# -*- coding: utf-8 -*-
"""
LAB13: графики по summary JSON k6 (прокси → Kafka).

Имена файлов: summary_CPU05_conc1.json, summary_CPU05_conc2.json, ...

Зависимости: matplotlib
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
except ImportError:
    print("Установите: pip install matplotlib", file=sys.stderr)
    sys.exit(1)

_NAME_RE = re.compile(r"summary_CPU(?P<cpu>\d+)_conc(?P<conc>\d+)\.json$", re.IGNORECASE)


def cpu_tag_to_float(tag: str) -> float:
    # 05 → 0.5, 10 → 1.0 (как в именах summary_CPU05_…)
    return int(tag, 10) / 10.0


def pick_duration_metric(metrics: dict) -> dict | None:
    for key, val in metrics.items():
        if key.startswith("http_req_duration"):
            return val if isinstance(val, dict) else None
    return None


def get_p95(metric: dict | None) -> float | None:
    if not metric:
        return None
    return metric.get("p(95)") if metric.get("p(95)") is not None else None


def get_avg(metric: dict | None) -> float | None:
    if not metric:
        return None
    return metric.get("avg") if metric.get("avg") is not None else None


def load_cell(path: Path) -> tuple[float, int, float | None, float | None]:
    m = _NAME_RE.search(path.name)
    if not m:
        raise ValueError(f"ожидалось имя summary_CPU{{05|10}}_conc{{1|2}}.json: {path.name}")
    cpu_f = cpu_tag_to_float(m.group("cpu"))
    conc = int(m.group("conc"), 10)
    data = json.loads(path.read_text(encoding="utf-8"))
    metrics = data.get("metrics") or {}
    dur = pick_duration_metric(metrics)
    return cpu_f, conc, get_p95(dur), get_avg(dur)


def main() -> int:
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent / "reports-lab13")
    if not out_dir.is_dir():
        print(f"Нет каталога: {out_dir}", file=sys.stderr)
        return 1

    cells: list[tuple[float, int, float | None, float | None]] = []
    for path in sorted(out_dir.glob("summary_CPU*_conc*.json")):
        try:
            cells.append(load_cell(path))
        except (ValueError, json.JSONDecodeError, OSError) as ex:
            print(f"пропуск {path}: {ex}", file=sys.stderr)

    if not cells:
        print(f"В {out_dir} нет summary_CPU*_conc*.json", file=sys.stderr)
        return 1

    by_conc: dict[int, list[tuple[float, float]]] = {1: [], 2: []}
    avg_by_conc: dict[int, list[tuple[float, float]]] = {1: [], 2: []}
    for cpu_f, conc, p95, avg in sorted(cells, key=lambda x: (x[0], x[1])):
        if p95 is not None:
            by_conc.setdefault(conc, []).append((cpu_f, p95))
        if avg is not None:
            avg_by_conc.setdefault(conc, []).append((cpu_f, avg))

    fig, ax = plt.subplots(figsize=(8, 4.5))
    for conc, series in sorted(by_conc.items()):
        if series:
            xs = [x[0] for x in series]
            ys = [x[1] for x in series]
            ax.plot(xs, ys, marker="o", label=f"p(95), concurrency={conc}")

    ax.set_xlabel("CPU limit (app + additional)")
    ax.set_ylabel("http_req_duration (ms)")
    ax.set_title("LAB13 — латентность POST к прокси (через k6 summary)")
    ax.legend()
    ax.grid(True, alpha=0.3)
    png = out_dir / "lab13_latency_p95_vs_cpu.png"
    fig.tight_layout()
    fig.savefig(png, dpi=120)
    print(f"PNG: {png}")

    fig2, ax2 = plt.subplots(figsize=(8, 4.5))
    for conc, series in sorted(avg_by_conc.items()):
        if series:
            xs = [x[0] for x in series]
            ys = [x[1] for x in series]
            ax2.plot(xs, ys, marker="s", label=f"avg, concurrency={conc}")
    ax2.set_xlabel("CPU limit (app + additional)")
    ax2.set_ylabel("http_req_duration (ms)")
    ax2.set_title("LAB13 — средняя латентность POST к прокси")
    ax2.legend()
    ax2.grid(True, alpha=0.3)
    png2 = out_dir / "lab13_latency_avg_vs_cpu.png"
    fig2.tight_layout()
    fig2.savefig(png2, dpi=120)
    print(f"PNG: {png2}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
