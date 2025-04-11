data "aws_caller_identity" "current" {}

locals {
  resources_name = "${var.logging.bucket_prefix}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_athena_workgroup" "cloudfront" {
  count         = var.logging.deploy_resources ? 1 : 0
  name          = local.resources_name
  force_destroy = true
  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.logs[count.index].bucket}/query-results/"
    }
  }
}

resource "aws_athena_database" "cloudfront" {
  count         = var.logging.deploy_resources ? 1 : 0
  name          = replace(local.resources_name, "-", "_")
  bucket        = aws_s3_bucket.logs[count.index].bucket
  comment       = "Database for CloudFront logs"
  force_destroy = true
}

resource "aws_athena_named_query" "cloudfront_logs_table" {
  count     = var.logging.deploy_resources ? 1 : 0
  name      = "table-creation-${local.resources_name}"
  workgroup = aws_athena_workgroup.cloudfront[count.index].id
  database  = aws_athena_database.cloudfront[count.index].name
  query = templatefile("${path.module}/athena_queries/cloudfront_logs_table.sql", {
    logging_bucket_name = aws_s3_bucket.logs[count.index].bucket
    logging_path_prefix = var.logging.logs_prefix
    database_name       = aws_athena_database.cloudfront[count.index].name
  })
}

resource "aws_athena_named_query" "first_logs_query" {
  count     = var.logging.deploy_resources ? 1 : 0
  name      = "first-100-results"
  workgroup = aws_athena_workgroup.cloudfront[count.index].id
  database  = aws_athena_database.cloudfront[count.index].name
  query     = "SELECT * FROM ${aws_athena_database.cloudfront[count.index].name}.cloudfront_logs limit 100;"
}

resource "aws_s3_bucket" "logs" {
  count = var.logging.deploy_resources ? 1 : 0

  bucket        = local.resources_name
  force_destroy = true
}

# See issue <https://github.com/hashicorp/terraform-provider-aws/issues/28353>
resource "aws_s3_bucket_ownership_controls" "logs" {
  count = var.logging.deploy_resources ? 1 : 0

  bucket = aws_s3_bucket.logs[count.index].id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  count = var.logging.deploy_resources ? 1 : 0

  bucket = aws_s3_bucket.logs[count.index].id
  acl    = "private"

  depends_on = [aws_s3_bucket_ownership_controls.logs]
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  count = var.logging.deploy_resources ? 1 : 0

  bucket = aws_s3_bucket.logs[count.index].bucket
  rule {
    id = "cloudfront-logs"
    expiration {
      days = var.logging.retention_days
    }
    filter {
      prefix = ""
    }
    status = "Enabled"
  }
}
