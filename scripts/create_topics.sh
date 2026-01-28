#!/usr/bin/env bash
set -e

BOOTSTRAP="$1"

if [ -z "$BOOTSTRAP" ]; then
  echo "Usage: $0 <bootstrap-brokers>"
  exit 1
fi

TOPICS=(
  "iot-sensor-readings"
  "user-threshold-config"
  "threshold-breached-alerts"
)

for TOPIC in "${TOPICS[@]}"; do
  kafka-topics.sh \
    --bootstrap-server "$BOOTSTRAP" \
    --create \
    --if-not-exists \
    --topic "$TOPIC" \
    --partitions 3 \
    --replication-factor 2
done

kafka-topics.sh --bootstrap-server "$BOOTSTRAP" --list
