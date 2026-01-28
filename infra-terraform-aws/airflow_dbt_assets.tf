resource "aws_s3_object" "dbt_project_zip" {
  bucket = aws_s3_bucket.airflow.bucket
  key    = "dbt/iot_lakehouse.zip"
  source = "../dbt/iot_lakehouse.zip"
  etag   = filemd5("../dbt/iot_lakehouse.zip")
}
