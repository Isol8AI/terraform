# =============================================================================
# Dev Environment Configuration
# =============================================================================

environment = "dev"
aws_region  = "us-east-1"

# VPC
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b"]

# EC2 (smaller instance for dev)
ec2_instance_type = "m5.xlarge"
ec2_desired_count = 1
ec2_min_count     = 1
ec2_max_count     = 2

# Domain
domain_name  = "api-dev.isol8.co"
root_domain  = "isol8.co"
frontend_url = "http://localhost:3000"

# Clerk
clerk_issuer = "https://up-moth-55.clerk.accounts.dev"

# GitHub (for CI/CD OIDC) - trust both backend and terraform repos
github_org   = "Isol8AI"
github_repos = ["backend", "terraform"]

# =============================================================================
# SENSITIVE VALUES - Set via environment variables, not in this file!
# =============================================================================
# export TF_VAR_supabase_connection_string="postgresql://..."
# export TF_VAR_huggingface_token="hf_..."
# export TF_VAR_clerk_webhook_secret="whsec_..."
# =============================================================================
