output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "msk_bootstrap_brokers" {
  value = aws_msk_cluster.this.bootstrap_brokers
}

output "s3_buckets" {
  value = {
    bronze = aws_s3_bucket.bronze.bucket
    silver = aws_s3_bucket.silver.bucket
    gold   = aws_s3_bucket.gold.bucket
    logs   = aws_s3_bucket.logs.bucket
  }
}

output "flink_app_name" {
  value = aws_kinesisanalyticsv2_application.flink.name
}
