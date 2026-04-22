#!/usr/bin/env python3
"""
LAB5: заливка тестовых данных в REST API перед k6.
Требования: requests, faker (см. requirements.txt).
Порядок в жизни: поднять docker/app -> python seed.py -> k6 run ...
"""

from __future__ import annotations

import argparse
import random
import sys
import uuid
from datetime import date, timedelta
from decimal import Decimal
from typing import Any

import requests
from faker import Faker

DEFAULT_BASE = "http://localhost:8083"
DEFAULT_COUNT = 500
TIMEOUT = 10


def fail_response(r: requests.Response, context: str) -> None:
    print(f"[{context}] HTTP {r.status_code}", file=sys.stderr)
    if r.text:
        print(r.text[:2000], file=sys.stderr)


def call_clear(base: str) -> None:
    r = requests.post(f"{base.rstrip('/')}/dev/clear", timeout=TIMEOUT)
    if r.status_code not in (200, 204):
        fail_response(r, "POST /dev/clear")
        sys.exit(1)


def post_ok(
    base: str, path: str, payload: dict[str, Any], context: str
) -> requests.Response:
    r = requests.post(
        f"{base.rstrip('/')}{path}", json=payload, timeout=TIMEOUT
    )
    if r.status_code not in (200, 201):
        fail_response(r, context)
        sys.exit(1)
    return r


def seed_clients(base: str, count: int, fake: Faker) -> None:
    for i in range(count):
        # +79 + 9 цифр — уникально при переборе i
        phone = f"+79{100000000 + i:09d}"
        body = {
            "fullName": fake.name(),
            "driverLicense": f"DL-{uuid.uuid4()}",
            "phone": phone,
        }
        post_ok(base, "/clients", body, f"POST /clients [{i + 1}/{count}]")
    print(f"Создано клиентов: {count}")


def seed_cars(base: str, count: int, fake: Faker) -> None:
    for i in range(count):
        # VIN: 17 символов, без I/O/Q в реальном стандарте; для теста — буквенно-цифровой
        vin_core = (uuid.uuid4().hex + uuid.uuid4().hex).upper()[:16]
        body = {
            "vin": f"V{vin_core}"[:17],
            "model": f"{fake.word().title()} {fake.word().title()}",
            "color": fake.safe_color_name(),
            "rentalCostPerDay": float(
                Decimal(random.randint(30, 120)) + Decimal("0.50")
            ),
            "city": random.choice(
                ("Moscow", "SPB", "Kazan", "Ekaterinburg", "Novosibirsk")
            ),
            "salonName": f"{fake.company()} {i % 100}",
        }
        post_ok(base, "/cars", body, f"POST /cars [{i + 1}/{count}]")
    print(f"Создано машин: {count}")


def seed_rents(base: str, count: int, fake: Faker) -> None:
    car_ids: list[str] = []
    client_ids: list[str] = []

    for i in range(count):
        r = post_ok(
            base,
            "/clients",
            {
                "fullName": fake.name(),
                "driverLicense": f"DL-R-{uuid.uuid4()}",
                "phone": f"+79{200000000 + i:09d}",
            },
            f"POST /clients (для rents) [{i + 1}/{count}]",
        )
        client_ids.append(r.json()["id"])

    for i in range(count):
        vin_core = (uuid.uuid4().hex + uuid.uuid4().hex).upper()[:16]
        r = post_ok(
            base,
            "/cars",
            {
                "vin": f"R{vin_core}"[:17],
                "model": f"Model-{i % 50}",
                "color": fake.safe_color_name(),
                "rentalCostPerDay": float(Decimal(40) + Decimal(i % 20)),
                "city": "Moscow",
                "salonName": f"Salon {i % 20}",
            },
            f"POST /cars (для rents) [{i + 1}/{count}]",
        )
        car_ids.append(r.json()["id"])

    start0 = date.today() + timedelta(days=1)
    for i in range(count):
        cid = random.choice(car_ids)
        clid = random.choice(client_ids)
        start = start0 + timedelta(days=(i % 200))
        end = start + timedelta(days=random.randint(1, 14))
        days = (end - start).days
        # грубая оценка стоимости
        cost = float((Decimal(50) * Decimal(days)).quantize(Decimal("0.01")))
        body = {
            "carId": cid,
            "clientId": clid,
            "startDate": start.isoformat(),
            "endDate": end.isoformat(),
            "totalCost": cost,
        }
        post_ok(base, "/rents", body, f"POST /rents [{i + 1}/{count}]")
    print(f"Создано аренд: {count} (и по {count} клиентов/машин для связей)")


def main() -> None:
    p = argparse.ArgumentParser(description="Заливка тестовых данных в Car Rental API")
    p.add_argument(
        "--count",
        type=int,
        default=DEFAULT_COUNT,
        help=f"сколько объектов (по умолчанию {DEFAULT_COUNT})",
    )
    p.add_argument(
        "--endpoint",
        choices=("clients", "cars", "rents"),
        default="clients",
        help="сущность: clients | cars | rents",
    )
    p.add_argument(
        "--base-url",
        default=DEFAULT_BASE,
        help=f"база API (по умолчанию {DEFAULT_BASE})",
    )
    p.add_argument(
        "--no-clear",
        action="store_true",
        help="не вызывать POST /dev/clear перед заливкой",
    )
    args = p.parse_args()
    if args.count < 1:
        print("--count должен быть >= 1", file=sys.stderr)
        sys.exit(2)

    base = args.base_url.rstrip("/")
    fake = Faker("ru_RU")
    Faker.seed(42)

    try:
        if not args.no_clear:
            print("POST /dev/clear ...")
            call_clear(base)
        if args.endpoint == "clients":
            seed_clients(base, args.count, fake)
        elif args.endpoint == "cars":
            seed_cars(base, args.count, fake)
        else:
            seed_rents(base, args.count, fake)
    except requests.RequestException as e:
        print(f"Сетевая ошибка: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
