# =============================================================================
# IAM Module - Variables
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
  description = "KMS key ARN for enclave attestation"
  type        = string
}

variable "secrets_arn_prefix" {
  description = "ARN prefix for Secrets Manager secrets"
  type        = string
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repos" {
  description = "List of GitHub repository names to trust"
  type        = list(string)
  default     = []
}

variable "websocket_api_arn" {
  description = "WebSocket API execution ARN for Management API permissions"
  type        = string
  default     = ""
}

variable "ws_connections_table_arn" {
  description = "DynamoDB table ARN for WebSocket connections"
  type        = string
  default     = ""
}
