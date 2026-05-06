# LAB13 — REST → Kafka (прокси для k6)

Маленький HTTP-сервис: **`POST /publish`** с JSON телом [LAB12](../documentation/LAB12_IMPLEMENTATION_MANUAL_FULL_RU.md) → публикация **value** в топик эксперимента LAB13 (**обычно `hl07-lab13`**, **2 партиции** по ТЗ; совпадает с **`KAFKA_TOPIC`** контейнера **`app`**).

## Переменные окружения

| Переменная | Назначение | Пример |
|------------|------------|--------|
| **`KAFKA_BOOTSTRAP_SERVERS`** | Брокеры, **доступные с этой ВМ** | `hl15.zil:9094,hl14.zil:9094` или `10.60.3.12:9094,10.60.3.13:9094` |
| **`KAFKA_TOPIC`** | Топик (должен совпадать с приложением; LAB13 см. ниже) | `hl07-lab13` |
| **`KAFKA_SEND_TIMEOUT_SEC`** | Таймаут ожидания ack (сек.) | `15` |

Опционально: `KAFKA_ACKS`, `KAFKA_PRODUCER_LINGER_MS`, `KAFKA_REQUEST_TIMEOUT_MS`, `KAFKA_PRODUCER_RETRIES`.

## Локальный запуск (ВМ 2311 или ПК)

```bash
cd lab13-kafka-proxy
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export KAFKA_BOOTSTRAP_SERVERS="hl15.zil:9094,hl14.zil:9094"
export KAFKA_TOPIC=hl07-lab13
uvicorn main:app --host 127.0.0.1 --port 18080
```

Проверка:

```bash
curl -sS -X POST http://127.0.0.1:18080/publish \
  -H 'Content-Type: application/json' \
  -d '{"entity":"USER","operation":"POST","payload":{"fullName":"t","driverLicense":"DL-1","phone":"+70000000001"}}'
```

## Docker (только этот сервис)

```bash
docker build -t lab13-kafka-proxy:local .
docker run --rm -e KAFKA_BOOTSTRAP_SERVERS -e KAFKA_TOPIC \
  -p 127.0.0.1:18080:18080 lab13-kafka-proxy:local
```

Образ слушает **`0.0.0.0:18080`** внутри контейнера снаружи — **127.0.0.1:18080** на хосте.

См. также `compose.proxy.example.yml`.

## Типичная ошибка

**`NoBrokersAvailable`** — с ВМ нет маршрута к `KAFKA_BOOTSTRAP_SERVERS` (порт часто **9094**), либо неверные имена/IP.
