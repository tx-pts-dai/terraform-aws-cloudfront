output "cloudfront_distribution_dns_name" {
  value       = aws_cloudfront_distribution.cloudfront_distribution.domain_name
  description = "DNS name of the cloudfront distribution"
}

output "cloudfront_distribution_hosted_zone" {
  value       = aws_cloudfront_distribution.cloudfront_distribution.hosted_zone_id
  description = "Hosted zone id of the cloudfront distribution"
}

output "realtime_log_config_arn" {
  value       = try(aws_cloudfront_realtime_log_config.default[0].arn, null)
  description = "ARN of the realtime logging configuration"

}
