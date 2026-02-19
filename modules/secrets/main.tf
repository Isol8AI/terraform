# =============================================================================
# Secrets Manager Module
# =============================================================================
# Stores application secrets encrypted with the KMS key.
# The enclave keypair is stored here, encrypted so only the enclave can decrypt.
# =============================================================================

# -----------------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "main" {
  for_each = var.secrets

  name       = "${var.project}/${var.environment}/${each.key}"
  kms_key_id = var.kms_key_arn

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}"
  }
}

resource "aws_secretsmanager_secret_version" "main" {
  for_each = { for k, v in var.secrets : k => v if nonsensitive(v) != "" }

  secret_id     = aws_secretsmanager_secret.main[each.key].id
  secret_string = each.value
}

# -----------------------------------------------------------------------------
# Enclave Keypair Secret
# This secret is created empty and populated by the enclave on first boot.
# Only the enclave can decrypt it (KMS attestation policy).
# -----------------------------------------------------------------------------
resource "aws_secretsmanager_secret" "enclave_keypair" {
  name       = "${var.project}/${var.environment}/enclave-keypair"
  kms_key_id = var.kms_key_arn

  description = "Encrypted X25519 keypair for enclave. Only attested enclave can decrypt."

  tags = {
    Name = "${var.project}-${var.environment}-enclave-keypair"
  }
}
