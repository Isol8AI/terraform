# =============================================================================
# KMS Module - Outputs
# =============================================================================

output "key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.enclave.arn
}

output "key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.enclave.key_id
}

output "key_alias" {
  description = "KMS key alias"
  value       = aws_kms_alias.enclave.name
}
