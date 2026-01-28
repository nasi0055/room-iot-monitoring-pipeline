package com.example.alerts;

public final class AppConfig {
  public final String mskBootstrapServers;
  public final String topicSensor;
  public final String topicConfig;
  public final String topicAlerts;
  public final String env;

  // Rule-specific constant:
  public final int noOccLightDurationSeconds;
  public final int tempWarningDurationSeconds;
  public final int tempViolationDurationSeconds;
  public final int noOccLightCooldownSeconds;
  public final int tempWarningCooldownSeconds;
  public final int tempViolationCooldownSeconds;

  public final String bronzeBucket;
  public final String bronzePrefix;

  private AppConfig(
      String env,
      String mskBootstrapServers,
      String topicSensor,
      String topicConfig,
      String topicAlerts,
      int noOccLightDurationSeconds,
      int tempWarningDurationSeconds,
      int tempViolationDurationSeconds,
      int noOccLightCooldownSeconds,
      int tempWarningCooldownSeconds,
      int tempViolationCooldownSeconds,
      String bronzeBucket,
      String bronzePrefix
  ) {
    this.env = env;
    this.mskBootstrapServers = mskBootstrapServers;
    this.topicSensor = topicSensor;
    this.topicConfig = topicConfig;
    this.topicAlerts = topicAlerts;
    this.noOccLightDurationSeconds = noOccLightDurationSeconds;
    this.tempWarningDurationSeconds = tempWarningDurationSeconds;
    this.tempViolationDurationSeconds = tempViolationDurationSeconds;
    this.noOccLightCooldownSeconds = noOccLightCooldownSeconds;
    this.tempWarningCooldownSeconds = tempWarningCooldownSeconds;
    this.tempViolationCooldownSeconds = tempViolationCooldownSeconds;
    this.bronzeBucket = bronzeBucket;
    this.bronzePrefix = bronzePrefix;
  }

  public static AppConfig fromEnv() {
    String env = getenv("ENV", "dev");
    String bs = getenv("MSK_BOOTSTRAP_SERVERS", "b-1.iotsensorprodmsk.attx6n.c6.kafka.eu-west-1.amazonaws.com:9092,b-2.iotsensorprodmsk.attx6n.c6.kafka.eu-west-1.amazonaws.com:9092");
    String sensor = getenv("TOPIC_SENSOR", "iot-sensor-readings");
    String cfg = getenv("TOPIC_CONFIG", "user-threshold-config");
    String alerts = getenv("TOPIC_ALERTS", "threshold-breached-alerts");

    int noOcc = Integer.parseInt(getenv("NO_OCC_LIGHT_DURATION_SECONDS", "300"));
    int tempWarn = Integer.parseInt(getenv("TEMP_WARNING_DURATION_SECONDS", "1200")); // 20 min
    int tempViol = Integer.parseInt(getenv("TEMP_VIOLATION_DURATION_SECONDS", "600")); // 10 min

    int noOccCd = Integer.parseInt(getenv("NO_OCC_LIGHT_COOLDOWN_SECONDS", "600"));     // 10 min
    int warnCd  = Integer.parseInt(getenv("TEMP_WARNING_COOLDOWN_SECONDS", "600"));
    int violCd  = Integer.parseInt(getenv("TEMP_VIOLATION_COOLDOWN_SECONDS", "600"));

    String bronzeBucket = getenv("BRONZE_BUCKET", "iot-sensor-prod-bronze");
    String bronzePrefix = getenv("BRONZE_PREFIX", "bronze");

    return new AppConfig(env, bs, sensor, cfg, alerts, noOcc, tempWarn, tempViol, noOccCd, warnCd, violCd, bronzeBucket, bronzePrefix);
  }

  private static String getenv(String key, String def) {
    String v = System.getenv(key);
    return (v == null || v.isBlank()) ? def : v;
  }

  private static String getenvOrThrow(String key) {
    String v = System.getenv(key);
    if (v == null || v.isBlank()) {
      throw new IllegalArgumentException("Missing required env var: " + key);
    }
    return v;
  }

  public String envSuffix() {
    return env;
  }

}