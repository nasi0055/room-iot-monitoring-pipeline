package com.example.alerts.sources;

import com.example.alerts.AppConfig;
import org.apache.flink.api.common.serialization.SimpleStringSchema;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;

public final class ConfigKafkaSource {

  private ConfigKafkaSource() {}

  public static KafkaSource<String> build(AppConfig cfg) {
    return KafkaSource.<String>builder()
        .setBootstrapServers(cfg.mskBootstrapServers)
        .setTopics(cfg.topicConfig)
        .setGroupId("flink-alerting-config-consumer")
        .setStartingOffsets(OffsetsInitializer.earliest()) // configs: usually want all history
        .setValueOnlyDeserializer(new SimpleStringSchema())
        .build();
  }
}
