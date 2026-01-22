# =============================================================================
# Production Environment Configuration
# =============================================================================

environment = "prod"
aws_region  = "us-east-1"

# VPC
vpc_cidr           = "10.2.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# EC2 (higher capacity for production)
ec2_instance_type = "m5.xlarge"
ec2_desired_count = 2
ec2_min_count     = 2
ec2_max_count     = 6

# Domain (update with your domain)
domain_name  = "api.freebird.example.com"
frontend_url = "https://freebird.example.com"

# Clerk (update with your values)
clerk_issuer = "https://your-clerk-domain.clerk.accounts.dev"

# GitHub (for CI/CD OIDC)
github_org  = "your-org"
github_repo = "freebird"
