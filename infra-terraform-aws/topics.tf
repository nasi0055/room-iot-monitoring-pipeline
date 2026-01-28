# Kafka provider runs where you run terraform (your laptop), so you must be on VPN.
provider "kafka" {
  # aws_msk_cluster.bootstrap_brokers is a comma-separated string
  bootstrap_servers = split(",", aws_msk_cluster.this.bootstrap_brokers)

  # Keep it simple: plaintext inside VPC (since MSK was configured TLS_PLAINTEXT)
  tls_enabled = false
}

locals {
  topics = {
    iot_sensor_readings = {
      name               = "iot-sensor-readings"
      partitions         = 6
      replication_factor = 2
      config = {
        # keep a week of raw stream in Kafka (tune later)
        "retention.ms"   = tostring(7 * 24 * 60 * 60 * 1000)
        "cleanup.policy" = "delete"
      }
    }

    user_threshold_config = {
      name               = "user-threshold-config"
      partitions         = 3
      replication_factor = 2
      config = {
        # configs are “latest value wins” -> compaction is useful
        "cleanup.policy" = "compact"
      }
    }

    threshold_breached_alerts = {
      name               = "threshold-breached-alerts"
      partitions         = 3
      replication_factor = 2
      config = {
        # alerts don’t need long retention
        "retention.ms"   = tostring(24 * 60 * 60 * 1000)
        "cleanup.policy" = "delete"
      }
    }
  }
}

resource "kafka_topic" "topics" {
  for_each = local.topics

  name               = each.value.name
  partitions         = each.value.partitions
  replication_factor = each.value.replication_factor
  config             = each.value.config
}
