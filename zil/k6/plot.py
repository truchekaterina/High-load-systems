#!/usr/bin/env python3
"""LAB4: график avg(http_req_duration) vs VU из нескольких summary k6. Зависимость: pip install matplotlib"""

import argparse
import json
from pathlib import Path


def read_avg_ms(path: Path) -> float:
    data = json.loads(path.read_text(encoding='utf-8'))
    m = (data.get("metrics") or {}).get("http_req_duration") or {}
    # Старый k6: metrics.http_req_duration.values.avg; новый: metrics.http_req_duration.avg
    if isinstance(m.get("values"), dict) and m["values"].get("avg") is not None:
        return float(m["values"]["avg"])
    if m.get("avg") is not None:
        return float(m["avg"])
    raise SystemExit(f"Нет avg для http_req_duration в {path}")


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument('--out', default='avg_vs_vus.png')
    p.add_argument('pairs', nargs='+', help='VU file.json VU file.json ...')
    args = p.parse_args()
    if len(args.pairs) % 2:
        raise SystemExit('Нужны пары: VU summary.json')

    pts = sorted(
        [(int(args.pairs[i]), read_avg_ms(Path(args.pairs[i + 1]))) for i in range(0, len(args.pairs), 2)],
        key=lambda x: x[0],
    )
    vus, avgs = zip(*pts)

    import matplotlib.pyplot as plt

    plt.figure(figsize=(8, 5))
    plt.plot(vus, avgs, marker='o')
    plt.xlabel('VUs')
    plt.ylabel('http_req_duration avg, ms')
    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(args.out, dpi=150)
    print('Сохранено:', args.out)


if __name__ == '__main__':
    main()
