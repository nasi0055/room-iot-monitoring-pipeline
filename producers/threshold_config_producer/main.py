import argparse
import pandas as pd
from datetime import datetime, timezone
from producers.common.config import Settings
from producers.common.kafka_client import KafkaPublisher

def iso_now():
    return datetime.now(timezone.utc).isoformat()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=Settings.CONFIG_CSV_PATH)
    args = ap.parse_args()

    df = pd.read_csv(args.csv)

    required = [
        "user_id",
        "device_id",
        "temperature_warning_threshold",
        "temperature_violation_threshold",
        "light_threshold",
    ]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise RuntimeError(f"config csv missing columns: {missing}. Found: {list(df.columns)}")

    pub = KafkaPublisher()

    for _, row in df.iterrows():
        event = {
            "updated_at": iso_now(),
            "user_id": str(row["user_id"]),
            "device_id": str(row["device_id"]),
            "temperature_warning_threshold": float(row["temperature_warning_threshold"]),
            "temperature_violation_threshold": float(row["temperature_violation_threshold"]),
            # rename as you requested
            "no_occupancy_light_threshold": float(row["light_threshold"]),
        }

        key = f"{event['user_id']}:{event['device_id']}"

        pub.send(
            topic=Settings.TOPIC_CONFIG,
            key=key,
            value=event,
            event_type="threshold_config",
            producer_name="config-producer",
        )

    pub.flush(10.0)

if __name__ == "__main__":
    main()
