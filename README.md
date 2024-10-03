# Cloudfront Module

This module provides a CloudFront distribution, with SSL certificates from Custom Domains. It features built-in Athena queries, Kinesis stream for real-time logging and ACM certificate validation on AWS Route53 or Cloudflare.

## Usage

```tf
module "cdn" {
  source            = "tx-pts-dai/cloudfront/aws"
  version           = "2.0.1"
  enable_cloudfront = true
  aliases           = ["www.example.com", "beta.example.com", "*.beta.example.com"]
  http_version      = var.cloudfront_http_version
  dynamic_custom_origin_config = [
    {
      domain_name              = module.traefik_ingress.dns_name_ingress
      origin_id                = "custom-origin-1"
      origin_path              = "/route-to-custom-origin-1"
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  ]
  dns_zone_id                    = aws_route53_zone.zone.zone_id
  default_cache_behavior         = {
    path_pattern     = "*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "default"
    cache_policy = {
        headers         = ["Authorization", "Host"]
        cookie_behavior = "whitelist"
        cookies         = ["my-custom-cookie"]
    }
  }
  dynamic_ordered_cache_behavior = var.cloudfront_ordered_cache_behaviour # Same as the default one, but ordered

  providers = {
    aws = aws.us # AWS provider should be in region "us-east-1"
  }
}
```

## Core concepts

### Realtime Log flow

Realtime logs are configured per behaviour and are delivererd like this

```
+--------------+       +------------+       +---------+       +----------+       +---------+
| CloudFront   |       | CloudFront |       | Kinesis |       | Firehose |       | datadog |
| distribution |  -->  | realtime   |  -->  | stream  |  -->  | delivery |  -->  | Saas    |
| behaviour    |  /    | log config |       |         |       | stream   |       |         |
+--------------+  |    +------------+       +---------+       +----------+       +---------+
      ...         |
+--------------+  |
| CloudFront   |  |
| distribution | /
| behaviour    |
+--------------+
```

### Cloudwatch logs

Cloudwatch logs are configured per distribution and follow this path.

```
+--------------+       +-----------+
| CloudFront   |       |           |
| distribution |  -->  | S3 Bucket |
|              |       |           |
+--------------+       +-----------+
```

## Improvements

* Allow the possibility to configure multiple Firehose Stream from the Kinesis Stream
* Deploy the Kinesis Stream only if there is a Firehose Stream
* Put Kinesis as an external modules. We put it in CloudFront only because we want to use the "Logging" S3 bucket deployed in it. To discuss if it's not mether to have a dedicated Kinesis S3 bucket or use an AWS Account generic S3 bucket.

## Examples

< if the folder `examples/` exists, put here the link to the examples subfolders with their descriptions >

## Contributing

< issues and contribution guidelines for public modules >

### Pre-Commit

Installation: [install pre-commit](https://pre-commit.com/) and execute `pre-commit install`. This will generate pre-commit hooks according to the config in `.pre-commit-config.yaml`

Before submitting a PR be sure to have used the pre-commit hooks or run: `pre-commit run -a`

The `pre-commit` command will run:

* Terraform fmt
* Terraform validate
* Terraform docs
* Terraform validate with tflint
* check for merge conflicts
* fix end of files

as described in the `.pre-commit-config.yaml` file

## Terraform docs

Generated with `terraform-docs markdown --anchor=false --html=false --indent=3 --output-file=README.md .` from this directory

<!-- BEGIN_TF_DOCS -->
### Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.3.0 |
| aws | >= 5.0 |
| cloudflare | >= 3.0 |
| random | >= 3.0 |

### Providers

| Name | Version |
|------|---------|
| aws | 5.62.0 |
| cloudflare | 4.39.0 |
| random | 3.6.2 |

### Modules

No modules.

### Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_athena_database.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_database) | resource |
| [aws_athena_named_query.cloudfront_logs_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_named_query.first_logs_query](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_named_query) | resource |
| [aws_athena_workgroup.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/athena_workgroup) | resource |
| [aws_cloudfront_cache_policy.ordered_behaviors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_cache_policy) | resource |
| [aws_cloudfront_distribution.cloudfront_distribution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_request_policy.ordered_behaviors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_request_policy) | resource |
| [aws_cloudfront_realtime_log_config.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_realtime_log_config) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_stream.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_cloudwatch_log_stream.delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_stream) | resource |
| [aws_iam_policy.cloudfront_realtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.cloudfront_realtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.cloudfront_realtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.firehose](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kinesis_firehose_delivery_stream.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_firehose_delivery_stream) | resource |
| [aws_kinesis_stream.cloudfront](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_stream) | resource |
| [aws_s3_bucket.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_lifecycle_configuration.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [cloudflare_record.certificate_validation](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/record) | resource |
| [random_id.this](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.cloudfront_realtime_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudfront_realtime_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.firehose_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.firehose_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aliases | Alternate domain names for the CloudFront Distribution. A Custom SSL certificate will be created in ACM with the same names | `list(string)` | n/a | yes |
| cloudflare\_zone\_id | ID of the CloudFlare Route53 Zone where to create the records to validate the certificate. Providing it will auto-create the DNS record for the validation of the certificate | `string` | `null` | no |
| cloudfront\_custom\_error\_response | The list of custom errors and their TTLs. | ```list(object({ error_code = number min_ttl = number response_page_path = string response_code = number }))``` | `[]` | no |
| cloudfront\_price\_class | Price class of the cloudfront distribution. | `string` | `"PriceClass_100"` | no |
| comment | Comments for the cloudfront distribution. | `string` | `""` | no |
| default\_cache\_behavior | Default cache behavior resource for this distribution. | ```object({ path_pattern = string allowed_methods = list(string) cached_methods = list(string) target_origin_id = string compress = optional(bool, true) cache_policy = optional(object({ min_ttl = optional(number, 0) default_ttl = optional(number, 0) max_ttl = optional(number, 31536000) # 1 year header_behavior = optional(string, "whitelist") headers = optional(list(string), ["Host", "Origin"]) cookie_behavior = optional(string, "none") cookies = optional(list(string), []) query_string_behavior = optional(string, "all") query_strings = optional(list(string), []) enable_brotli = optional(bool, true) enable_gzip = optional(bool, true) }), {}) # use this if you want to include additional headers/cookies/query_strings to be forwarded to the origin origin_request_policy = optional(object({ header_behavior = optional(string, "none") headers = optional(list(string), []) cookie_behavior = optional(string, "none") cookies = optional(list(string), []) query_string_behavior = optional(string, "none") query_strings = optional(list(string), []) })) viewer_protocol_policy = optional(string, "redirect-to-https") realtime_log_config_arn = optional(string) function_association = optional(list(object({ event_type = string function_arn = string })), []) lambda_at_edge = optional(list(object({ lambda_arn = string event_type = string include_body = bool })), []) })``` | `null` | no |
| default\_root\_object | The object that we want Cloudfront to return | `string` | `null` | no |
| dynamic\_custom\_origin\_config | Configuration of the custom origin (e.g: HTTP server) | ```list(object({ domain_name = string origin_id = string origin_path = string http_port = optional(number, 80) https_port = optional(number, 443) origin_keepalive_timeout = optional(number, 60) origin_read_timeout = optional(number, 60) origin_protocol_policy = optional(string, "https-only") origin_ssl_protocols = list(string) custom_header = optional(list(object({ name = string value = string })), []) }))``` | `[]` | no |
| dynamic\_ordered\_cache\_behavior | An ordered list of cache behaviors resource for this distribution. List from top to bottom in order of precedence. The topmost cache behavior will have precedence 0. | ```list(object({ path_pattern = string allowed_methods = list(string) cached_methods = list(string) target_origin_id = string compress = optional(bool, true) cache_policy = optional(object({ min_ttl = optional(number, 0) default_ttl = optional(number, 0) max_ttl = optional(number, 31536000) # 1 year header_behavior = optional(string, "whitelist") headers = optional(list(string), ["Host", "Origin"]) cookie_behavior = optional(string, "none") cookies = optional(list(string), []) query_string_behavior = optional(string, "all") query_strings = optional(list(string), []) enable_brotli = optional(bool, true) enable_gzip = optional(bool, true) }), {}) # use this if you want to include additional headers/cookies/query_strings to be forwarded to the origin origin_request_policy = optional(object({ header_behavior = optional(string, "none") headers = optional(list(string), []) cookie_behavior = optional(string, "none") cookies = optional(list(string), []) query_string_behavior = optional(string, "none") query_strings = optional(list(string), []) })) viewer_protocol_policy = optional(string, "redirect-to-https") realtime_log_config_arn = optional(string) function_association = optional(list(object({ event_type = string function_arn = string })), []) lambda_at_edge = optional(list(object({ lambda_arn = string event_type = string include_body = bool })), []) }))``` | `[]` | no |
| dynamic\_origin\_group | One or more origin\_group for this distribution (multiples allowed). | ```list(object({ id = string status_codes = list(number) member1 = string member2 = string }))``` | `[]` | no |
| dynamic\_s3\_origin\_config | Configuration of the S3 bucket used as origin, if any | ```list(object({ domain_name = string origin_id = string origin_path = string origin_access_identity = optional(string) }))``` | `[]` | no |
| enable\_cloudfront | Enables the cloudfront distribution. If false: distribution isn't active. | `bool` | `true` | no |
| http\_version | Which HTTP version we use | `string` | `"http2and3"` | no |
| logging | Enable logging capabilities for CloudFront | ```object({ activate = bool deploy_resources = bool bucket_prefix = optional(string, "aws-cloudfront-logs") bucket_override = optional(string, null) cloudfront_realtime_log_fields = optional(list(string), [ # See https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/real-time-logs.html#understand-real-time-log-config-fields "asn", "c-country", "c-ip", "c-ip-version", "c-port", "cache-behavior-path-pattern", "cmcd-buffer-length", "cmcd-buffer-starvation", "cmcd-content-id", "cmcd-deadline", "cmcd-encoded-bitrate", "cmcd-measured-throughput", "cmcd-next-object-request", "cmcd-next-range-request", "cmcd-object-duration", "cmcd-object-type", "cmcd-playback-rate", "cmcd-requested-maximum-throughput", "cmcd-session-id", "cmcd-startup", "cmcd-stream-type", "cmcd-streaming-format", "cmcd-top-bitrate", "cmcd-version", "cs-accept", "cs-accept-encoding", "cs-bytes", "cs-cookie", "cs-header-names", "cs-headers", "cs-headers-count", "cs-host", "cs-method", "cs-protocol", "cs-protocol-version", "cs-referer", "cs-uri-query", "cs-uri-stem", "cs-user-agent", "fle-encrypted-fields", "fle-status", "origin-fbl", "origin-lbl", "primary-distribution-dns-name", "primary-distribution-id", "sc-bytes", "sc-content-len", "sc-content-type", "sc-range-end", "sc-range-start", "sc-status", "ssl-cipher", "ssl-protocol", "time-taken", "time-to-first-byte", "timestamp", "x-edge-detailed-result-type", "x-edge-location", "x-edge-request-id", "x-edge-response-result-type", "x-edge-result-type", "x-forwarded-for", "x-host-header" ]) cloudfront_realtime_log_sampling_rate = optional(number, 1) logs_prefix = optional(string, "logs/") retention_days = optional(number, 30) datadog_api_key = optional(string, null) })``` | ```{ "activate": false, "deploy_resources": false }``` | no |
| retain\_on\_delete | Disables the distribution instead of deleting it when destroying the resource through Terraform. If this is set, the distribution needs to be deleted manually afterwards. | `bool` | `false` | no |
| viewer\_cert\_minimum\_protocol\_version | Minimum SSL/TLS protocol for https certificates used by the viewer | `string` | `"TLSv1.2_2021"` | no |
| wait\_for\_deployment | If enabled, the resource will wait for the distribution status to change from In Progress to Deployed. Setting this to false will skip the process. Default: true | `bool` | `false` | no |
| web\_acl\_id | Optional WAF arn | `string` | `""` | no |

### Outputs

| Name | Description |
|------|-------------|
| cloudfront\_distribution\_dns\_name | DNS name of the cloudfront distribution |
| cloudfront\_distribution\_hosted\_zone | Hosted zone id of the cloudfront distribution |
| realtime\_log\_config\_arn | ARN of the realtime logging configuration |
<!-- END_TF_DOCS -->
