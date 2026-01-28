resource "aws_s3_object" "airflow_dag" {
  bucket = aws_s3_bucket.airflow.bucket
  key    = "dags/lakehouse_dbt_pipeline.py"
  source = "../airflow/dags/lakehouse_dbt_pipeline.py"
  etag   = filemd5("../airflow/dags/lakehouse_dbt_pipeline.py")
}
