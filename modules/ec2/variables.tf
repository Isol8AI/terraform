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

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "secrets_arn_prefix" {
  description = "Secrets Manager ARN prefix"
  type        = string
}

variable "frontend_url" {
  description = "Frontend URL for CORS"
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
