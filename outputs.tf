# =============================================================================
# Isol8 Infrastructure - Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Outputs
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

# -----------------------------------------------------------------------------
# API Gateway Outputs
# -----------------------------------------------------------------------------
output "api_gateway_endpoint" {
  description = "API Gateway invoke URL"
  value       = module.api_gateway.api_endpoint
}

output "api_url" {
  description = "API URL (HTTPS custom domain)"
  value       = "https://${var.domain_name}"
}

# -----------------------------------------------------------------------------
# ALB Outputs (Internal)
# -----------------------------------------------------------------------------
output "alb_dns_name" {
  description = "ALB DNS name (internal)"
  value       = module.alb.dns_name
}

# -----------------------------------------------------------------------------
# KMS Outputs
# -----------------------------------------------------------------------------
output "kms_key_arn" {
  description = "KMS key ARN for enclave attestation"
  value       = module.kms.key_arn
}

output "kms_key_id" {
  description = "KMS key ID"
  value       = module.kms.key_id
}

# -----------------------------------------------------------------------------
# IAM Outputs
# -----------------------------------------------------------------------------
output "ec2_role_arn" {
  description = "EC2 IAM role ARN"
  value       = module.iam.ec2_role_arn
}

output "github_actions_role_arn" {
  description = "GitHub Actions IAM role ARN (for CI/CD)"
  value       = module.iam.github_actions_role_arn
}

# -----------------------------------------------------------------------------
# Secrets Outputs
# -----------------------------------------------------------------------------
output "secrets_arn_prefix" {
  description = "ARN prefix for Secrets Manager secrets"
  value       = module.secrets.secrets_arn_prefix
}

# -----------------------------------------------------------------------------
# WebSocket API Outputs
# -----------------------------------------------------------------------------
output "websocket_url" {
  description = "WebSocket URL for client connections (wss://ws-{env}.isol8.co)"
  value       = module.websocket_api.websocket_url
}
