# =============================================================================
# Freebird Infrastructure - Main Configuration
# =============================================================================
# This file wires together all modules for the Freebird backend infrastructure.
#
# Architecture:
#   Vercel (Frontend) → API Gateway → ALB → EC2 (Nitro Enclave)
#
# Security: The EC2 parent instance CANNOT see user plaintext. All decryption
# happens inside the Nitro Enclave, which calls HuggingFace via TLS through
# vsock-proxy (TLS terminates inside enclave, parent sees encrypted bytes).
# =============================================================================

# -----------------------------------------------------------------------------
# VPC Module
# -----------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  project            = "freebird"
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

# -----------------------------------------------------------------------------
# KMS Module (Enclave Attestation)
# -----------------------------------------------------------------------------
module "kms" {
  source = "./modules/kms"

  project     = "freebird"
  environment = var.environment
  ec2_role_arn = module.iam.ec2_role_arn

  # PCR values for enclave attestation (set after first build)
  # enclave_pcr0 = var.enclave_pcr0
  # enclave_pcr1 = var.enclave_pcr1
  # enclave_pcr2 = var.enclave_pcr2
}

# -----------------------------------------------------------------------------
# Secrets Manager Module
# -----------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  project     = "freebird"
  environment = var.environment
  kms_key_arn = module.kms.key_arn

  # Secrets to store (encrypted with KMS key)
  secrets = {
    database_url         = var.supabase_connection_string
    huggingface_token    = var.huggingface_token
    clerk_issuer         = var.clerk_issuer
    clerk_secret_key     = var.clerk_secret_key
    clerk_webhook_secret = var.clerk_webhook_secret
  }
}

# -----------------------------------------------------------------------------
# IAM Module
# -----------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  project     = "freebird"
  environment = var.environment
  kms_key_arn = module.kms.key_arn
  secrets_arn_prefix = module.secrets.secrets_arn_prefix

  # GitHub OIDC for CI/CD
  github_org  = var.github_org
  github_repo = var.github_repo
}

# -----------------------------------------------------------------------------
# ACM Module (SSL Certificate)
# -----------------------------------------------------------------------------
module "acm" {
  source = "./modules/acm"

  project     = "freebird"
  environment = var.environment
  domain_name = var.domain_name
  root_domain = var.root_domain

  # Wildcard for all subdomains
  subject_alternative_names = ["*.${var.root_domain}"]
}

# -----------------------------------------------------------------------------
# ALB Module (Internal - only accessible via API Gateway)
# -----------------------------------------------------------------------------
module "alb" {
  source = "./modules/alb"

  project     = "freebird"
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
  subnet_ids  = module.vpc.private_subnet_ids # Internal ALB in private subnets

  # 300s timeout for long-running SSE streaming requests
  idle_timeout = 300

  # Health check configuration
  health_check_path     = "/health"
  health_check_interval = 30
  health_check_timeout  = 10

  # SSL certificate
  certificate_arn = module.acm.certificate_arn
  enable_https    = true
}

# -----------------------------------------------------------------------------
# API Gateway Module (Public entry point)
# -----------------------------------------------------------------------------
module "api_gateway" {
  source = "./modules/api-gateway"

  project     = "freebird"
  environment = var.environment
  subnet_ids  = module.vpc.private_subnet_ids

  # ALB integration
  alb_listener_arn      = module.alb.https_listener_arn
  alb_security_group_id = module.alb.security_group_id

  # CORS - allow frontend origin
  cors_allow_origins = [var.frontend_url]

  # Custom domain
  domain_name     = var.domain_name
  certificate_arn = module.acm.certificate_arn

  # Rate limiting
  throttling_burst_limit = 1000
  throttling_rate_limit  = 500
}

# -----------------------------------------------------------------------------
# Route53 DNS Record (points domain to API Gateway)
# -----------------------------------------------------------------------------
data "aws_route53_zone" "main" {
  name         = var.root_domain
  private_zone = false
}

resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.api_gateway.custom_domain_name
    zone_id                = module.api_gateway.custom_domain_zone_id
    evaluate_target_health = false
  }
}

# -----------------------------------------------------------------------------
# EC2 Module (Nitro Enclave)
# -----------------------------------------------------------------------------
module "ec2" {
  source = "./modules/ec2"

  project       = "freebird"
  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
  subnet_ids    = module.vpc.private_subnet_ids
  instance_type = var.ec2_instance_type

  # Auto Scaling
  desired_count = var.ec2_desired_count
  min_count     = var.ec2_min_count
  max_count     = var.ec2_max_count

  # IAM
  instance_profile_name = module.iam.ec2_instance_profile_name

  # ALB
  target_group_arn = module.alb.target_group_arn
  alb_security_group_id = module.alb.security_group_id

  # Secrets
  secrets_arn_prefix = module.secrets.secrets_arn_prefix

  # Application configuration
  frontend_url = var.frontend_url
}
