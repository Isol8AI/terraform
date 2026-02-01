# =============================================================================
# IAM Module
# =============================================================================
# Creates IAM roles for:
# 1. EC2 instances (to access Secrets Manager and KMS)
# 2. GitHub Actions (OIDC for CI/CD deployments)
# =============================================================================

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# EC2 Role (for Nitro Enclave instances)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-${var.environment}-ec2-role"
  }
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# EC2 Policy - Secrets Manager access
resource "aws_iam_role_policy" "ec2_secrets" {
  name = "secrets-access"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "${var.secrets_arn_prefix}*"
      }
    ]
  })
}

# EC2 Policy - KMS access (for attestation)
resource "aws_iam_role_policy" "ec2_kms" {
  name = "kms-access"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

# EC2 Policy - CloudWatch Logs
resource "aws_iam_role_policy" "ec2_logs" {
  name = "cloudwatch-logs"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/isol8/*"
      }
    ]
  })
}

# EC2 Policy - ECR access (for pulling container images)
resource "aws_iam_role_policy" "ec2_ecr" {
  name = "ecr-access"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "*"
      }
    ]
  })
}

# EC2 Policy - AWS Bedrock access (for LLM inference)
resource "aws_iam_role_policy" "ec2_bedrock" {
  name = "bedrock-access"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = [
          # Foundation models (direct invocation)
          "arn:aws:bedrock:*::foundation-model/*",
          # Inference profiles (required for on-demand throughput)
          "arn:aws:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
          # System-defined inference profiles (us., eu., apac. prefixes)
          "arn:aws:bedrock:*:*:inference-profile/*",
        ]
      }
    ]
  })
}

# EC2 Policy - SSM access (for GitHub Actions deployments via SSM)
resource "aws_iam_role_policy" "ec2_ssm" {
  name = "ssm-access"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply",
        ]
        Resource = "*"
      }
    ]
  })
}

# EC2 Policy - S3 access for enclave artifacts
resource "aws_iam_role_policy" "ec2_s3_enclave" {
  name = "s3-enclave-artifacts"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-enclave-artifacts-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::${var.project}-enclave-artifacts-${data.aws_caller_identity.current.account_id}/*"
        ]
      }
    ]
  })
}

# EC2 Policy - API Gateway Management API (for WebSocket push)
resource "aws_iam_role_policy" "ec2_websocket" {
  count = var.websocket_api_arn != "" ? 1 : 0

  name = "websocket-management-api"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections"
        ]
        Resource = "${var.websocket_api_arn}/*"
      }
    ]
  })
}

# EC2 Policy - DynamoDB access for WebSocket connections
resource "aws_iam_role_policy" "ec2_websocket_dynamodb" {
  count = var.ws_connections_table_arn != "" ? 1 : 0

  name = "websocket-dynamodb"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
        ]
        Resource = var.ws_connections_table_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# GitHub Actions OIDC Provider (use existing one created by bootstrap)
# -----------------------------------------------------------------------------
data "aws_iam_openid_connect_provider" "github" {
  count = var.github_org != "" && length(var.github_repos) > 0 ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

# GitHub Actions Role
resource "aws_iam_role" "github_actions" {
  count = var.github_org != "" && length(var.github_repos) > 0 ? 1 : 0

  name = "${var.project}-${var.environment}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Trust multiple repos from the same org
            "token.actions.githubusercontent.com:sub" = [
              for repo in var.github_repos : "repo:${var.github_org}/${repo}:*"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project}-${var.environment}-github-actions"
  }
}

# GitHub Actions Policy - ECR push
resource "aws_iam_role_policy" "github_ecr" {
  count = var.github_org != "" && length(var.github_repos) > 0 ? 1 : 0

  name = "ecr-push"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = "arn:aws:ecr:*:${data.aws_caller_identity.current.account_id}:repository/${var.project}-*"
      }
    ]
  })
}

# GitHub Actions Policy - EC2 deployment
resource "aws_iam_role_policy" "github_ec2" {
  count = var.github_org != "" && length(var.github_repos) > 0 ? 1 : 0

  name = "ec2-deploy"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:StartInstanceRefresh",
          "autoscaling:DescribeInstanceRefreshes",
          "autoscaling:DescribeAutoScalingGroups",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
        ]
        Resource = "*"
      }
    ]
  })
}

# GitHub Actions Policy - Terraform state management (S3 + DynamoDB)
resource "aws_iam_role_policy" "github_terraform" {
  count = var.github_org != "" && length(var.github_repos) > 0 ? 1 : 0

  name = "terraform-state"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-terraform-state-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::${var.project}-terraform-state-${data.aws_caller_identity.current.account_id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/${var.project}-terraform-locks"
      }
    ]
  })
}

# GitHub Actions Policy - S3 enclave artifacts upload
resource "aws_iam_role_policy" "github_s3_enclave" {
  count = var.github_org != "" && length(var.github_repos) > 0 ? 1 : 0

  name = "s3-enclave-artifacts"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.project}-enclave-artifacts-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::${var.project}-enclave-artifacts-${data.aws_caller_identity.current.account_id}/*"
        ]
      }
    ]
  })
}

# GitHub Actions Policy - Full Terraform permissions for infrastructure management
resource "aws_iam_role_policy" "github_terraform_infra" {
  count = var.github_org != "" && length(var.github_repos) > 0 ? 1 : 0

  name = "terraform-infrastructure"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2Full"
        Effect = "Allow"
        Action = [
          "ec2:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "VPCFull"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:ModifyVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
        ]
        Resource = "*"
      },
      {
        Sid    = "ELBFull"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "APIGatewayFull"
        Effect = "Allow"
        Action = [
          "apigateway:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:ListAttachedRolePolicies",
          "iam:ListRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:ListOpenIDConnectProviders",
          "iam:GetOpenIDConnectProvider",
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSFull"
        Effect = "Allow"
        Action = [
          "kms:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "SecretsManagerFull"
        Effect = "Allow"
        Action = [
          "secretsmanager:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "ACMFull"
        Effect = "Allow"
        Action = [
          "acm:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53Full"
        Effect = "Allow"
        Action = [
          "route53:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogsFull"
        Effect = "Allow"
        Action = [
          "logs:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "AutoScalingFull"
        Effect = "Allow"
        Action = [
          "autoscaling:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Full"
        Effect = "Allow"
        Action = [
          "s3:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaFull"
        Effect = "Allow"
        Action = [
          "lambda:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "DynamoDBFull"
        Effect = "Allow"
        Action = [
          "dynamodb:*",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMTagRole"
        Effect = "Allow"
        Action = [
          "iam:TagRole",
          "iam:UntagRole",
        ]
        Resource = "*"
      }
    ]
  })
}
