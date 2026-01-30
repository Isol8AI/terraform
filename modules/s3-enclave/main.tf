# =============================================================================
# S3 Enclave Artifacts Module
# =============================================================================
# Stores Nitro Enclave EIF files built by CI/CD and pulled by EC2 instances.
# =============================================================================

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# S3 Bucket for Enclave Artifacts
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "enclave_artifacts" {
  bucket = "${var.project}-enclave-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project}-enclave-artifacts"
    Project     = var.project
    Environment = var.environment
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "enclave_artifacts" {
  bucket = aws_s3_bucket.enclave_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for rollback capability
resource "aws_s3_bucket_versioning" "enclave_artifacts" {
  bucket = aws_s3_bucket.enclave_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "enclave_artifacts" {
  bucket = aws_s3_bucket.enclave_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# Lifecycle rule to clean up old versions
resource "aws_s3_bucket_lifecycle_configuration" "enclave_artifacts" {
  bucket = aws_s3_bucket.enclave_artifacts.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Clean up incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

# -----------------------------------------------------------------------------
# Bucket Policy - Allow EC2 and GitHub Actions access
# -----------------------------------------------------------------------------
resource "aws_s3_bucket_policy" "enclave_artifacts" {
  bucket = aws_s3_bucket.enclave_artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Read"
        Effect = "Allow"
        Principal = {
          AWS = var.ec2_role_arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.enclave_artifacts.arn,
          "${aws_s3_bucket.enclave_artifacts.arn}/*"
        ]
      },
      {
        Sid    = "AllowGitHubActionsWrite"
        Effect = "Allow"
        Principal = {
          AWS = var.github_actions_role_arn
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.enclave_artifacts.arn,
          "${aws_s3_bucket.enclave_artifacts.arn}/*"
        ]
      }
    ]
  })
}
