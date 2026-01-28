package com.example.alerts.model;

public class SensorReading {
  public String event_time;     // ISO string, from CSV "date"
  public String device_id;

  public double temperature;
  public double humidity;
  public double light;
  public double co2;
  public double humidity_ratio;
  public int occupancy;

  // Derived in code (not part of JSON)
  public long eventTimeMillis;

  public SensorReading() {} // for Jackson

  @Override
  public String toString() {
    return "SensorReading{" +
        "event_time='" + event_time + '\'' +
        ", device_id='" + device_id + '\'' +
        ", temperature=" + temperature +
        ", humidity=" + humidity +
        ", light=" + light +
        ", co2=" + co2 +
        ", humidity_ratio=" + humidity_ratio +
        ", occupancy=" + occupancy +
        ", eventTimeMillis=" + eventTimeMillis +
        '}';
  }
}
