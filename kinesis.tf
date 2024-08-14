# Resources to allow forwarding of cloudfront real-time logs to datadog
# It's using CloudFront Realtime Log Config, Kinesis Stream and Firehose Stream
locals {
  cloudfront_realtime_log_name                 = "cloudfront-${random_id.this.hex}-rt"
  kinesis_stream_name                          = "cloudfront-${random_id.this.hex}-rt"
  firehose_stream_name                         = "cloudfront-${random_id.this.hex}-rt"
  datadog_kinesis_url                          = "https://aws-kinesis-http-intake.logs.datadoghq.eu/v1/input"
  cloudwatch_firehose_log_group_name           = "/firehose/${local.firehose_stream_name}"
  cloudwatch_firehose_delivery_log_stream_name = "DestinationDelivery"
  cloudwatch_firehose_backup_log_stream_name   = "BackupDelivery"
  iam_name_firehose                            = "kinesis-firehose-cloudwatch-${random_id.this.hex}"
  iam_name_cf_realtime                         = "cloudfront-realtime-cloudwatch-${random_id.this.hex}"
}

# Random ID for creating unique resources instead of using a timestamp which is
# different accross resources. Note: This is only generated on apply and is
# static for the life of the stack. Avoids a circular dependency.
resource "random_id" "this" {
  byte_length = 4
}

resource "aws_cloudfront_realtime_log_config" "default" {
  count = var.logging.deploy_resources ? 1 : 0

  name          = "default"
  sampling_rate = var.logging.cloudfront_realtime_log_sampling_rate

  endpoint {
    stream_type = "Kinesis"

    kinesis_stream_config {
      role_arn   = aws_iam_role.cloudfront_realtime[0].arn
      stream_arn = aws_kinesis_stream.cloudfront[0].arn
    }
  }
  fields = var.logging.cloudfront_realtime_log_fields
}

resource "aws_kinesis_stream" "cloudfront" {
  count = var.logging.deploy_resources ? 1 : 0

  name             = local.kinesis_stream_name
  retention_period = 24 # in hours (24=default and minimum)

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
}

resource "aws_kinesis_firehose_delivery_stream" "cloudfront" {
  count = var.logging.deploy_resources ? 1 : 0

  name        = local.firehose_stream_name
  destination = "http_endpoint"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.cloudfront[0].arn
    role_arn           = aws_iam_role.firehose[0].arn
  }

  http_endpoint_configuration {
    url                = local.datadog_kinesis_url
    name               = "datadog"
    role_arn           = aws_iam_role.firehose[0].arn
    access_key         = var.logging.datadog_api_key
    buffering_size     = 4  # number (5=default)
    buffering_interval = 60 # in seconds (300=default)
    retry_duration     = 60 # in seconds (300=default)

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.this[0].name
      log_stream_name = aws_cloudwatch_log_stream.delivery[0].name
    }

    s3_configuration {
      role_arn            = aws_iam_role.firehose[0].arn
      bucket_arn          = aws_s3_bucket.logs[0].arn
      prefix              = "kinesis/"
      error_output_prefix = "kinesis-error/"
      cloudwatch_logging_options {
        enabled         = true
        log_group_name  = aws_cloudwatch_log_group.this[0].name
        log_stream_name = aws_cloudwatch_log_stream.backup[0].name
      }
    }

    request_configuration {
      content_encoding = "GZIP"
    }
  }
  depends_on = [
    aws_iam_role_policy_attachment.firehose[0]
  ]
}

# For firehose stream logging
resource "aws_cloudwatch_log_group" "this" {
  count = var.logging.deploy_resources ? 1 : 0

  name              = local.cloudwatch_firehose_log_group_name
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "delivery" {
  count = var.logging.deploy_resources ? 1 : 0

  name           = local.cloudwatch_firehose_delivery_log_stream_name
  log_group_name = aws_cloudwatch_log_group.this[0].name
}

resource "aws_cloudwatch_log_stream" "backup" {
  count = var.logging.deploy_resources ? 1 : 0

  name           = local.cloudwatch_firehose_backup_log_stream_name
  log_group_name = aws_cloudwatch_log_group.this[0].name
}

# Needed role/permission for firehose stream
resource "aws_iam_role" "firehose" {
  count = var.logging.deploy_resources ? 1 : 0

  name               = local.iam_name_firehose
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "firehose" {
  count = var.logging.deploy_resources ? 1 : 0

  role       = aws_iam_role.firehose[0].name
  policy_arn = aws_iam_policy.firehose[0].arn
}

resource "aws_iam_policy" "firehose" {
  count = var.logging.deploy_resources ? 1 : 0

  name        = local.iam_name_firehose
  description = "Permissions for ${local.firehose_stream_name} firehose stream"
  policy      = data.aws_iam_policy_document.firehose_permissions[0].json
}

data "aws_iam_policy_document" "firehose_assume_role" {
  count = var.logging.deploy_resources ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "firehose_permissions" {
  count = var.logging.deploy_resources ? 1 : 0

  statement {
    actions = [
      "glue:GetTable",
      "glue:GetTableVersion",
      "glue:GetTableVersions"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:glue:eu-central-1:${data.aws_caller_identity.current.account_id}:catalog"
    ]
  }

  statement {
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetBucketLocation",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ]
    effect = "Allow"
    resources = [
      aws_s3_bucket.logs[0].arn,
      "${aws_s3_bucket.logs[0].arn}/*",
    ]
  }

  statement {
    actions = [
      "logs:PutLogEvents"
    ]
    effect = "Allow"
    resources = [
      aws_cloudwatch_log_stream.delivery[0].arn,
      aws_cloudwatch_log_stream.backup[0].arn
    ]
  }
  statement {
    actions = [
      "kinesis:DescribeStream",
      "kinesis:GetShardIterator",
      "kinesis:GetRecords",
      "kinesis:ListShards"
    ]
    effect = "Allow"
    resources = [
      aws_kinesis_stream.cloudfront[0].arn
    ]
  }
}
resource "aws_iam_role" "cloudfront_realtime" {
  count = var.logging.deploy_resources ? 1 : 0

  name               = local.iam_name_cf_realtime
  assume_role_policy = data.aws_iam_policy_document.cloudfront_realtime_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "cloudfront_realtime" {
  count = var.logging.deploy_resources ? 1 : 0

  role       = aws_iam_role.cloudfront_realtime[0].name
  policy_arn = aws_iam_policy.cloudfront_realtime[0].arn
}

resource "aws_iam_policy" "cloudfront_realtime" {
  count = var.logging.deploy_resources ? 1 : 0

  name        = local.iam_name_cf_realtime
  description = "Permissions for ${local.cloudfront_realtime_log_name} cloudfront realtime log"
  policy      = data.aws_iam_policy_document.cloudfront_realtime_permissions[0].json
}

data "aws_iam_policy_document" "cloudfront_realtime_assume_role" {
  count = var.logging.deploy_resources ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "cloudfront_realtime_permissions" {
  count = var.logging.deploy_resources ? 1 : 0

  statement {
    actions = [
      "kinesis:DescribeStreamSummary",
      "kinesis:DescribeStream",
      "kinesis:ListStreams",
      "kinesis:PutRecord",
      "kinesis:PutRecords"
    ]
    effect = "Allow"
    resources = [
      aws_kinesis_stream.cloudfront[0].arn
    ]
  }
}
