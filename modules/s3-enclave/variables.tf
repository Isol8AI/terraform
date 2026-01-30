# =============================================================================
# S3 Enclave Artifacts Module - Variables
# =============================================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for bucket encryption (optional, uses AES256 if not provided)"
  type        = string
  default     = null
}

variable "ec2_role_arn" {
  description = "EC2 IAM role ARN that needs read access to EIF files"
  type        = string
}

variable "github_actions_role_arn" {
  description = "GitHub Actions IAM role ARN that needs write access to upload EIF files"
  type        = string
}
