# =============================================================================
# Staging Environment Configuration
# =============================================================================

environment = "staging"
aws_region  = "us-east-1"

# VPC
vpc_cidr           = "10.1.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# EC2
ec2_instance_type = "m5.xlarge"
ec2_desired_count = 1
ec2_min_count     = 1
ec2_max_count     = 2

# Domain (update with your domain)
domain_name  = "api-staging.freebird.example.com"
frontend_url = "https://staging.freebird.example.com"

# Clerk (update with your values)
clerk_issuer = "https://your-clerk-domain.clerk.accounts.dev"

# GitHub (for CI/CD OIDC)
github_org  = "your-org"
github_repo = "freebird"
