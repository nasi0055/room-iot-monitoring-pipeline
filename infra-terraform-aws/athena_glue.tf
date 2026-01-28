resource "aws_glue_catalog_database" "lake" {
  name = "${local.name_prefix}_lake"
  tags = local.tags
}

resource "aws_athena_workgroup" "wg" {
  name = "${local.name_prefix}-athena"

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.logs.bucket}/athena-results/"
    }
  }

  tags = local.tags
}
