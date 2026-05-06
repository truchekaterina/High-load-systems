# Простой продюсер для проверки LAB12.
# Установка: py -m pip install kafka-python
#
# На ВМ приложения (hl07 и т.п.) брокеры доступны по именам узлов Kafka — по умолчанию
# hl15.zil:9094, hl14.zil:9094 (как у Spring).
# С ноутбука при туннеле LAB11 (§8.2): задайте KAFKA_BOOTSTRAP_SERVERS=127.0.0.1:19094,127.0.0.1:19095
# или KAFKA_PUBLISH_USE_TUNNEL=1.
# DEL: KAFKA_OPERATION=DEL и KAFKA_USER_ID=<uuid>; при необходимости KAFKA_DEL_PAYLOAD_AS_OBJECT=1.

from __future__ import annotations

import json
import os
import sys

from kafka import KafkaProducer

# Как на учебном кластере (два брокера); на hl07 к 127.0.0.1:19094 Kafka не привязана.
_DEFAULT_VM_BOOTSTRAPS = "hl15.zil:9094,hl14.zil:9094"
_TUNNEL_BOOTSTRAPS = "127.0.0.1:19094,127.0.0.1:19095"
_DEFAULT_TOPIC = "hl07"


def _parse_bootstraps(raw: str) -> list[str]:
    parts = [p.strip() for p in raw.split(",") if p.strip()]
    return parts if parts else ["hl15.zil:9094", "hl14.zil:9094"]


def _resolve_bootstrap_servers() -> list[str]:
    for key in ("KAFKA_BOOTSTRAP_SERVERS", "SPRING_KAFKA_BOOTSTRAP_SERVERS"):
        val = os.environ.get(key, "").strip()
        if val:
            return _parse_bootstraps(val)
    if os.environ.get("KAFKA_PUBLISH_USE_TUNNEL", "").strip() in ("1", "true", "yes"):
        return _parse_bootstraps(_TUNNEL_BOOTSTRAPS)
    return _parse_bootstraps(_DEFAULT_VM_BOOTSTRAPS)


def _resolve_topic() -> str:
    return (os.environ.get("KAFKA_TOPIC") or _DEFAULT_TOPIC).strip() or _DEFAULT_TOPIC


def _build_message() -> dict:
    op = (os.environ.get("KAFKA_OPERATION") or "POST").strip().upper()
    if op == "DEL":
        user_id = (os.environ.get("KAFKA_USER_ID") or "").strip()
        if not user_id:
            print(
                "DEL requires KAFKA_USER_ID=<uuid>",
                file=sys.stderr,
            )
            raise SystemExit(2)
        as_object = os.environ.get("KAFKA_DEL_PAYLOAD_AS_OBJECT", "").strip() in (
            "1",
            "true",
            "yes",
        )
        payload: object = {"id": user_id} if as_object else user_id
        return {"entity": "USER", "operation": "DEL", "payload": payload}
    if op != "POST":
        print(f"Unsupported KAFKA_OPERATION={op!r} (use POST or DEL)", file=sys.stderr)
        raise SystemExit(2)
    return {
        "entity": "USER",
        "operation": "POST",
        "payload": {
            "fullName": "From Python LAB12",
            "driverLicense": "PY1234567",
            "phone": "+70000000099",
        },
    }


def main() -> None:
    bootstraps = _resolve_bootstrap_servers()
    topic = _resolve_topic()
    msg = _build_message()

    producer = KafkaProducer(
        bootstrap_servers=bootstraps,
        value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode("utf-8"),
    )

    producer.send(topic, value=msg).get(timeout=15)
    producer.flush()
    producer.close()
    print(
        "Sent one message to topic",
        topic,
        "via",
        ",".join(bootstraps),
        "op=",
        msg.get("operation"),
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
