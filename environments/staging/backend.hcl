# =============================================================================
# Terraform Backend Configuration - Staging Environment
# =============================================================================
# Initialize with: terraform init -backend-config=environments/staging/backend.hcl

bucket         = "freebird-terraform-state-877352799272"
key            = "staging/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "freebird-terraform-locks"
