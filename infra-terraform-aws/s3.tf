resource "aws_s3_bucket" "bronze" {
  bucket = "${local.name_prefix}-bronze"
  tags   = local.tags
}

resource "aws_s3_bucket" "silver" {
  bucket = "${local.name_prefix}-silver"
  tags   = local.tags
}

resource "aws_s3_bucket" "gold" {
  bucket = "${local.name_prefix}-gold"
  tags   = local.tags
}

resource "aws_s3_bucket" "logs" {
  bucket = "${local.name_prefix}-logs"
  tags   = local.tags
}

resource "aws_s3_bucket" "flink_artifacts" {
  bucket = "${local.name_prefix}-flink-artifacts"
  tags   = local.tags
}

resource "aws_s3_bucket_versioning" "bronze" {
  bucket = aws_s3_bucket.bronze.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "silver" {
  bucket = aws_s3_bucket.silver.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "gold" {
  bucket = aws_s3_bucket.gold.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_versioning" "flink_artifacts" {
  bucket = aws_s3_bucket.flink_artifacts.id
  versioning_configuration { status = "Enabled" }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "all" {
  for_each = {
    bronze         = aws_s3_bucket.bronze.id
    silver         = aws_s3_bucket.silver.id
    gold           = aws_s3_bucket.gold.id
    logs           = aws_s3_bucket.logs.id
    flinkArtifacts = aws_s3_bucket.flink_artifacts.id
  }

  bucket = each.value

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}


# Upload Flink artifact to S3 (jar/zip)
resource "aws_s3_object" "flink_app" {
  bucket = aws_s3_bucket.flink_artifacts.bucket
  key    = "apps/flink-app.zip"
  source = var.flink_artifact_local_path
  etag   = filemd5(var.flink_artifact_local_path)
}

# Upload MWAA requirements to S3
resource "aws_s3_object" "mwaa_requirements" {
  bucket = aws_s3_bucket.airflow.bucket
  key    = "requirements/requirements.txt"
  source = "../airflow/requirements/requirements.txt"
  etag   = filemd5("../airflow/requirements/requirements.txt")
}

resource "aws_s3_object" "mwaa_startup_script" {
  bucket = aws_s3_bucket.airflow.bucket
  key    = "startup/startup.sh"
  source = "../airflow/startup/startup.sh"
  etag   = filemd5("../airflow/startup/startup.sh")
}
