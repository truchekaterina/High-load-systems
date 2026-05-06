# -*- coding: utf-8 -*-
"""
LAB13: графики по summary JSON k6 (прокси → Kafka + опциональный GET /additional/stats).

1) LAB8-стиль: три панели по смесям STATS_SHARE (05 / 50 / 95), ось X = CPU 0.5 и 1.0,
   две линии — Trend post_ms (POST к прокси) и get_ms (GET stats).
   Файлы: summary_CPU05_conc2_mix50.json и т.д.

2) Устаревший режим (без *_mix* в имени): две картинки p95/avg по concurrency.

Зависимости: matplotlib
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.lines import Line2D
except ImportError:
    print("Установите: pip install matplotlib", file=sys.stderr)
    sys.exit(1)

CPU_STEPS: tuple[float, ...] = (0.5, 1.0)
MIX_ORDER: tuple[str, ...] = ("05", "50", "95")

_LEGACY_NAME_RE = re.compile(
    r"^summary_CPU(?P<cpu>\d+)_conc(?P<conc>\d+)\.json$",
    re.IGNORECASE,
)
_MIX_NAME_RE = re.compile(
    r"^summary_CPU(?P<cpu>\d+)_conc(?P<conc>\d+)_mix(?P<mix>\d+)\.json$",
    re.IGNORECASE,
)


def cpu_tag_to_float(tag: str) -> float:
    return int(tag, 10) / 10.0


def warn(message: str) -> None:
    print(f"Предупреждение: {message}", file=sys.stderr)


def read_metrics(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"не удалось прочитать JSON {path}: {exc}") from exc
    metrics = data.get("metrics")
    if not isinstance(metrics, dict):
        raise ValueError(f"в файле {path} нет объекта metrics")
    return metrics


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


def pick_duration_metric(metrics: dict) -> dict | None:
    for key, val in metrics.items():
        if key.startswith("http_req_duration"):
            return val if isinstance(val, dict) else None
    return None


def collect_lab13_mix(
    root: Path,
    panel_conc: int,
) -> dict[float, dict[str, tuple[float, float]]]:
    """by_cpu[cpu][mix] = (post_avg, get_avg)."""
    by_cpu: dict[float, dict[str, tuple[float, float]]] = {}

    for path in sorted(root.glob("summary_CPU*_conc*_mix*.json")):
        m = _MIX_NAME_RE.match(path.name)
        if not m:
            continue
        if int(m.group("conc"), 10) != panel_conc:
            continue

        cpu = cpu_tag_to_float(m.group("cpu"))
        mix = m.group("mix")
        if cpu not in CPU_STEPS:
            warn(f"{path.name}: CPU {cpu:g} не 0.5/1.0 — пропуск")
            continue
        if mix not in MIX_ORDER:
            warn(f"{path.name}: неизвестный mix{mix}")
            continue

        metrics = read_metrics(path)
        post_avg = get_avg(metrics.get("post_ms") or {})
        get_avg_val = get_avg(metrics.get("get_ms") or {})
        if post_avg is None or get_avg_val is None:
            warn(f"{path.name}: нет post_ms и/или get_ms avg (добавьте Trend в load-lab13-kafka-proxy.js)")
            continue

        by_cpu.setdefault(cpu, {})[mix] = (post_avg, get_avg_val)

    return by_cpu


def plot_lab13_like_lab8(
    root: Path,
    panel_conc: int,
    *,
    save_alias_default: int | None,
) -> bool:
    """Три панели как LAB8 lab8_latency_vs_cpu.png; сохраняет lab13_latency_vs_cpu_conc{N}.png."""
    by_cpu = collect_lab13_mix(root, panel_conc)
    missing: list[tuple[float, str]] = []
    for cpu in CPU_STEPS:
        for mix in MIX_ORDER:
            if mix not in by_cpu.get(cpu, {}):
                missing.append((cpu, mix))

    if missing:
        print(
            f"LAB13 (conc={panel_conc}): не хватает JSON для lab13_latency_vs_cpu (нужны все CPU×mix):",
            file=sys.stderr,
        )
        for cpu, mix in missing:
            print(f"  CPU {cpu:g}, mix {mix}", file=sys.stderr)
        print(
            "Ожидаются файлы вида summary_CPU05_conc{N}_mix05.json … mix95.",
            file=sys.stderr,
        )
        return False

    mix_order = MIX_ORDER
    # Как LAB8: доля GET /additional/stats задаётся STATS_SHARE (mix05 → 0.05 …).
    subtitles = (
        "write/read = 5/95",
        "write/read = 50/50",
        "write/read = 95/5",
    )
    xs = list(CPU_STEPS)

    fig, axes = plt.subplots(1, 3, figsize=(12, 5), sharey=True)
    fig.suptitle(
        f"Avg response time (ms) vs CPU — LAB13 @KafkaListener concurrency={panel_conc}",
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
            label="POST /publish (Kafka proxy)",
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
    out_conc = root / f"lab13_latency_vs_cpu_conc{panel_conc}.png"
    plt.savefig(out_conc, dpi=150, bbox_inches="tight")
    if save_alias_default is not None and panel_conc == save_alias_default:
        out_alias = root / "lab13_latency_vs_cpu.png"
        plt.savefig(out_alias, dpi=150, bbox_inches="tight")
        print(f"PNG: {out_alias}")
    plt.close()
    print(f"PNG: {out_conc}")
    return True


def plot_legacy_concurrency_lines(root: Path) -> None:
    paths = sorted(
        p
        for p in root.glob("summary_CPU*_conc*.json")
        if "_mix" not in p.name and _LEGACY_NAME_RE.match(p.name)
    )
    if not paths:
        return

    def load(path: Path) -> tuple[float, int, float | None, float | None]:
        m = _LEGACY_NAME_RE.match(path.name)
        if not m:
            raise ValueError(path.name)
        cpu_f = cpu_tag_to_float(m.group("cpu"))
        conc = int(m.group("conc"), 10)
        metrics = read_metrics(path)
        dur = pick_duration_metric(metrics)
        return cpu_f, conc, get_p95(dur), get_avg(dur)

    cells: list[tuple[float, int, float | None, float | None]] = []
    for path in paths:
        try:
            cells.append(load(path))
        except (ValueError, json.JSONDecodeError, OSError) as ex:
            warn(f"пропуск {path}: {ex}")

    if not cells:
        return

    by_conc_p95: dict[int, list[tuple[float, float]]] = {}
    by_conc_avg: dict[int, list[tuple[float, float]]] = {}
    for cpu_f, conc, p95, avg in sorted(cells, key=lambda x: (x[0], x[1])):
        if p95 is not None:
            by_conc_p95.setdefault(conc, []).append((cpu_f, p95))
        if avg is not None:
            by_conc_avg.setdefault(conc, []).append((cpu_f, avg))

    if by_conc_p95:
        fig1, ax1 = plt.subplots(figsize=(8, 4.5))
        for conc, series in sorted(by_conc_p95.items()):
            xs = [x[0] for x in series]
            ys = [x[1] for x in series]
            ax1.plot(xs, ys, marker="o", label=f"p(95), concurrency={conc}")
        ax1.set_xlabel("CPU limit (app + additional)")
        ax1.set_ylabel("http_req_duration p(95) (ms)")
        ax1.set_title("LAB13 (legacy JSON) — смешанная латентность HTTP")
        ax1.legend()
        ax1.grid(True, alpha=0.3)
        fig1.tight_layout()
        fig1.savefig(root / "lab13_latency_p95_vs_cpu.png", dpi=120)
        plt.close()
        print(f"PNG: {root / 'lab13_latency_p95_vs_cpu.png'}")

    if by_conc_avg:
        fig2, ax2 = plt.subplots(figsize=(8, 4.5))
        for conc, series in sorted(by_conc_avg.items()):
            xs = [x[0] for x in series]
            ys = [x[1] for x in series]
            ax2.plot(xs, ys, marker="s", label=f"http_req avg, concurrency={conc}")
        ax2.set_xlabel("CPU limit (app + additional)")
        ax2.set_ylabel("http_req_duration avg (ms)")
        ax2.set_title("LAB13 (legacy JSON) — смешанная латентность HTTP")
        ax2.legend()
        ax2.grid(True, alpha=0.3)
        fig2.tight_layout()
        fig2.savefig(root / "lab13_latency_avg_vs_cpu.png", dpi=120)
        plt.close()
        print(f"PNG: {root / 'lab13_latency_avg_vs_cpu.png'}")


def main() -> int:
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent / "reports-lab13")
    if not out_dir.is_dir():
        print(f"Нет каталога: {out_dir}", file=sys.stderr)
        return 1

    mix_paths = list(out_dir.glob("summary_CPU*_conc*_mix*.json"))
    default_panel = int(os.environ.get("LAB13_PANEL_CONC", sys.argv[2] if len(sys.argv) > 2 else "2"))

    rc = 0
    if mix_paths:
        any_ok = False
        for pc in (1, 2):
            if plot_lab13_like_lab8(out_dir, pc, save_alias_default=default_panel):
                any_ok = True
        if not any_ok:
            rc = 1
    else:
        warn("нет summary_*_mix*.json — пропуск трёхпанельного lab13_latency_vs_cpu*.png")

    plot_legacy_concurrency_lines(out_dir)

    return rc


if __name__ == "__main__":
    raise SystemExit(main())
