# =============================================================================
# EC2 Module - Variables
# =============================================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EC2 instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m5.xlarge"
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "nlb_target_group_arn" {
  description = "NLB target group ARN for WebSocket traffic"
  type        = string
  default     = ""
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for NLB traffic ingress"
  type        = string
  default     = ""
}

variable "secrets_arn_prefix" {
  description = "Secrets Manager ARN prefix"
  type        = string
}

variable "frontend_url" {
  description = "Frontend URL for CORS configuration"
  type        = string
}

# Auto Scaling
variable "desired_count" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "min_count" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_count" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
}

# Enclave
variable "enclave_bucket_name" {
  description = "S3 bucket name for enclave artifacts"
  type        = string
  default     = ""
}

# WebSocket
variable "ws_connections_table" {
  description = "DynamoDB table name for WebSocket connections"
  type        = string
  default     = ""
}

variable "ws_management_api_url" {
  description = "Management API URL for pushing WebSocket messages"
  type        = string
  default     = ""
}

# KMS
variable "kms_key_id" {
  description = "KMS key ID for enclave envelope encryption (background mode)"
  type        = string
  default     = ""
}
