# Простой продюсер для проверки LAB12.
# Установка: py -m pip install kafka-python
# Туннель LAB11 (§8.2) должен быть открыт, иначе замените BOOTSTRAPS на адреса доступные с вашей машины.

from kafka import KafkaProducer
import json
import sys

BOOTSTRAPS = ["127.0.0.1:19094", "127.0.0.1:19095"]
TOPIC = "hl07"


def main() -> None:
    producer = KafkaProducer(
        bootstrap_servers=BOOTSTRAPS,
        value_serializer=lambda v: json.dumps(v, ensure_ascii=False).encode("utf-8"),
    )

    # Пример из ТЗ: USER + POST (клиент без id — сгенерируется в @PrePersist)
    msg = {
        "entity": "USER",
        "operation": "POST",
        "payload": {
            "fullName": "From Python LAB12",
            "driverLicense": "PY1234567",
            "phone": "+70000000099",
        },
    }
    producer.send(TOPIC, value=msg).get(timeout=15)
    producer.flush()
    producer.close()
    print("Sent one message to topic", TOPIC, file=sys.stderr)


if __name__ == "__main__":
    main()
