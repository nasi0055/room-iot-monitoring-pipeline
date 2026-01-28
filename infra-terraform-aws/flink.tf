# Security group for Flink app ENIs
resource "aws_security_group" "flink" {
  name        = "${local.name_prefix}-flink-sg"
  description = "Managed Flink security group"
  vpc_id      = aws_vpc.this.id
  tags        = local.tags
}

resource "aws_security_group_rule" "flink_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.flink.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow Flink to talk to MSK brokers
resource "aws_security_group_rule" "msk_in_from_flink" {
  type                     = "ingress"
  from_port                = 9092
  to_port                  = 9094
  protocol                 = "tcp"
  security_group_id        = aws_security_group.msk.id
  source_security_group_id = aws_security_group.flink.id
  description              = "Kafka ports from Flink SG"
}

# IAM role for Managed Flink
data "aws_iam_policy_document" "flink_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["kinesisanalytics.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flink" {
  name               = "${local.name_prefix}-flink-role"
  assume_role_policy = data.aws_iam_policy_document.flink_assume_role.json
  tags               = local.tags
}

# Policy: read Flink artifact from S3, write logs to CloudWatch.
data "aws_iam_policy_document" "flink_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.flink_artifacts.arn,
      "${aws_s3_bucket.flink_artifacts.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = [
      aws_s3_bucket.bronze.arn,
      "${aws_s3_bucket.bronze.arn}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }


  # Required for VPC access (ENIs) for the app
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeRouteTables",
      "ec2:DescribeAvailabilityZones",
      "ec2:CreateNetworkInterface",
      "ec2:CreateNetworkInterfacePermission",
      "ec2:DeleteNetworkInterface"
    ]
    resources = ["*"]
  }


}

resource "aws_iam_role_policy" "flink_inline" {
  name   = "${local.name_prefix}-flink-inline"
  role   = aws_iam_role.flink.id
  policy = data.aws_iam_policy_document.flink_policy.json
}

# CloudWatch logs for the app
resource "aws_cloudwatch_log_group" "flink" {
  name              = "/aws/kinesis-analytics/${local.name_prefix}-flink"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_cloudwatch_log_stream" "flink" {
  name           = "flink-application"
  log_group_name = aws_cloudwatch_log_group.flink.name
}


# Managed Flink application
resource "aws_kinesisanalyticsv2_application" "flink" {
  name                   = "${local.name_prefix}-flink-app"
  runtime_environment    = var.flink_runtime_environment
  service_execution_role = aws_iam_role.flink.arn

  application_configuration {

    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = aws_s3_bucket.flink_artifacts.arn
          file_key   = aws_s3_object.flink_app.key
        }
      }

      code_content_type = "ZIPFILE"
    }

    flink_application_configuration {
      parallelism_configuration {
        configuration_type = "CUSTOM"
        parallelism        = var.flink_parallelism
        parallelism_per_kpu = 1
        auto_scaling_enabled = false
      }
    }

    vpc_configuration {
      security_group_ids = [aws_security_group.flink.id]
      subnet_ids         = aws_subnet.private[*].id
    }


    environment_properties {
      property_group {
        property_group_id = "app"
        property_map = {
          MSK_BOOTSTRAP_SERVERS = aws_msk_cluster.this.bootstrap_brokers
          TOPIC_SENSOR          = "iot-sensor-readings"
          TOPIC_CONFIG          = "user-threshold-config"
          TOPIC_ALERTS          = "threshold-breached-alerts"

          BRONZE_BUCKET         = aws_s3_bucket.bronze.bucket
          BRONZE_PREFIX         = "bronze"
          ENV                   = var.env
        }
      }
    }
  }

    cloudwatch_logging_options {
        log_stream_arn = aws_cloudwatch_log_stream.flink.arn
    }

  tags = local.tags
}
