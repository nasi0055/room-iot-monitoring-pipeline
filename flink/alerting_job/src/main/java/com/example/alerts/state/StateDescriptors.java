package com.example.alerts.state;

import com.example.alerts.model.ThresholdConfig;
import org.apache.flink.api.common.state.MapStateDescriptor;
import org.apache.flink.api.common.typeinfo.TypeInformation;

public final class StateDescriptors {
  private StateDescriptors() {}

  // Keyed by device_id (since sensor stream keyed by device_id)
  public static final MapStateDescriptor<String, ThresholdConfig> CONFIG_BY_DEVICE =
      new MapStateDescriptor<>(
          "configByDevice",
          TypeInformation.of(String.class),
          TypeInformation.of(ThresholdConfig.class)
      );
}
