#!/usr/bin/env python3
"""
LAB4: несколько прогонов k6 (load-sweep.js) + график avg vs VU с двумя линиями: POST /clients, GET /stats.

Метрики в summary (Trend из load-sweep.js): post_req_duration, get_req_duration.
При каждом запуске k6 --summary-export и --out PNG перезаписывают файлы.

Зависимости: k6 в PATH, pip install matplotlib

Пример (из папки zil/k6):
  python sweep_plot.py
  python sweep_plot.py --duration 30s
  python sweep_plot.py --skip-k6
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

K6_DIR = Path(__file__).resolve().parent
LOAD_SWEEP = K6_DIR / "load-sweep.js"

POST_METRIC = "post_req_duration"
GET_METRIC = "get_req_duration"

DEFAULT_VUS = (5, 10, 20, 40, 80)
DEFAULT_DURATION = "45s"
DEFAULT_PNG = "avg_vs_vus.png"


def read_metric_avg(data: dict, name: str) -> float:
    m = (data.get("metrics") or {}).get(name) or {}
    if isinstance(m.get("values"), dict) and m["values"].get("avg") is not None:
        return float(m["values"]["avg"])
    if m.get("avg") is not None:
        return float(m["avg"])
    raise SystemExit(
        f"В summary нет avg для метрики «{name}». "
        "Нужен `k6 run ... load-sweep.js` с Trend post_req_duration / get_req_duration."
    )


def load_series(
    vus: list[int], paths: list[Path]
) -> tuple[list[int], list[float], list[float]]:
    xs: list[int] = []
    post_avgs: list[float] = []
    get_avgs: list[float] = []
    for vu, p in zip(vus, paths):
        if not p.is_file():
            raise SystemExit(f"Нет файла: {p}")
        data = json.loads(p.read_text(encoding="utf-8"))
        xs.append(vu)
        post_avgs.append(read_metric_avg(data, POST_METRIC))
        get_avgs.append(read_metric_avg(data, GET_METRIC))
    return xs, post_avgs, get_avgs


def plot_two_lines(
    vus: list[int],
    post_ms: list[float],
    get_ms: list[float],
    out: Path,
) -> None:
    import matplotlib.pyplot as plt

    plt.figure(figsize=(8, 5))
    plt.plot(vus, post_ms, marker="o", label="POST /clients (avg, ms)")
    plt.plot(vus, get_ms, marker="s", label="GET /stats (avg, ms)")
    plt.xlabel("Суммарные VU (TARGET_VU; POST и GET по половине)")
    plt.ylabel("Время ответа, ms (avg)")
    plt.title("k6: avg длительность POST и GET vs нагрузка")
    plt.grid(True, alpha=0.3)
    plt.legend()
    plt.tight_layout()
    plt.savefig(out, dpi=150)
    print("Сохранено:", out)


def main() -> None:
    p = argparse.ArgumentParser(
        description="k6 load-sweep: все точки + график (две линии POST/GET); summary и PNG перезаписываются"
    )
    p.add_argument(
        "--duration",
        default=DEFAULT_DURATION,
        help=f"длительность constant-vu на точку (по умолчанию {DEFAULT_DURATION})",
    )
    p.add_argument(
        "--out",
        default=DEFAULT_PNG,
        help=f"имя PNG в папке k6 (по умолчанию {DEFAULT_PNG})",
    )
    p.add_argument(
        "--base-url",
        default=None,
        help="база API, напр. http://localhost:8083",
    )
    p.add_argument(
        "--vus",
        type=int,
        nargs="+",
        default=list(DEFAULT_VUS),
        metavar="N",
        help="точки нагрузки (по умолчанию: 5 10 20 40 80)",
    )
    p.add_argument(
        "--plot-only",
        action="store_true",
        help="только график из существующих summary-*.json (без k6)",
    )
    p.add_argument(
        "--skip-k6",
        action="store_true",
        help="то же, что --plot-only: не запускать k6",
    )
    p.add_argument(
        "legacy_pairs",
        nargs="*",
        help="устаревший режим: VU1 path1 VU2 path2 ... — только график, без k6",
    )
    args = p.parse_args()

    if args.legacy_pairs:
        if len(args.legacy_pairs) % 2:
            raise SystemExit("Нужны пары: VU summary.json")
        pairs = sorted(
            [
                (int(args.legacy_pairs[i]), Path(args.legacy_pairs[i + 1]))
                for i in range(0, len(args.legacy_pairs), 2)
            ],
            key=lambda x: x[0],
        )
        vus, paths = zip(*pairs)
        _, post_ms, get_ms = load_series(list(vus), list(paths))
        plot_out = K6_DIR / args.out
        plot_two_lines(list(vus), post_ms, get_ms, plot_out)
        return

    no_k6 = args.plot_only or args.skip_k6

    if not no_k6 and not LOAD_SWEEP.is_file():
        sys.exit(f"Нет файла {LOAD_SWEEP}")

    env = {**os.environ}
    if args.base_url:
        env["BASE_URL"] = args.base_url

    summary_paths: list[Path] = []
    for vu in args.vus:
        out_json = K6_DIR / f"summary-{vu}.json"
        summary_paths.append(out_json)
        if no_k6:
            if not out_json.is_file():
                sys.exit(
                    f"С --plot-only / --skip-k6 нужен {out_json.name}. Сначала уберите флаг и запустите k6."
                )
            continue
        cmd = [
            "k6",
            "run",
            "-e",
            f"TARGET_VUS={vu}",
            "-e",
            f"DURATION={args.duration}",
            "--summary-export",
            str(out_json),
            str(LOAD_SWEEP),
        ]
        print(f"[k6] VU={vu} -> {out_json.name}", flush=True)
        r = subprocess.run(cmd, cwd=K6_DIR, env=env)
        if r.returncode != 0:
            sys.exit(r.returncode)

    vus_list = list(args.vus)
    _, post_ms, get_ms = load_series(vus_list, summary_paths)
    plot_out = K6_DIR / args.out
    print(f"[plot] -> {plot_out.name} (две линии: POST, GET)", flush=True)
    plot_two_lines(vus_list, post_ms, get_ms, plot_out)


if __name__ == "__main__":
    main()
