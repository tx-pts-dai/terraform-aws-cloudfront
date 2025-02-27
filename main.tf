terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

resource "aws_acm_certificate" "cert" {
  domain_name               = var.aliases[0]
  subject_alternative_names = slice(var.aliases, 1, length(var.aliases))
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = trim(var.aliases[0], "*.") # wildcard not allowed in tags.
  }
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = aws_acm_certificate.cert.arn

  lifecycle {
    create_before_destroy = true
  }
}

resource "cloudflare_record" "certificate_validation" {
  for_each = (
    var.cloudflare_zone_id != null
    ? {
      # replace(dvo.domain_name, "*.", "") is a workaorund to not create 2 CNAMEs with same value
      for dvo in aws_acm_certificate.cert.domain_validation_options : replace(dvo.domain_name, "*.", "") => {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }
    }
    : {}
  )

  allow_overwrite = true
  name            = each.value.name
  content         = each.value.record
  ttl             = 60
  type            = each.value.type
  zone_id         = var.cloudflare_zone_id
}

locals {
  ordered_behaviours_map = { for behaviour in var.dynamic_ordered_cache_behavior :
    substr(sha256(behaviour.path_pattern), 0, 8) => behaviour
  }
  cache_policy_map = merge(
    { "default" = var.default_cache_behavior }, local.ordered_behaviours_map
  )
  origin_request_policies_map = { for k, v in local.cache_policy_map :
    k => v if v.origin_request_policy != null
  }
  ordered_behaviours_map_staging = { for behaviour in var.dynamic_ordered_cache_behavior_staging :
    substr(sha256(behaviour.path_pattern), 0, 8) => behaviour
  }
  cache_policy_map_staging = merge(
    { "default" = var.default_cache_behavior_staging }, local.ordered_behaviours_map_staging
  )
  origin_request_policies_map_staging = { for k, v in local.cache_policy_map_staging :
    k => v if v.origin_request_policy != null
  }
}

resource "aws_cloudfront_cache_policy" "ordered_behaviors" {
  for_each    = local.cache_policy_map
  name        = "${replace(var.aliases[0], "/[*.]/", "_")}-${each.key}"
  min_ttl     = each.value.cache_policy.min_ttl
  default_ttl = each.value.cache_policy.default_ttl
  max_ttl     = each.value.cache_policy.max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = each.value.cache_policy.enable_gzip
    enable_accept_encoding_brotli = each.value.cache_policy.enable_brotli
    cookies_config {
      cookie_behavior = each.value.cache_policy.cookie_behavior
      dynamic "cookies" {
        for_each = length(each.value.cache_policy.cookies) > 0 ? [1] : []
        content {
          items = each.value.cache_policy.cookies
        }
      }
    }
    headers_config {
      header_behavior = each.value.cache_policy.header_behavior
      dynamic "headers" {
        for_each = length(each.value.cache_policy.headers) > 0 ? [1] : []
        content {
          items = each.value.cache_policy.headers
        }
      }
    }
    query_strings_config {
      query_string_behavior = each.value.cache_policy.query_string_behavior
      dynamic "query_strings" {
        for_each = length(each.value.cache_policy.query_strings) > 0 ? [1] : []
        content {
          items = each.value.cache_policy.query_strings
        }
      }
    }
  }
}

# Values in the cache policy are automatically included in origin requests,
# so you don’t need to specify those values again in the origin request policy.
resource "aws_cloudfront_origin_request_policy" "ordered_behaviors" {
  for_each = local.origin_request_policies_map
  name     = "${replace(var.aliases[0], "/[*.]/", "_")}-${each.key}"

  cookies_config {
    cookie_behavior = each.value.origin_request_policy.cookie_behavior
    dynamic "cookies" {
      for_each = length(each.value.origin_request_policy.cookies) > 0 ? [1] : []
      content {
        items = each.value.origin_request_policy.cookies
      }
    }
  }

  headers_config {
    header_behavior = each.value.origin_request_policy.header_behavior
    dynamic "headers" {
      for_each = length(each.value.origin_request_policy.headers) > 0 ? [1] : []
      content {
        items = each.value.origin_request_policy.headers
      }
    }
  }

  query_strings_config {
    query_string_behavior = each.value.origin_request_policy.query_string_behavior
    dynamic "query_strings" {
      for_each = length(each.value.origin_request_policy.query_strings) > 0 ? [1] : []
      content {
        items = each.value.origin_request_policy.query_strings
      }
    }
  }
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  aliases             = var.aliases
  comment             = "${var.comment}. Associated with resource ID ${random_id.this.hex}"
  default_root_object = var.default_root_object
  enabled             = var.enable_cloudfront
  http_version        = var.http_version
  is_ipv6_enabled     = "true"
  price_class         = var.cloudfront_price_class
  retain_on_delete    = var.retain_on_delete
  wait_for_deployment = var.wait_for_deployment
  web_acl_id          = var.web_acl_id

  continuous_deployment_policy_id = var.enable_cloudfront_staging ? aws_cloudfront_continuous_deployment_policy.cloudfront_staging[0].id : null

  dynamic "origin" {
    for_each = var.dynamic_s3_origin_config
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
      dynamic "s3_origin_config" {
        for_each = origin.value.origin_access_identity != null ? [1] : []
        content {
          origin_access_identity = origin.value.origin_access_identity
        }
      }
    }
  }
  dynamic "origin" {
    for_each = var.dynamic_custom_origin_config
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
      custom_origin_config {
        http_port                = origin.value.http_port
        https_port               = origin.value.https_port
        origin_keepalive_timeout = origin.value.origin_keepalive_timeout
        origin_read_timeout      = origin.value.origin_read_timeout
        origin_protocol_policy   = origin.value.origin_protocol_policy
        origin_ssl_protocols     = origin.value.origin_ssl_protocols
      }
      dynamic "custom_header" {
        for_each = origin.value.custom_header
        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }
    }
  }
  dynamic "origin_group" {
    for_each = var.dynamic_origin_group
    content {
      origin_id = origin_group.value.id
      failover_criteria {
        status_codes = origin_group.value.status_codes
      }
      member {
        origin_id = origin_group.value.member1
      }
      member {
        origin_id = origin_group.value.member2
      }
    }
  }
  default_cache_behavior {
    allowed_methods         = var.default_cache_behavior.allowed_methods
    cached_methods          = var.default_cache_behavior.cached_methods
    target_origin_id        = var.default_cache_behavior.target_origin_id
    compress                = var.default_cache_behavior.compress
    viewer_protocol_policy  = var.default_cache_behavior.viewer_protocol_policy
    realtime_log_config_arn = var.default_cache_behavior.realtime_log_config_arn

    cache_policy_id          = aws_cloudfront_cache_policy.ordered_behaviors["default"].id
    origin_request_policy_id = try(aws_cloudfront_origin_request_policy.ordered_behaviors["default"].id, null)

    dynamic "function_association" {
      for_each = var.default_cache_behavior.function_association
      content {
        function_arn = function_association.value.function_arn
        event_type   = function_association.value.event_type
      }
    }

    dynamic "lambda_function_association" {
      for_each = var.default_cache_behavior.lambda_at_edge
      content {
        lambda_arn   = lambda_function_association.value.lambda_arn
        event_type   = lambda_function_association.value.event_type
        include_body = lambda_function_association.value.include_body
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.dynamic_ordered_cache_behavior
    content {
      path_pattern            = ordered_cache_behavior.value.path_pattern
      allowed_methods         = ordered_cache_behavior.value.allowed_methods
      cached_methods          = ordered_cache_behavior.value.cached_methods
      target_origin_id        = ordered_cache_behavior.value.target_origin_id
      compress                = ordered_cache_behavior.value.compress
      viewer_protocol_policy  = ordered_cache_behavior.value.viewer_protocol_policy
      realtime_log_config_arn = ordered_cache_behavior.value.realtime_log_config_arn

      cache_policy_id          = aws_cloudfront_cache_policy.ordered_behaviors[substr(sha256(ordered_cache_behavior.value.path_pattern), 0, 8)].id
      origin_request_policy_id = try(aws_cloudfront_origin_request_policy.ordered_behaviors[substr(sha256(ordered_cache_behavior.value.path_pattern), 0, 8)].id, null)

      dynamic "function_association" {
        for_each = ordered_cache_behavior.value.function_association
        content {
          function_arn = function_association.value.function_arn
          event_type   = function_association.value.event_type
        }
      }

      dynamic "lambda_function_association" {
        for_each = ordered_cache_behavior.value.lambda_at_edge
        content {
          lambda_arn   = lambda_function_association.value.lambda_arn
          event_type   = lambda_function_association.value.event_type
          include_body = lambda_function_association.value.include_body
        }
      }
    }
  }
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    minimum_protocol_version = var.viewer_cert_minimum_protocol_version
    ssl_support_method       = "sni-only"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "custom_error_response" {
    for_each = var.cloudfront_custom_error_response
    content {
      error_code            = custom_error_response.value.error_code
      error_caching_min_ttl = custom_error_response.value.min_ttl
      response_page_path    = custom_error_response.value.response_page_path
      response_code         = custom_error_response.value.response_code
    }
  }

  dynamic "logging_config" {
    for_each = var.logging.activate ? [1] : []
    content {
      bucket = var.logging.bucket_override != null ? var.logging.bucket_override : aws_s3_bucket.logs[0].bucket_domain_name
      prefix = var.logging.logs_prefix
    }
  }
}

resource "aws_cloudfront_distribution" "cloudfront_staging_distribution" {
  count               = var.enable_cloudfront_staging ? 1 : 0
  comment             = "${var.comment}. Staging associated with resource ID ${random_id.this.hex}"
  default_root_object = var.default_root_object
  enabled             = var.enable_cloudfront_staging
  http_version        = "http2"
  is_ipv6_enabled     = "true"
  price_class         = var.cloudfront_price_class
  retain_on_delete    = var.retain_on_delete
  wait_for_deployment = var.wait_for_deployment
  web_acl_id          = var.web_acl_id
  staging             = true
  dynamic "origin" {
    for_each = var.dynamic_s3_origin_config_staging
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
      dynamic "s3_origin_config" {
        for_each = origin.value.origin_access_identity != null ? [1] : []
        content {
          origin_access_identity = origin.value.origin_access_identity
        }
      }
    }
  }
  dynamic "origin" {
    for_each = var.dynamic_custom_origin_config_staging
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path
      custom_origin_config {
        http_port                = origin.value.http_port
        https_port               = origin.value.https_port
        origin_keepalive_timeout = origin.value.origin_keepalive_timeout
        origin_read_timeout      = origin.value.origin_read_timeout
        origin_protocol_policy   = origin.value.origin_protocol_policy
        origin_ssl_protocols     = origin.value.origin_ssl_protocols
      }
      dynamic "custom_header" {
        for_each = origin.value.custom_header
        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }
    }
  }
  dynamic "origin_group" {
    for_each = var.dynamic_origin_group_staging
    content {
      origin_id = origin_group.value.id
      failover_criteria {
        status_codes = origin_group.value.status_codes
      }
      member {
        origin_id = origin_group.value.member1
      }
      member {
        origin_id = origin_group.value.member2
      }
    }
  }
  default_cache_behavior {
    allowed_methods         = var.default_cache_behavior_staging.allowed_methods
    cached_methods          = var.default_cache_behavior_staging.cached_methods
    target_origin_id        = var.default_cache_behavior_staging.target_origin_id
    compress                = var.default_cache_behavior_staging.compress
    viewer_protocol_policy  = var.default_cache_behavior_staging.viewer_protocol_policy
    realtime_log_config_arn = var.default_cache_behavior_staging.realtime_log_config_arn

    cache_policy_id          = aws_cloudfront_cache_policy.ordered_behaviors_staging["default"].id
    origin_request_policy_id = try(aws_cloudfront_origin_request_policy.ordered_behaviors_staging["default"].id, null)

    dynamic "function_association" {
      for_each = var.default_cache_behavior_staging.function_association
      content {
        function_arn = function_association.value.function_arn
        event_type   = function_association.value.event_type
      }
    }

    dynamic "lambda_function_association" {
      for_each = var.default_cache_behavior_staging.lambda_at_edge
      content {
        lambda_arn   = lambda_function_association.value.lambda_arn
        event_type   = lambda_function_association.value.event_type
        include_body = lambda_function_association.value.include_body
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.dynamic_ordered_cache_behavior_staging
    content {
      path_pattern            = ordered_cache_behavior.value.path_pattern
      allowed_methods         = ordered_cache_behavior.value.allowed_methods
      cached_methods          = ordered_cache_behavior.value.cached_methods
      target_origin_id        = ordered_cache_behavior.value.target_origin_id
      compress                = ordered_cache_behavior.value.compress
      viewer_protocol_policy  = ordered_cache_behavior.value.viewer_protocol_policy
      realtime_log_config_arn = ordered_cache_behavior.value.realtime_log_config_arn

      cache_policy_id          = aws_cloudfront_cache_policy.ordered_behaviors_staging[substr(sha256(ordered_cache_behavior.value.path_pattern), 0, 8)].id
      origin_request_policy_id = try(aws_cloudfront_origin_request_policy.ordered_behaviors_staging[substr(sha256(ordered_cache_behavior.value.path_pattern), 0, 8)].id, null)

      dynamic "function_association" {
        for_each = ordered_cache_behavior.value.function_association
        content {
          function_arn = function_association.value.function_arn
          event_type   = function_association.value.event_type
        }
      }

      dynamic "lambda_function_association" {
        for_each = ordered_cache_behavior.value.lambda_at_edge
        content {
          lambda_arn   = lambda_function_association.value.lambda_arn
          event_type   = lambda_function_association.value.event_type
          include_body = lambda_function_association.value.include_body
        }
      }
    }
  }
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    minimum_protocol_version = var.viewer_cert_minimum_protocol_version
    ssl_support_method       = "sni-only"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  dynamic "custom_error_response" {
    for_each = var.cloudfront_custom_error_response
    content {
      error_code            = custom_error_response.value.error_code
      error_caching_min_ttl = custom_error_response.value.min_ttl
      response_page_path    = custom_error_response.value.response_page_path
      response_code         = custom_error_response.value.response_code
    }
  }

  dynamic "logging_config" {
    for_each = var.logging.activate ? [1] : []
    content {
      bucket = var.logging.bucket_override != null ? var.logging.bucket_override : aws_s3_bucket.logs[0].bucket_domain_name
      prefix = var.logging.logs_prefix
    }
  }
}

resource "aws_cloudfront_continuous_deployment_policy" "cloudfront_staging" {
  count   = var.enable_cloudfront_staging ? 1 : 0
  enabled = var.enable_cloudfront_staging

  staging_distribution_dns_names {
    items    = [aws_cloudfront_distribution.cloudfront_staging_distribution[count.index].domain_name]
    quantity = 1
  }

  traffic_config {
    type = "SingleWeight"
    single_weight_config {
      weight = var.cloudfront_staging_weight
    }
  }
}

resource "aws_cloudfront_cache_policy" "ordered_behaviors_staging" {
  for_each    = local.cache_policy_map_staging
  name        = "${replace(var.aliases[0], "/[*.]/", "_")}-${each.key}"
  min_ttl     = each.value.cache_policy.min_ttl
  default_ttl = each.value.cache_policy.default_ttl
  max_ttl     = each.value.cache_policy.max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = each.value.cache_policy.enable_gzip
    enable_accept_encoding_brotli = each.value.cache_policy.enable_brotli
    cookies_config {
      cookie_behavior = each.value.cache_policy.cookie_behavior
      dynamic "cookies" {
        for_each = length(each.value.cache_policy.cookies) > 0 ? [1] : []
        content {
          items = each.value.cache_policy.cookies
        }
      }
    }
    headers_config {
      header_behavior = each.value.cache_policy.header_behavior
      dynamic "headers" {
        for_each = length(each.value.cache_policy.headers) > 0 ? [1] : []
        content {
          items = each.value.cache_policy.headers
        }
      }
    }
    query_strings_config {
      query_string_behavior = each.value.cache_policy.query_string_behavior
      dynamic "query_strings" {
        for_each = length(each.value.cache_policy.query_strings) > 0 ? [1] : []
        content {
          items = each.value.cache_policy.query_strings
        }
      }
    }
  }
}

# Values in the cache policy are automatically included in origin requests,
# so you don’t need to specify those values again in the origin request policy.
resource "aws_cloudfront_origin_request_policy" "ordered_behaviors_staging" {
  for_each = local.origin_request_policies_map_staging
  name     = "${replace(var.aliases[0], "/[*.]/", "_")}-${each.key}"

  cookies_config {
    cookie_behavior = each.value.origin_request_policy.cookie_behavior
    dynamic "cookies" {
      for_each = length(each.value.origin_request_policy.cookies) > 0 ? [1] : []
      content {
        items = each.value.origin_request_policy.cookies
      }
    }
  }

  headers_config {
    header_behavior = each.value.origin_request_policy.header_behavior
    dynamic "headers" {
      for_each = length(each.value.origin_request_policy.headers) > 0 ? [1] : []
      content {
        items = each.value.origin_request_policy.headers
      }
    }
  }

  query_strings_config {
    query_string_behavior = each.value.origin_request_policy.query_string_behavior
    dynamic "query_strings" {
      for_each = length(each.value.origin_request_policy.query_strings) > 0 ? [1] : []
      content {
        items = each.value.origin_request_policy.query_strings
      }
    }
  }
}
