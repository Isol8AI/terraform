# =============================================================================
# WebSocket API Module - Variables
# =============================================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

# -----------------------------------------------------------------------------
# Domain Configuration
# -----------------------------------------------------------------------------

variable "domain_name" {
  description = "Custom domain name for WebSocket API (e.g., ws-dev.isol8.co). Leave empty to skip custom domain."
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "ACM certificate ARN for custom domain (required if domain_name is set)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# ALB Integration
# -----------------------------------------------------------------------------

variable "vpc_link_id" {
  description = "VPC Link ID for ALB integration (shared with HTTP API)"
  type        = string
}

variable "alb_listener_arn" {
  description = "ALB listener ARN for WebSocket forwarding"
  type        = string
}

# -----------------------------------------------------------------------------
# Clerk Configuration
# -----------------------------------------------------------------------------

variable "clerk_jwks_url" {
  description = "Clerk JWKS URL for JWT validation (e.g., https://<clerk-domain>/.well-known/jwks.json)"
  type        = string
}

variable "clerk_issuer" {
  description = "Clerk issuer URL for JWT validation (e.g., https://<clerk-domain>)"
  type        = string
}

# -----------------------------------------------------------------------------
# Lambda Configuration
# -----------------------------------------------------------------------------

variable "jwt_layer_arn" {
  description = "Lambda layer ARN containing PyJWT and cryptography dependencies. Leave empty if dependencies are bundled."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Rate Limiting
# -----------------------------------------------------------------------------

variable "throttling_burst_limit" {
  description = "Throttling burst limit (concurrent requests)"
  type        = number
  default     = 100
}

variable "throttling_rate_limit" {
  description = "Throttling rate limit (requests per second)"
  type        = number
  default     = 50
}
