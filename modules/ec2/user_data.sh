#!/bin/bash
# =============================================================================
# EC2 User Data Script - Isol8 Backend with OpenClaw Gateway
# =============================================================================
set -euo pipefail

# Variables from Terraform
PROJECT="${project}"
ENVIRONMENT="${environment}"
SECRETS_ARN_PREFIX="${secrets_arn_prefix}"
REGION="${aws_region}"
FRONTEND_URL="${frontend_url}"
TOWN_FRONTEND_URL="${town_frontend_url}"
WS_CONNECTIONS_TABLE="${ws_connections_table}"
WS_MANAGEMENT_API_URL="${ws_management_api_url}"

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting Isol8 backend setup..."

# -----------------------------------------------------------------------------
# Install dependencies
# -----------------------------------------------------------------------------
yum update -y
amazon-linux-extras install docker -y
amazon-linux-extras install python3.8 -y
yum install -y aws-cli jq gcc python38-devel libffi-devel openssl-devel

# Upgrade pip for Python on host
python3 -m pip install --upgrade pip

# Start Docker
systemctl start docker
systemctl enable docker

# Start SSM agent (pre-installed on Amazon Linux 2, needed for GitHub Actions deployments)
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Add ec2-user to docker group
usermod -aG docker ec2-user

# -----------------------------------------------------------------------------
# Set up OpenClaw gateway workspace
# -----------------------------------------------------------------------------
echo "Setting up OpenClaw gateway workspace..."
mkdir -p /var/lib/isol8/gateway-workspace
chown ec2-user:ec2-user /var/lib/isol8/gateway-workspace

# -----------------------------------------------------------------------------
# Fetch secrets from Secrets Manager
# -----------------------------------------------------------------------------
echo "Fetching secrets from region: $REGION"

# Fetch secrets
DATABASE_URL=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}database_url" \
    --query 'SecretString' --output text)

HUGGINGFACE_TOKEN=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}huggingface_token" \
    --query 'SecretString' --output text)

CLERK_ISSUER=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}clerk_issuer" \
    --query 'SecretString' --output text)

CLERK_WEBHOOK_SECRET=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}clerk_webhook_secret" \
    --query 'SecretString' --output text)

OM_PG_DSN=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}openmemory_url" \
    --query 'SecretString' --output text)

STRIPE_SECRET_KEY=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}stripe_secret_key" \
    --query 'SecretString' --output text 2>/dev/null || echo "")

STRIPE_WEBHOOK_SECRET=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}stripe_webhook_secret" \
    --query 'SecretString' --output text 2>/dev/null || echo "")

BRAVE_API_KEY=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$${SECRETS_ARN_PREFIX}brave_api_key" \
    --query 'SecretString' --output text 2>/dev/null || echo "")

# -----------------------------------------------------------------------------
# Create environment file
# -----------------------------------------------------------------------------
cat > /home/ec2-user/.env << EOF
DATABASE_URL=$DATABASE_URL
OM_METADATA_BACKEND=postgres
OM_PG_DSN=$OM_PG_DSN
OM_PG_SCHEMA=$ENVIRONMENT
HUGGINGFACE_TOKEN=$HUGGINGFACE_TOKEN
CLERK_ISSUER=$CLERK_ISSUER
CLERK_WEBHOOK_SECRET=$CLERK_WEBHOOK_SECRET
CORS_ORIGINS=$FRONTEND_URL,$TOWN_FRONTEND_URL
ENVIRONMENT=$ENVIRONMENT
DEBUG=false
GATEWAY_WORKSPACE=/var/lib/isol8/gateway-workspace
WS_CONNECTIONS_TABLE=$WS_CONNECTIONS_TABLE
WS_MANAGEMENT_API_URL=$WS_MANAGEMENT_API_URL
AWS_REGION=$REGION
AWS_DEFAULT_REGION=$REGION
STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY
STRIPE_WEBHOOK_SECRET=$STRIPE_WEBHOOK_SECRET
BRAVE_API_KEY=$BRAVE_API_KEY
EOF

chmod 600 /home/ec2-user/.env
chown ec2-user:ec2-user /home/ec2-user/.env

# -----------------------------------------------------------------------------
# Login to ECR and pull image
# -----------------------------------------------------------------------------
echo "Pulling container image..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$PROJECT-backend"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REPO"
docker pull "$ECR_REPO:latest" || docker pull "$ECR_REPO:$ENVIRONMENT" || true

# -----------------------------------------------------------------------------
# Start the application
# -----------------------------------------------------------------------------
echo "Starting application..."

# Create systemd service
cat > /etc/systemd/system/isol8.service << EOF
[Unit]
Description=Isol8 Backend
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=5
ExecStart=/usr/bin/docker run --rm \
    --name isol8 \
    --env-file /home/ec2-user/.env \
    -v /var/lib/isol8/gateway-workspace:/var/lib/isol8/gateway-workspace \
    --network=host \
    $ECR_REPO:latest

[Install]
WantedBy=multi-user.target
EOF

# Reload and start service
systemctl daemon-reload
systemctl enable isol8
systemctl start isol8

echo "Isol8 backend setup complete!"
