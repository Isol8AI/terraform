# =============================================================================
# S3 Enclave Artifacts Module - Outputs
# =============================================================================

output "bucket_name" {
  description = "Name of the S3 bucket storing enclave artifacts"
  value       = aws_s3_bucket.enclave_artifacts.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.enclave_artifacts.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket"
  value       = aws_s3_bucket.enclave_artifacts.bucket_regional_domain_name
}
