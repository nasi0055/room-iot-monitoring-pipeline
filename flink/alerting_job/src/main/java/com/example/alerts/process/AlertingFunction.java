package com.example.alerts.process;

import com.example.alerts.model.SensorReading;
import com.example.alerts.model.ThresholdBreachAlert;
import com.example.alerts.model.ThresholdConfig;
import com.example.alerts.state.StateDescriptors;

import org.apache.flink.api.common.state.ValueState;
import org.apache.flink.api.common.state.ValueStateDescriptor;
import org.apache.flink.api.common.state.ReadOnlyBroadcastState;
import org.apache.flink.api.common.typeinfo.Types;
import org.apache.flink.streaming.api.functions.co.KeyedBroadcastProcessFunction;
import org.apache.flink.util.Collector;

import java.time.Instant;

public class AlertingFunction extends KeyedBroadcastProcessFunction<String, SensorReading, ThresholdConfig, ThresholdBreachAlert> {

  // Per device/rule state: when condition started (event time ms), and whether we've emitted for this episode.
  private final ValueStateDescriptor<Long> noOccStartDesc =
      new ValueStateDescriptor<>("noOccLightStartMs", Types.LONG);
  private final ValueStateDescriptor<Boolean> noOccEmittedDesc =
      new ValueStateDescriptor<>("noOccLightEmitted", Types.BOOLEAN);

  private final ValueStateDescriptor<Long> tempWarnStartDesc =
      new ValueStateDescriptor<>("tempWarnStartMs", Types.LONG);
  private final ValueStateDescriptor<Boolean> tempWarnEmittedDesc =
      new ValueStateDescriptor<>("tempWarnEmitted", Types.BOOLEAN);

  private final ValueStateDescriptor<Long> tempViolStartDesc =
      new ValueStateDescriptor<>("tempViolStartMs", Types.LONG);
  private final ValueStateDescriptor<Boolean> tempViolEmittedDesc =
      new ValueStateDescriptor<>("tempViolEmitted", Types.BOOLEAN);

  private final ValueStateDescriptor<Long> noOccLastEmitDesc =
      new ValueStateDescriptor<>("noOccLightLastEmitMs", Types.LONG);

  private final ValueStateDescriptor<Long> tempWarnLastEmitDesc =
      new ValueStateDescriptor<>("tempWarnLastEmitMs", Types.LONG);

  private final ValueStateDescriptor<Long> tempViolLastEmitDesc =
      new ValueStateDescriptor<>("tempViolLastEmitMs", Types.LONG);

  private final long noOccLightDurationMs;   // 5 min
  private final long tempWarnDurationMs;     // 20 min
  private final long tempViolDurationMs;     // 10 min

  private final long noOccCooldownMs;
  private final long tempWarnCooldownMs;
  private final long tempViolCooldownMs;


  public AlertingFunction(
    long noOccLightDurationSeconds,
    long tempWarnDurationSeconds,
    long tempViolDurationSeconds,
    long noOccLightCooldownSeconds,
    long tempWarnCooldownSeconds,
    long tempViolCooldownSeconds
    ) {
    this.noOccLightDurationMs = noOccLightDurationSeconds * 1000L;
    this.tempWarnDurationMs = tempWarnDurationSeconds * 1000L;
    this.tempViolDurationMs = tempViolDurationSeconds * 1000L;

    this.noOccCooldownMs = noOccLightCooldownSeconds * 1000L;
    this.tempWarnCooldownMs = tempWarnCooldownSeconds * 1000L;
    this.tempViolCooldownMs = tempViolCooldownSeconds * 1000L;
  }

  @Override
  public void processBroadcastElement(ThresholdConfig cfg, Context ctx, Collector<ThresholdBreachAlert> out) throws Exception {
    // Store latest config by device_id
    ctx.getBroadcastState(StateDescriptors.CONFIG_BY_DEVICE).put(cfg.device_id, cfg);
  }

  @Override
  public void processElement(SensorReading r, ReadOnlyContext ctx, Collector<ThresholdBreachAlert> out) throws Exception {
    ReadOnlyBroadcastState<String, ThresholdConfig> cfgState =
        ctx.getBroadcastState(StateDescriptors.CONFIG_BY_DEVICE);

    ThresholdConfig cfg = cfgState.get(r.device_id);
    if (cfg == null) {
      // No config yet for this device: ignore for now
      return;
    }

    long t = r.eventTimeMillis;

    // 1) NO OCC + LIGHT
    boolean condNoOccLight = (r.occupancy == 0) && (r.light > cfg.no_occupancy_light_threshold);
    handleRule(
        "NO_OCC_LIGHT", "VIOLATION", "light",
        condNoOccLight, t,
        r.light, cfg.no_occupancy_light_threshold,
        cfg.user_id, r.device_id,
        noOccLightDurationMs,
        noOccCooldownMs,
        getRuntimeContext().getState(noOccStartDesc),
        getRuntimeContext().getState(noOccEmittedDesc),
        getRuntimeContext().getState(noOccLastEmitDesc),
        out
    );

    // 2) TEMP WARNING
    boolean condTempWarn = (r.temperature > cfg.temperature_warning_threshold);
    handleRule(
        "TEMP_WARNING", "WARNING", "temperature",
        condTempWarn, t,
        r.temperature, cfg.temperature_warning_threshold,
        cfg.user_id, r.device_id,
        tempWarnDurationMs,
        tempWarnCooldownMs,
        getRuntimeContext().getState(tempWarnStartDesc),
        getRuntimeContext().getState(tempWarnEmittedDesc),
        getRuntimeContext().getState(tempWarnLastEmitDesc),
        out
    );

    // 3) TEMP VIOLATION
    boolean condTempViol = (r.temperature > cfg.temperature_violation_threshold);
    handleRule(
        "TEMP_VIOLATION", "VIOLATION", "temperature",
        condTempViol, t,
        r.temperature, cfg.temperature_violation_threshold,
        cfg.user_id, r.device_id,
        tempViolDurationMs,
        tempViolCooldownMs,
        getRuntimeContext().getState(tempViolStartDesc),
        getRuntimeContext().getState(tempViolEmittedDesc),
        getRuntimeContext().getState(tempViolLastEmitDesc),
        out
    );
  }

  private static void handleRule(
      String rule,
      String severity,
      String metric,
      boolean condition,
      long eventTimeMs,
      double observed,
      double threshold,
      String userId,
      String deviceId,
      long durationMs,
      long cooldownMs,
      ValueState<Long> startState,
      ValueState<Boolean> emittedState,
      ValueState<Long> lastEmitState,
      Collector<ThresholdBreachAlert> out
  ) throws Exception {

    Long start = startState.value();
    Boolean emitted = emittedState.value();
    if (emitted == null) emitted = false;

    Long lastEmit = lastEmitState.value();
    if (lastEmit == null) lastEmit = 0L;

    if (condition) {
      if (start == null || start == 0L) {
        startState.update(eventTimeMs);
        emittedState.update(false);
        return;
      }

      long elapsed = eventTimeMs - start;
      boolean durationMet = elapsed >= durationMs;
      boolean cooldownPassed = (eventTimeMs - lastEmit) >= cooldownMs;

      if (durationMet && cooldownPassed) {
        // emit alert and mark last emitted
        ThresholdBreachAlert alert = new ThresholdBreachAlert();
        alert.alert_time = Instant.now().toString();
        alert.user_id = userId;
        alert.device_id = deviceId;
        alert.rule = rule;
        alert.severity = severity;
        alert.metric = metric;
        alert.observed_value = observed;
        alert.threshold_value = threshold;
        alert.window_start_ms = start;
        alert.window_end_ms = eventTimeMs;

        out.collect(alert);
        emittedState.update(true);
        lastEmitState.update(eventTimeMs);
      }
    } else {
      // reset episode; keep lastEmit so cooldown still applies across flapping (optional)
      startState.clear();
      emittedState.clear();
    }
  }
}
