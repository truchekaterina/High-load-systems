#!/usr/bin/env python3
"""
LAB4: подряд запускает k6 load-sweep для заданных TARGET_VU, затем plot.py.

При каждом запуске:
  - k6 с --summary-export ПЕРЕЗАПИСЫВАЕТ summary-<vu>.json (старые данные в файле не остаются);
  - plot.py ПЕРЕЗАПИСЫВАЕТ картинку --out (по умолчанию avg_vs_vus.png).

Требуется: k6 в PATH, Python с matplotlib (для plot.py).

Пример (из папки zil/k6):
  python run_sweep_and_plot.py
  python run_sweep_and_plot.py --duration 30s
  python run_sweep_and_plot.py --skip-k6
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

K6_DIR = Path(__file__).resolve().parent
LOAD_SWEEP = K6_DIR / "load-sweep.js"
PLOT_PY = K6_DIR / "plot.py"

DEFAULT_VUS = (5, 10, 20, 40, 80)
DEFAULT_DURATION = "45s"
DEFAULT_PNG = "avg_vs_vus.png"


def main() -> None:
    p = argparse.ArgumentParser(
        description="k6: все точки load-sweep + график avg vs VU (файлы перезаписываются)"
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
        help="база API, напр. http://localhost:8083 (как в load-sweep.js)",
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
        "--skip-k6",
        action="store_true",
        help="не запускать k6, только пересобрать график из уже существующих summary-*.json",
    )
    args = p.parse_args()

    if not LOAD_SWEEP.is_file():
        sys.exit(f"Нет файла {LOAD_SWEEP}")
    if not PLOT_PY.is_file():
        sys.exit(f"Нет файла {PLOT_PY}")

    env = {**os.environ}
    if args.base_url:
        env["BASE_URL"] = args.base_url

    summary_paths: list[Path] = []
    for vu in args.vus:
        out_json = K6_DIR / f"summary-{vu}.json"
        summary_paths.append(out_json)
        if args.skip_k6:
            if not out_json.is_file():
                sys.exit(
                    f"С --skip-k6 нужен файл {out_json.name}. Сначала уберите --skip-k6."
                )
            continue
        # k6 при успешном завершении перезаписывает out_json целиком
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

    plot_out = K6_DIR / args.out
    plot_args: list[str] = [sys.executable, str(PLOT_PY), "--out", str(plot_out)]
    for vu, sp in zip(args.vus, summary_paths):
        plot_args.append(str(vu))
        plot_args.append(str(sp))
    print(f"[plot] -> {plot_out.name} (файл перезаписывается)", flush=True)
    r = subprocess.run(plot_args, cwd=K6_DIR)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
