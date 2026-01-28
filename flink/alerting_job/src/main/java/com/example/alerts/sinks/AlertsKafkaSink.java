package com.example.alerts.sinks;

import com.example.alerts.AppConfig;
import com.example.alerts.model.ThresholdBreachAlert;
import com.example.alerts.serde.AlertJsonSerializer;

import org.apache.flink.connector.kafka.sink.KafkaSink;
import org.apache.flink.connector.base.DeliveryGuarantee;

public final class AlertsKafkaSink {
  private AlertsKafkaSink() {}

  public static KafkaSink<ThresholdBreachAlert> build(AppConfig cfg) {
    return KafkaSink.<ThresholdBreachAlert>builder()
        .setBootstrapServers(cfg.mskBootstrapServers)
        .setRecordSerializer(AlertJsonSerializer.forTopic(cfg.topicAlerts))
        .setDeliveryGuarantee(DeliveryGuarantee.AT_LEAST_ONCE) // upgrade later
        .build();
  }
}
