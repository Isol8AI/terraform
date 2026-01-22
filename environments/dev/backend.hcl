# =============================================================================
# Terraform Backend Configuration - Dev Environment
# =============================================================================
# Initialize with: terraform init -backend-config=environments/dev/backend.hcl

bucket         = "freebird-terraform-state-877352799272"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "freebird-terraform-locks"
