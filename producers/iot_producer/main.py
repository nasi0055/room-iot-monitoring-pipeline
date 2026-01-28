import argparse
import pandas as pd
import time
from datetime import datetime, timezone
from producers.common.config import Settings
from producers.common.kafka_client import KafkaPublisher

def to_iso_utc(dt_val) -> str:
    ts = pd.to_datetime(dt_val, utc=True)
    # Ensure "Z" suffix
    return ts.to_pydatetime().astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=Settings.IOT_CSV_PATH)
    ap.add_argument("--eps", type=float, default=Settings.EVENTS_PER_SECOND)
    ap.add_argument("--loop", action="store_true", default=False)
    ap.add_argument("--device-id", default=None)  # optional override
    args = ap.parse_args()

    df = pd.read_csv(args.csv)

    # Your schema (exact headers provided)
    required = ["date", "Temperature", "Humidity", "Light", "CO2", "HumidityRatio", "Occupancy"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise RuntimeError(f"iot csv missing columns: {missing}. Found: {list(df.columns)}")

    device_id = args.device_id or Settings.DEVICE_ID  # default from env
    pub = KafkaPublisher()

    i = 0
    while True:
        row = df.iloc[i % len(df)]
        event = {
            "event_time": to_iso_utc(row["date"]),
            "device_id": device_id,
            "temperature": float(row["Temperature"]),
            "humidity": float(row["Humidity"]),
            "light": float(row["Light"]),
            "co2": float(row["CO2"]),
            "humidity_ratio": float(row["HumidityRatio"]),
            "occupancy": int(row["Occupancy"]),
        }

        # Key = device_id (NOT timestamp)
        pub.send(
            topic=Settings.TOPIC_SENSOR,
            key=device_id,
            value=event,
            event_type="iot_reading",
            producer_name="iot-producer",
        )

        if i % 500 == 0:
            pub.flush(2.0)

        if args.eps > 0:
            time.sleep(1.0 / args.eps)

        i += 1
        if not args.loop and i >= len(df):
            break

    pub.flush(10.0)

if __name__ == "__main__":
    main()
