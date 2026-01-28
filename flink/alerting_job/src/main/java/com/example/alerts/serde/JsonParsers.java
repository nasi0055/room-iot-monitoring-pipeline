package com.example.alerts.serde;

import com.example.alerts.model.SensorReading;
import com.example.alerts.model.ThresholdConfig;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;


import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;

public final class JsonParsers {
  private static final ObjectMapper MAPPER = new ObjectMapper()
      .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

  private JsonParsers() {}


  private static Instant parseInstantFlex(String ts) {
  try {
  return Instant.parse(ts); // "...Z"
  } catch (DateTimeParseException e) {
  return OffsetDateTime.parse(ts, DateTimeFormatter.ISO_OFFSET_DATE_TIME).toInstant(); // "...+00:00"
  }
  }

  public static SensorReading parseSensorReading(String json) throws Exception {
    SensorReading r = MAPPER.readValue(json, SensorReading.class);
    r.eventTimeMillis = parseInstantFlex(r.event_time).toEpochMilli();
    return r;
  }

public static ThresholdConfig parseThresholdConfig(String json) throws Exception {
  ThresholdConfig c = MAPPER.readValue(json, ThresholdConfig.class);
  
  c.updatedAtMillis = parseInstantFlex(c.updated_at).toEpochMilli();
  c.userDeviceKey = c.user_id + ":" + c.device_id;
  return c;
}

}

