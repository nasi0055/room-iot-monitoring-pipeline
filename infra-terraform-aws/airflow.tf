resource "aws_s3_bucket" "airflow" {
  bucket = "${local.name_prefix}-airflow"
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "airflow" {
  bucket = aws_s3_bucket.airflow.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "airflow" {
  bucket = aws_s3_bucket.airflow.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}


data "aws_iam_policy_document" "mwaa_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["airflow.amazonaws.com", "airflow-env.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mwaa" {
  name               = "${local.name_prefix}-mwaa-role"
  assume_role_policy = data.aws_iam_policy_document.mwaa_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "mwaa_policy" {

  statement {
    actions = [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetBucketLocation"
    ]
    resources = [
        aws_s3_bucket.airflow.arn,
        "${aws_s3_bucket.airflow.arn}/*"
    ]
    }

    statement {
    actions   = [
        "s3:GetBucketLocation",
        "s3:GetAccountPublicAccessBlock",
        "s3:GetBucketPublicAccessBlock"
        ]
    resources = ["*"]
    }


  # Allow Athena queries + Glue catalog reads
  statement {
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions"
    ]
    resources = ["*"]
  }

  # CloudWatch logs (MWAA needs this)
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }


  statement {
    actions = [
        "airflow:PublishMetrics"
    ]
    resources = ["*"]
    }

  statement {
    actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
    ]
    resources = ["*"]
    }


}

resource "aws_iam_role_policy" "mwaa_inline" {
  role   = aws_iam_role.mwaa.id
  policy = data.aws_iam_policy_document.mwaa_policy.json
}

resource "aws_security_group" "mwaa" {
  name        = "${local.name_prefix}-mwaa-sg"
  description = "MWAA security group"
  vpc_id      = aws_vpc.this.id
  tags        = local.tags
}

resource "aws_security_group_rule" "mwaa_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.mwaa.id
}

resource "aws_security_group_rule" "mwaa_ingress_self_all" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.mwaa.id
  self              = true
}


resource "aws_mwaa_environment" "this" {
  name               = "${local.name_prefix}-mwaa"
  airflow_version    = "2.8.1"
  environment_class  = "mw1.small"
  execution_role_arn = aws_iam_role.mwaa.arn

  source_bucket_arn = aws_s3_bucket.airflow.arn
  dag_s3_path       = "dags"
  requirements_s3_path = "requirements/requirements.txt"
  webserver_access_mode = "PUBLIC_ONLY"

  startup_script_s3_path = "startup/startup.sh"
  depends_on = [
    aws_s3_object.mwaa_startup_script,
    aws_s3_object.mwaa_requirements
    ]

  network_configuration {
    security_group_ids = [aws_security_group.mwaa.id]
    subnet_ids         = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  }

  logging_configuration {
    dag_processing_logs {
                        enabled = true
                        log_level = "INFO"
                        }
    scheduler_logs      {
                        enabled = true
                        log_level = "INFO"
                        }
    task_logs           {
                        enabled = true
                        log_level = "INFO"
                        }
    webserver_logs      {
                        enabled = true
                        log_level = "INFO"
                        }
    worker_logs         {
                        enabled = true
                        log_level = "INFO"
                        }
  }

  tags = local.tags
  
}
