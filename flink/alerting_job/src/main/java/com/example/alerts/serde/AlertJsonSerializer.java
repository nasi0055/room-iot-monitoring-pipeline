package com.example.alerts.serde;

import com.example.alerts.model.ThresholdBreachAlert;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.connector.kafka.sink.KafkaRecordSerializationSchema;
import org.apache.kafka.clients.producer.ProducerRecord;

import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;

public final class AlertJsonSerializer {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  private AlertJsonSerializer() {}

  public static KafkaRecordSerializationSchema<ThresholdBreachAlert> forTopic(String topic) {
    return (element, context, timestamp) -> {
      byte[] value;
      try {
        value = MAPPER.writeValueAsBytes(element);
      } catch (Exception e) {
        // fall back to toString (should be rare)
        value = element.toString().getBytes(StandardCharsets.UTF_8);
      }

      // key: user_id:device_id:rule (helps partitioning + ordering per user/device/rule)
      String key = element.user_id + ":" + element.device_id + ":" + element.rule;

      // Optional headers
      Map<String, byte[]> headers = new HashMap<>();
      headers.put("schema_version", "1".getBytes(StandardCharsets.UTF_8));
      headers.put("event_type", "threshold_breached_alert".getBytes(StandardCharsets.UTF_8));
      headers.put("producer", "flink-alerting-job".getBytes(StandardCharsets.UTF_8));
      headers.put("severity", element.severity.getBytes(StandardCharsets.UTF_8));
      headers.put("rule", element.rule.getBytes(StandardCharsets.UTF_8));

      ProducerRecord<byte[], byte[]> rec = new ProducerRecord<>(
          topic,
          key.getBytes(StandardCharsets.UTF_8),
          value
      );

      // attach headers
      headers.forEach((k, v) -> rec.headers().add(k, v));
      return rec;
    };
  }
}
