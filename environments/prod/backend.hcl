# =============================================================================
# Terraform Backend Configuration - Prod Environment
# =============================================================================
# Initialize with: terraform init -backend-config=environments/prod/backend.hcl

bucket         = "freebird-terraform-state-877352799272"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "freebird-terraform-locks"
