package com.example.alerts.model;

public class ThresholdBreachAlert {
  public String alert_time;     // ISO string now()
  public String user_id;
  public String device_id;

  public String rule;           // NO_OCC_LIGHT | TEMP_WARNING | TEMP_VIOLATION
  public String severity;       // WARNING | VIOLATION
  public String metric;         // light | temperature
  public double observed_value;
  public double threshold_value;

  public long window_start_ms;  // when condition started (event time)
  public long window_end_ms;    // time of triggering event (event time)

  public ThresholdBreachAlert() {}

  @Override
  public String toString() {
    return "ThresholdBreachAlert{" +
        "alert_time='" + alert_time + '\'' +
        ", user_id='" + user_id + '\'' +
        ", device_id='" + device_id + '\'' +
        ", rule='" + rule + '\'' +
        ", severity='" + severity + '\'' +
        ", metric='" + metric + '\'' +
        ", observed_value=" + observed_value +
        ", threshold_value=" + threshold_value +
        ", window_start_ms=" + window_start_ms +
        ", window_end_ms=" + window_end_ms +
        '}';
  }
}
