import json
from typing import Dict, List, Tuple, Optional
from confluent_kafka import Producer
from .config import Settings

Header = Tuple[str, bytes]

def _delivery_report(err, msg):
    if err is not None:
        print(f"[DELIVERY-ERROR] topic={msg.topic()} key={msg.key()} err={err}")

class KafkaPublisher:
    def __init__(self):
        conf = {
            "bootstrap.servers": Settings.BOOTSTRAP,
            "security.protocol": Settings.SECURITY_PROTOCOL,  # PLAINTEXT for now
            "client.id": "sim-producer",
            "enable.idempotence": True,
            "acks": "all",
            "retries": 10,
            "retry.backoff.ms": 500,
            "linger.ms": 5,
        }
        self.p = Producer(conf)

    @staticmethod
    def _default_headers(event_type: str, producer_name: str) -> List[Header]:
        return [
            ("schema_version", b"1"),
            ("content_type", b"application/json"),
            ("event_type", event_type.encode("utf-8")),
            ("producer", producer_name.encode("utf-8")),
        ]

    def send(
        self,
        topic: str,
        key: str,
        value: Dict,
        *,
        event_type: str,
        producer_name: str,
        headers: Optional[List[Header]] = None,
    ):
        payload = json.dumps(value, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        hdrs = headers if headers is not None else self._default_headers(event_type, producer_name)
        self.p.produce(
            topic=topic,
            key=key.encode("utf-8"),
            value=payload,
            headers=hdrs,
            callback=_delivery_report,
        )

    def flush(self, timeout: float = 10.0):
        self.p.flush(timeout)
