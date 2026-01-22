# =============================================================================
# KMS Module - Variables
# =============================================================================

variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ec2_role_arn" {
  description = "ARN of the EC2 IAM role that hosts the enclave"
  type        = string
}

# -----------------------------------------------------------------------------
# Attestation PCR Values
# These are set after building the enclave image for the first time.
# Get them with: nitro-cli describe-eif --eif-path enclave.eif
# -----------------------------------------------------------------------------

variable "enable_attestation" {
  description = "Enable PCR attestation validation (disable for initial setup)"
  type        = bool
  default     = false
}

variable "enclave_pcr0" {
  description = "PCR0: Hash of enclave image file"
  type        = string
  default     = ""
}

variable "enclave_pcr1" {
  description = "PCR1: Hash of Linux kernel and boot ramfs"
  type        = string
  default     = ""
}

variable "enclave_pcr2" {
  description = "PCR2: Hash of application inside enclave"
  type        = string
  default     = ""
}
