# Cloudfront
variable "web_acl_id" {
  description = "Optional WAF arn"
  type        = string
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "ID of the CloudFlare Route53 Zone where to create the records to validate the certificate. Providing it will auto-create the DNS record for the validation of the certificate"
  type        = string
  default     = null
}

variable "aliases" {
  description = "Alternate domain names for the CloudFront Distribution. A Custom SSL certificate will be created in ACM with the same names"
  type        = list(string)

  validation {
    condition     = length(var.aliases) > 0
    error_message = "You must specify at least one alias for your CloudFront distribution."
  }
}

variable "enable_cloudfront" {
  description = "Enables the cloudfront distribution. If false: distribution isn't active."
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "Price class of the cloudfront distribution."
  type        = string
  default     = "PriceClass_100"
}

variable "comment" {
  description = "Comments for the cloudfront distribution."
  type        = string
  default     = ""
}

variable "default_root_object" {
  description = "The object that we want Cloudfront to return"
  type        = string
  default     = null
}

variable "http_version" {
  description = "Which HTTP version we use"
  type        = string
  default     = "http2and3"
}

variable "retain_on_delete" {
  description = "Disables the distribution instead of deleting it when destroying the resource through Terraform. If this is set, the distribution needs to be deleted manually afterwards."
  type        = bool
  default     = false
}

variable "wait_for_deployment" {
  description = "If enabled, the resource will wait for the distribution status to change from In Progress to Deployed. Setting this to false will skip the process. Default: true"
  type        = bool
  default     = false
}

variable "dynamic_s3_origin_config" {
  description = "Configuration of the S3 bucket used as origin, if any"
  type = list(object({
    domain_name            = string
    origin_id              = string
    origin_path            = string
    origin_access_identity = optional(string)
  }))
  default = []
}

variable "dynamic_custom_origin_config" {
  description = "Configuration of the custom origin (e.g: HTTP server)"
  type = list(object({
    domain_name              = string
    origin_id                = string
    origin_path              = string
    http_port                = optional(number, 80)
    https_port               = optional(number, 443)
    origin_keepalive_timeout = optional(number, 60)
    origin_read_timeout      = optional(number, 60)
    origin_protocol_policy   = optional(string, "https-only")
    origin_ssl_protocols     = list(string)
    custom_header = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

variable "cloudfront_custom_error_response" {
  description = "The list of custom errors and their TTLs."
  type = list(object({
    error_code         = number
    min_ttl            = number
    response_page_path = string
    response_code      = number
  }))
  default = []
}

variable "viewer_cert_minimum_protocol_version" {
  description = "Minimum SSL/TLS protocol for https certificates used by the viewer"
  type        = string
  default     = "TLSv1.2_2021"
}

variable "dynamic_ordered_cache_behavior" {
  description = "An ordered list of cache behaviors resource for this distribution. List from top to bottom in order of precedence. The topmost cache behavior will have precedence 0."
  type = list(object({
    path_pattern     = string
    allowed_methods  = list(string)
    cached_methods   = list(string)
    target_origin_id = string
    compress         = optional(bool, true)
    cache_policy = optional(object({
      min_ttl               = optional(number, 0)
      default_ttl           = optional(number, 0)
      max_ttl               = optional(number, 31536000) # 1 year
      header_behavior       = optional(string, "whitelist")
      headers               = optional(list(string), ["Host", "Origin"])
      cookie_behavior       = optional(string, "none")
      cookies               = optional(list(string), [])
      query_string_behavior = optional(string, "all")
      query_strings         = optional(list(string), [])
      enable_brotli         = optional(bool, true)
      enable_gzip           = optional(bool, true)
    }), {})
    # use this if you want to include additional headers/cookies/query_strings to be forwarded to the origin
    origin_request_policy = optional(object({
      header_behavior       = optional(string, "none")
      headers               = optional(list(string), [])
      cookie_behavior       = optional(string, "none")
      cookies               = optional(list(string), [])
      query_string_behavior = optional(string, "none")
      query_strings         = optional(list(string), [])
    }))
    viewer_protocol_policy  = optional(string, "redirect-to-https")
    realtime_log_config_arn = optional(string)
    function_association = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])
    lambda_at_edge = optional(list(object({
      lambda_arn   = string
      event_type   = string
      include_body = bool
    })), [])
  }))
  default = []
}

variable "default_cache_behavior" {
  description = "Default cache behavior resource for this distribution."
  type = object({
    path_pattern     = string
    allowed_methods  = list(string)
    cached_methods   = list(string)
    target_origin_id = string
    compress         = optional(bool, true)
    cache_policy = optional(object({
      min_ttl               = optional(number, 0)
      default_ttl           = optional(number, 0)
      max_ttl               = optional(number, 31536000) # 1 year
      header_behavior       = optional(string, "whitelist")
      headers               = optional(list(string), ["Host", "Origin"])
      cookie_behavior       = optional(string, "none")
      cookies               = optional(list(string), [])
      query_string_behavior = optional(string, "all")
      query_strings         = optional(list(string), [])
      enable_brotli         = optional(bool, true)
      enable_gzip           = optional(bool, true)
    }), {})
    # use this if you want to include additional headers/cookies/query_strings to be forwarded to the origin
    origin_request_policy = optional(object({
      header_behavior       = optional(string, "none")
      headers               = optional(list(string), [])
      cookie_behavior       = optional(string, "none")
      cookies               = optional(list(string), [])
      query_string_behavior = optional(string, "none")
      query_strings         = optional(list(string), [])
    }))
    viewer_protocol_policy  = optional(string, "redirect-to-https")
    realtime_log_config_arn = optional(string)
    function_association = optional(list(object({
      event_type   = string
      function_arn = string
    })), [])
    lambda_at_edge = optional(list(object({
      lambda_arn   = string
      event_type   = string
      include_body = bool
    })), [])
  })
  default = null
}

variable "dynamic_origin_group" {
  description = "One or more origin_group for this distribution (multiples allowed)."
  type = list(object({
    id           = string
    status_codes = list(number)
    member1      = string
    member2      = string
  }))
  default = []
}

# LOGS
variable "logging" {
  description = "Enable logging capabilities for CloudFront"
  type = object({
    activate         = bool
    deploy_resources = bool
    bucket_prefix    = optional(string, "aws-cloudfront-logs")
    bucket_override  = optional(string, null)
    cloudfront_realtime_log_fields = optional(list(string), [ # See https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/real-time-logs.html#understand-real-time-log-config-fields
      "asn",
      "c-country",
      "c-ip",
      "c-ip-version",
      "c-port",
      "cache-behavior-path-pattern",
      "cmcd-buffer-length",
      "cmcd-buffer-starvation",
      "cmcd-content-id",
      "cmcd-deadline",
      "cmcd-encoded-bitrate",
      "cmcd-measured-throughput",
      "cmcd-next-object-request",
      "cmcd-next-range-request",
      "cmcd-object-duration",
      "cmcd-object-type",
      "cmcd-playback-rate",
      "cmcd-requested-maximum-throughput",
      "cmcd-session-id",
      "cmcd-startup",
      "cmcd-stream-type",
      "cmcd-streaming-format",
      "cmcd-top-bitrate",
      "cmcd-version",
      "cs-accept",
      "cs-accept-encoding",
      "cs-bytes",
      "cs-cookie",
      "cs-header-names",
      "cs-headers",
      "cs-headers-count",
      "cs-host",
      "cs-method",
      "cs-protocol",
      "cs-protocol-version",
      "cs-referer",
      "cs-uri-query",
      "cs-uri-stem",
      "cs-user-agent",
      "fle-encrypted-fields",
      "fle-status",
      "origin-fbl",
      "origin-lbl",
      "primary-distribution-dns-name",
      "primary-distribution-id",
      "sc-bytes",
      "sc-content-len",
      "sc-content-type",
      "sc-range-end",
      "sc-range-start",
      "sc-status",
      "ssl-cipher",
      "ssl-protocol",
      "time-taken",
      "time-to-first-byte",
      "timestamp",
      "x-edge-detailed-result-type",
      "x-edge-location",
      "x-edge-request-id",
      "x-edge-response-result-type",
      "x-edge-result-type",
      "x-forwarded-for",
      "x-host-header"
    ])
    cloudfront_realtime_log_sampling_rate = optional(number, 1)
    logs_prefix                           = optional(string, "logs/")
    retention_days                        = optional(number, 30)
    datadog_api_key                       = optional(string, null)
  })
  default = {
    activate         = false
    deploy_resources = false
  }
  validation {
    condition     = !(var.logging.activate && !var.logging.deploy_resources && var.logging.bucket_override == null)
    error_message = "In order to activate logs you should deploy infrastructure resources, which can be done by setting the 'deploy_resources' variable to 'true', or override the s3 bucket name"
  }
  validation {
    condition     = !(var.logging.bucket_override != null && var.logging.deploy_resources)
    error_message = "If you override the bucket name where logs will be stored you should not deploy the loggin infrastructure, this can be done by setting the 'deploy_resources' variable to 'false'"
  }
  validation {
    condition     = var.logging.cloudfront_realtime_log_sampling_rate >= 1 && var.logging.cloudfront_realtime_log_sampling_rate <= 100
    error_message = "Should be between 1 and 100 inclusive"
  }
}
