package com.example.alerts.sources;

import com.example.alerts.AppConfig;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;

public final class SensorKafkaSource {

  private SensorKafkaSource() {}

  public static KafkaSource<String> build(AppConfig cfg) {
    return KafkaSource.<String>builder()
        .setBootstrapServers(cfg.mskBootstrapServers)
        .setTopics(cfg.topicSensor)
        .setGroupId("flink-alerting-sensor-consumer")
        .setStartingOffsets(OffsetsInitializer.latest())
        .setValueOnlyDeserializer(new SimpleStringSchema())
        .build();
  }
}
