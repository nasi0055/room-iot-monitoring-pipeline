package com.example.alerts.model;

public class ThresholdConfig {
  public String updated_at;  // ISO time now()
  public String user_id;
  public String device_id;

  public double temperature_warning_threshold;
  public double temperature_violation_threshold;
  public double no_occupancy_light_threshold;

  // derived
  public long updatedAtMillis;
  public String userDeviceKey;

  public ThresholdConfig() {}

  @Override
  public String toString() {
    return "ThresholdConfig{" +
        "updated_at='" + updated_at + '\'' +
        ", user_id='" + user_id + '\'' +
        ", device_id='" + device_id + '\'' +
        ", temperature_warning_threshold=" + temperature_warning_threshold +
        ", temperature_violation_threshold=" + temperature_violation_threshold +
        ", no_occupancy_light_threshold=" + no_occupancy_light_threshold +
        ", updatedAtMillis=" + updatedAtMillis +
        ", userDeviceKey='" + userDeviceKey + '\'' +
        '}';
  }
}
