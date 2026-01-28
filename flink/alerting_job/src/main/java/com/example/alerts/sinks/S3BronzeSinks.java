package com.example.alerts.sinks;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.serialization.Encoder;
import org.apache.flink.core.fs.Path;
import org.apache.flink.connector.file.sink.FileSink;
import org.apache.flink.streaming.api.functions.sink.filesystem.bucketassigners.DateTimeBucketAssigner;

import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.time.ZoneOffset;

public final class S3BronzeSinks {
  private static final ObjectMapper MAPPER = new ObjectMapper();

  private S3BronzeSinks() {}

  public static <T> FileSink<T> ndjson(String basePath) {
    Encoder<T> encoder = (element, stream) -> {
        try {
            writeLine(element, stream);
        } catch (Exception e) {
            throw new RuntimeException("Failed to write element to S3", e);
        }
    };
    return FileSink
        .forRowFormat(new Path(basePath), encoder)
        // partitions like dt=YYYY-MM-DD--HH (we can tweak format)
        .withBucketAssigner(new DateTimeBucketAssigner<>("'dt='yyyy-MM-dd/'hour='HH", ZoneOffset.UTC))
        .build();
  }

  private static <T> void writeLine(T element, OutputStream stream) throws Exception {
    byte[] json = MAPPER.writeValueAsBytes(element);
    stream.write(json);
    stream.write('\n');
  }
}
