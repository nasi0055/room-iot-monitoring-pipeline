import os

def env(name: str, default: str | None = None) -> str:
    v = os.getenv(name, default)
    if v is None:
        raise RuntimeError(f"Missing required env var: {name}")
    return v

class Settings:
    BOOTSTRAP = env("KAFKA_BOOTSTRAP_SERVERS")  # comma-separated
    SECURITY_PROTOCOL = env("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")

    TOPIC_SENSOR = env("TOPIC_SENSOR", "iot-sensor-readings")
    TOPIC_CONFIG = env("TOPIC_CONFIG", "user-threshold-config")

    IOT_CSV_PATH = env("IOT_CSV_PATH", "./data/iot_data.csv")
    CONFIG_CSV_PATH = env("CONFIG_CSV_PATH", "./data/threshold_config.csv")

    DEVICE_ID = env("DEVICE_ID", "dev_123")

    EVENTS_PER_SECOND = float(env("EVENTS_PER_SECOND", "5"))
    LOOP_FOREVER = env("LOOP_FOREVER", "true").lower() == "true"
