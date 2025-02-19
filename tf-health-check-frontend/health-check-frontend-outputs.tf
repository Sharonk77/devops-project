output "cloudfront_distribution_id" {
  description = "The CloudFront Distribution ID"
  value       = aws_cloudfront_distribution.s3_distribution.id
  sensitive   = true
}

output "cloudfront_oac_id" {
  description = "The CloudFront OAC ID"
  value       = aws_cloudfront_origin_access_control.s3_oac.id
  sensitive   = true
}