# Простой продюсер для проверки LAB12.
# Установка: py -m pip install kafka-python
#
# На ВМ приложения (hl07 и т.п.) брокеры доступны по именам узлов Kafka — по умолчанию
# hl15.zil:9094, hl14.zil:9094 (как у Spring).
# С ноутбука при туннеле LAB11 (§8.2): задайте KAFKA_BOOTSTRAP_SERVERS=127.0.0.1:19094,127.0.0.1:19095
# или KAFKA_PUBLISH_USE_TUNNEL=1.

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


def main() -> None:
    bootstraps = _resolve_bootstrap_servers()
    topic = _resolve_topic()

    producer = KafkaProducer(
        bootstrap_servers=bootstraps,
        value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode("utf-8"),
    )

    msg = {
        "entity": "USER",
        "operation": "POST",
        "payload": {
            "fullName": "From Python LAB12",
            "driverLicense": "PY1234567",
            "phone": "+70000000099",
        },
    }
    producer.send(topic, value=msg).get(timeout=15)
    producer.flush()
    producer.close()
    print("Sent one message to topic", topic, "via", ",".join(bootstraps), file=sys.stderr)


if __name__ == "__main__":
    main()
