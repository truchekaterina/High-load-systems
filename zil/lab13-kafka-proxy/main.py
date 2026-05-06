"""
LAB13: REST POST /publish → Kafka Producer (topic from env).

Запуск (ВМ нагрузки 2311, рядом с k6):
  export KAFKA_BOOTSTRAP_SERVERS=...
  export KAFKA_TOPIC=hl07-lab13
  uvicorn main:app --host 127.0.0.1 --port 18080
"""

from __future__ import annotations

import atexit
import json
import logging
import os

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from kafka import KafkaProducer
from kafka.errors import KafkaError
from starlette import status

log = logging.getLogger("lab13-proxy")

app = FastAPI(title="LAB13 kafka publish proxy", version="1.0")

_producer: KafkaProducer | None = None


def _bootstrap_servers() -> list[str]:
    raw = (
        os.environ.get("KAFKA_BOOTSTRAP_SERVERS")
        or os.environ.get("SPRING_KAFKA_BOOTSTRAP_SERVERS")
        or "127.0.0.1:9092"
    )
    return [s.strip() for s in raw.split(",") if s.strip()]


def _topic() -> str:
    return (os.environ.get("KAFKA_TOPIC") or "hl07-lab13").strip() or "hl07-lab13"


def _send_timeout_sec() -> float:
    return float(os.environ.get("KAFKA_SEND_TIMEOUT_SEC", "15"))


def get_producer() -> KafkaProducer:
    global _producer
    if _producer is None:
        _producer = KafkaProducer(
            bootstrap_servers=_bootstrap_servers(),
            value_serializer=lambda v: v,
            linger_ms=int(os.environ.get("KAFKA_PRODUCER_LINGER_MS", "5")),
            acks=os.environ.get("KAFKA_ACKS", "all"),
            request_timeout_ms=int(os.environ.get("KAFKA_REQUEST_TIMEOUT_MS", "30000")),
            retries=int(os.environ.get("KAFKA_PRODUCER_RETRIES", "3")),
        )
        log.info(
            "KafkaProducer bootstrap=%s topic=%s",
            _bootstrap_servers(),
            _topic(),
        )
    return _producer


def _close_producer() -> None:
    global _producer
    if _producer is not None:
        try:
            _producer.flush(timeout=5)
            _producer.close()
        except Exception as ex:  # noqa: BLE001
            log.warning("producer close: %s", ex)
        _producer = None


atexit.register(_close_producer)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/publish")
def publish(payload: dict) -> JSONResponse:
    """
    JSON body — как сообщение LAB12; в Kafka попадает тот же объект, сериализованный UTF-8.
    """
    try:
        raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    except (TypeError, ValueError) as ex:
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content={"error": f"cannot serialize payload: {ex}"},
        )

    prod = get_producer()
    try:
        fut = prod.send(_topic(), value=raw)
        fut.get(timeout=_send_timeout_sec())
        prod.flush(timeout=_send_timeout_sec())
    except KafkaError as ex:
        log.exception("kafka send failed")
        return JSONResponse(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            content={"error": str(ex)},
        )
    return JSONResponse(content={"status": "ok"})
