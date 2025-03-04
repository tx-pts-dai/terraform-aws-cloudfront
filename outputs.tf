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

output "certificate_arn" {
  description = "The ARN of the issued ACM certificate."
  value       = aws_acm_certificate.cert.arn
}
output "certificate_domain_validation_options" {
  description = "The validation options of the issued ACM certificate."
  value           = aws_acm_certificate.cert.cert.domain_validation_options
}

output "certificate_domain" {
  description = "The primary domain name of the certificate."
  value       = aws_acm_certificate.cert.domain_name
}

output "certificate_validation_arn" {
  description = "The ARN of the ACM certificate validation resource."
  value       = aws_acm_certificate_validation.cert.id
}
