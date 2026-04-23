#!/usr/bin/env python3
"""
LAB4: график среднего времени отклика (мс) vs TARGET_VU по файлам reports/summary-vus-*.json.

Если в JSON есть кастомные метрики k6 (Trend) из rental-mixed.js:
  k6_post_clients_ms, k6_get_stats_ms — строятся две линии с легендой.
Иначе — одна линия по общему http_req_duration (старые отчёты без Trend).

Зависимость: pip install "matplotlib>=3.7"
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import List, Optional, Tuple

# Имена Trend-метрик в k6/rental-mixed.js (должны совпадать с new Trend('…') )
METRIC_POST = "k6_post_clients_ms"
METRIC_GET = "k6_get_stats_ms"
METRIC_ALL = "http_req_duration"


def extract_avg_from_trend(trend: dict) -> Optional[float]:
    """Среднее из блока метрики k6 summary (старый и новый формат)."""
    if not trend:
        return None
    values = trend.get("values")
    if isinstance(values, dict):
        avg = values.get("avg")
        if avg is not None:
            return float(avg)
    avg = trend.get("avg")
    return float(avg) if avg is not None else None


def extract_metric(summary: dict, name: str) -> Optional[float]:
    metrics = summary.get("metrics") or {}
    return extract_avg_from_trend(metrics.get(name) or {})


def collect_series(
    reports_dir: Path,
) -> Tuple[
    List[Tuple[int, float]],
    List[Tuple[int, float]],
    List[Tuple[int, float]],
]:
    pat = re.compile(r"^summary-vus-(\d+)\.json$")
    post_pts: List[Tuple[int, float]] = []
    get_pts: List[Tuple[int, float]] = []
    legacy_pts: List[Tuple[int, float]] = []

    for path in sorted(reports_dir.glob("summary-vus-*.json")):
        m = pat.match(path.name)
        if not m:
            continue
        vus = int(m.group(1))
        with path.open(encoding="utf-8") as f:
            data = json.load(f)

        p = extract_metric(data, METRIC_POST)
        g = extract_metric(data, METRIC_GET)
        if p is not None:
            post_pts.append((vus, p))
        if g is not None:
            get_pts.append((vus, g))

        total = extract_metric(data, METRIC_ALL)
        if total is not None:
            legacy_pts.append((vus, total))
        elif p is None and g is None:
            print(f"Предупреждение: нет метрик для графика в {path}", file=sys.stderr)

    post_pts.sort(key=lambda t: t[0])
    get_pts.sort(key=lambda t: t[0])
    legacy_pts.sort(key=lambda t: t[0])
    return post_pts, get_pts, legacy_pts


def main() -> None:
    p = argparse.ArgumentParser(
        description="График avg времени отклика k6 vs VU (POST / GET раздельно)"
    )
    p.add_argument(
        "reports_dir",
        nargs="?",
        default=None,
        type=Path,
        help="Каталог с summary-vus-*.json (по умолчанию: <папка скрипта>/reports)",
    )
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="PNG (по умолчанию <reports_dir>/avg_vs_vus.png)",
    )
    args = p.parse_args()

    script_dir = Path(__file__).resolve().parent
    reports_dir = (args.reports_dir or (script_dir / "reports")).resolve()
    if not reports_dir.is_dir():
        print(f"Каталог не найден: {reports_dir}", file=sys.stderr)
        sys.exit(1)

    post_pts, get_pts, legacy_pts = collect_series(reports_dir)

    split_ok = len(post_pts) >= 1 and len(get_pts) >= 1
    if not split_ok and len(legacy_pts) < 2:
        print(
            "Нужно минимум 2 точки (legacy http_req_duration) или данные POST+GET.",
            file=sys.stderr,
        )
        sys.exit(1)

    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print('Установите matplotlib: pip install "matplotlib>=3.7"', file=sys.stderr)
        sys.exit(1)

    out_path = args.output or (reports_dir / "avg_vs_vus.png")
    plt.figure(figsize=(9, 5.5))

    if split_ok:
        vp, yp = zip(*post_pts)
        vg, yg = zip(*get_pts)
        plt.plot(
            vp,
            yp,
            "o-",
            linewidth=2,
            markersize=7,
            color="#1f77b4",
            label="POST /clients",
        )
        plt.plot(
            vg,
            yg,
            "s-",
            linewidth=2,
            markersize=7,
            color="#ff7f0e",
            label="GET /stats",
        )
        plt.legend(loc="upper left", framealpha=0.9)
        title = "k6: средняя задержка vs TARGET_VUS (отдельно POST и GET)"
    else:
        v, y = zip(*legacy_pts)
        plt.plot(
            v,
            y,
            "o-",
            linewidth=2,
            markersize=8,
            color="#444444",
            label="Все запросы (http_req_duration)",
        )
        plt.legend(loc="upper left", framealpha=0.9)
        title = (
            "k6: средняя задержка vs TARGET_VUS (общий http_req_duration; "
            "для раздельных кривых используйте rental-mixed.js и Trend-метрики)"
        )

    plt.xlabel("Целевые VU (TARGET_VUS)")
    plt.ylabel("Среднее время отклика (мс)")
    plt.title(title)
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(out_path, dpi=150)
    print(f"Сохранено: {out_path}")


if __name__ == "__main__":
    main()
