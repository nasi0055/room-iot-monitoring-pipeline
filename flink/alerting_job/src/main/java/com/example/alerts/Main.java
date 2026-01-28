package com.example.alerts;

import com.example.alerts.model.SensorReading;
import com.example.alerts.model.ThresholdBreachAlert;
import com.example.alerts.model.ThresholdConfig;
import com.example.alerts.process.AlertingFunction;
import com.example.alerts.serde.JsonParsers;
import com.example.alerts.sinks.AlertsKafkaSink;
import com.example.alerts.sinks.S3BronzeSinks;
import com.example.alerts.sources.ConfigKafkaSource;
import com.example.alerts.sources.SensorKafkaSource;

import java.time.Duration;

import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.MapFunction;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.streaming.api.CheckpointingMode;
import org.apache.flink.streaming.api.datastream.BroadcastStream;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.SingleOutputStreamOperator;
import org.apache.flink.streaming.api.environment.CheckpointConfig;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static com.example.alerts.state.StateDescriptors.CONFIG_BY_DEVICE;


public class Main {
  private static final Logger LOG = LoggerFactory.getLogger(Main.class);

  public static void main(String[] args) throws Exception {
    AppConfig cfg = AppConfig.fromEnv();

    StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();


    // // Checkpointing
    // env.enableCheckpointing(300_000L, CheckpointingMode.EXACTLY_ONCE); // every 5 mins
    // CheckpointConfig chk = env.getCheckpointConfig();
    // chk.setMinPauseBetweenCheckpoints(10_000L);
    // chk.setCheckpointTimeout(120_000L);
    // chk.setMaxConcurrentCheckpoints(1);
    // chk.setTolerableCheckpointFailureNumber(3);

    // // Good practice
    // chk.enableUnalignedCheckpoints(); // helps under backpressure

    LOG.info("Starting Flink Alerting Job");
    LOG.info("MSK_BOOTSTRAP_SERVERS={}", cfg.mskBootstrapServers);
    LOG.info("TOPIC_SENSOR={}", cfg.topicSensor);

    KafkaSource<String> kafkaSource = SensorKafkaSource.build(cfg);

    DataStream<SensorReading> sensorStream =
        env.fromSource(kafkaSource, WatermarkStrategy.noWatermarks(), "kafka-sensor-raw")
            .map((MapFunction<String, SensorReading>) JsonParsers::parseSensorReading)
            .name("parse-sensor-json")
            .assignTimestampsAndWatermarks(
                WatermarkStrategy.<SensorReading>forBoundedOutOfOrderness(Duration.ofSeconds(30))
                    .withTimestampAssigner((event, ts) -> event.eventTimeMillis)
            )
            .name("sensor-watermarks");

    SingleOutputStreamOperator<ThresholdConfig> configStream =
        env.fromSource(ConfigKafkaSource.build(cfg), WatermarkStrategy.noWatermarks(), "kafka-config-raw")
            .map(JsonParsers::parseThresholdConfig)
            .name("parse-config-json");


    BroadcastStream<ThresholdConfig> configBroadcast =
        configStream.broadcast(CONFIG_BY_DEVICE);

    DataStream<ThresholdBreachAlert> alerts =
        sensorStream
            .keyBy(r -> r.device_id)
            .connect(configBroadcast)
            .process(new AlertingFunction(
                cfg.noOccLightDurationSeconds,
                cfg.tempWarningDurationSeconds,
                cfg.tempViolationDurationSeconds,
                cfg.noOccLightCooldownSeconds,
                cfg.tempWarningCooldownSeconds,
                cfg.tempViolationCooldownSeconds
            ))
            .name("alerting-logic");


    alerts.print().name("debug-print-alerts");

    alerts.sinkTo(AlertsKafkaSink.build(cfg))
        .name("kafka-sink-alerts");

    String sensorOut = String.format("s3://%s/%s/iot_sensor_readings/", cfg.bronzeBucket, cfg.bronzePrefix);
    String alertsOut = String.format("s3://%s/%s/threshold_breached_alerts/", cfg.bronzeBucket, cfg.bronzePrefix);

    sensorStream.sinkTo(S3BronzeSinks.ndjson(sensorOut))
        .name("s3-bronze-sensor");

    alerts.sinkTo(S3BronzeSinks.ndjson(alertsOut))
        .name("s3-bronze-alerts");

    env.execute("flink-alerting-job");
  }
}
