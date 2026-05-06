#!/usr/bin/env bash
# Создать топик LAB13 с ровно 2 партициями (если ещё нет).
# Запускать на узле с kafka-topics.sh (SSH 2314/2315) или где есть доступ к bootstrap.
#
# Примеры:
#   export KAFKA_BOOTSTRAP_SERVERS=10.60.3.12:9094
#   ./kafka_lab13_create_topic_2_partitions.sh
#
#   KAFKA_LAB13_TOPIC=hl07-lab13 REPLICATION_FACTOR=1 ./kafka_lab13_create_topic_2_partitions.sh
set -euo pipefail

TOPIC="${KAFKA_LAB13_TOPIC:-hl07-lab13}"
PARTITIONS="${KAFKA_LAB13_PARTITIONS:-2}"
RF="${REPLICATION_FACTOR:-1}"
BOOTSTRAP="${KAFKA_BOOTSTRAP_SERVERS:-hl15.zil:9094}"

find_kafka_topics_sh() {
  if [[ -n "${KAFKA_HOME:-}" && -x "$KAFKA_HOME/bin/kafka-topics.sh" ]]; then
    echo "$KAFKA_HOME/bin/kafka-topics.sh"
    return
  fi
  local d
  for d in "$HOME"/kafka_2.13-*; do
    if [[ -x "$d/bin/kafka-topics.sh" ]]; then
      echo "$d/bin/kafka-topics.sh"
      return
    fi
  done
  echo "Не найден kafka-topics.sh: задайте KAFKA_HOME или установите Kafka в ~/kafka_2.13-*" >&2
  exit 1
}

KT="$(find_kafka_topics_sh)"
echo "Using: $KT"
echo "Bootstrap: $BOOTSTRAP"
echo "Topic: $TOPIC partitions=$PARTITIONS replication-factor=$RF"

if "$KT" --bootstrap-server "$BOOTSTRAP" --describe --topic "$TOPIC" &>/dev/null; then
  echo "Топик уже существует. Текущее описание:"
  "$KT" --bootstrap-server "$BOOTSTRAP" --describe --topic "$TOPIC"
  pc=$("$KT" --bootstrap-server "$BOOTSTRAP" --describe --topic "$TOPIC" | grep -E 'PartitionCount' | head -1 || true)
  echo "$pc"
  if echo "$pc" | grep -q 'PartitionCount: 2'; then
    echo "OK: PartitionCount = 2"
    exit 0
  fi
  echo "Ошибка: топик есть, но партиций не 2. Уменьшить число партиций стандартно нельзя — используйте другое имя топика." >&2
  exit 1
fi

"$KT" --bootstrap-server "$BOOTSTRAP" --create \
  --topic "$TOPIC" \
  --partitions "$PARTITIONS" \
  --replication-factor "$RF"

echo "Создано. Проверка:"
"$KT" --bootstrap-server "$BOOTSTRAP" --describe --topic "$TOPIC"
