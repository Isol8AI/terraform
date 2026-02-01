# =============================================================================
# KMS Module - Enclave Attestation
# =============================================================================
# Creates a KMS key with a policy that only allows decryption from attested
# Nitro Enclaves. This ensures only the enclave can decrypt the stored keypair.
#
# Attestation Flow:
# 1. Enclave requests decryption from KMS
# 2. KMS verifies PCR values in attestation document
# 3. Only if PCRs match, KMS performs decryption
# 4. Parent EC2 cannot use this key (no attestation)
# =============================================================================

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# KMS Key
# -----------------------------------------------------------------------------
resource "aws_kms_key" "enclave" {
  description             = "KMS key for Isol8 enclave keypair encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  # Policy WITHOUT attestation (dev / initial setup)
  policy = var.enable_attestation ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowRootFullAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowEC2Encrypt"
        Effect    = "Allow"
        Principal = { AWS = var.ec2_role_arn }
        Action    = ["kms:Encrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext"]
        Resource  = "*"
      },
      {
        Sid       = "AllowEnclaveDecrypt"
        Effect    = "Allow"
        Principal = { AWS = var.ec2_role_arn }
        Action    = ["kms:Decrypt"]
        Resource  = "*"
        Condition = {
          StringEqualsIgnoreCase = {
            "kms:RecipientAttestation:PCR0" = var.enclave_pcr0
            "kms:RecipientAttestation:PCR1" = var.enclave_pcr1
            "kms:RecipientAttestation:PCR2" = var.enclave_pcr2
          }
        }
      }
    ]
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowRootFullAccess"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowEC2Encrypt"
        Effect    = "Allow"
        Principal = { AWS = var.ec2_role_arn }
        Action    = ["kms:Encrypt", "kms:GenerateDataKey", "kms:GenerateDataKeyWithoutPlaintext"]
        Resource  = "*"
      },
      {
        Sid       = "AllowEnclaveDecrypt"
        Effect    = "Allow"
        Principal = { AWS = var.ec2_role_arn }
        Action    = ["kms:Decrypt"]
        Resource  = "*"
      }
    ]
  })

  tags = {
    Name = "${var.project}-${var.environment}-enclave-key"
  }
}

# -----------------------------------------------------------------------------
# KMS Alias
# -----------------------------------------------------------------------------
resource "aws_kms_alias" "enclave" {
  name          = "alias/${var.project}-${var.environment}-enclave"
  target_key_id = aws_kms_key.enclave.key_id
}
