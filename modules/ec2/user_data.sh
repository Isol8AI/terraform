#!/bin/bash
# =============================================================================
# EC2 User Data Script - Isol8 Backend with Nitro Enclave
# =============================================================================
set -euo pipefail

# Variables from Terraform
PROJECT="${project}"
ENVIRONMENT="${environment}"
SECRETS_ARN_PREFIX="${secrets_arn_prefix}"
REGION="${aws_region}"
FRONTEND_URL="${frontend_url}"
ENCLAVE_BUCKET="${enclave_bucket_name}"

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

# Install Nitro CLI
amazon-linux-extras install aws-nitro-enclaves-cli -y
yum install -y aws-nitro-enclaves-cli-devel

# Configure enclave allocator
cat > /etc/nitro_enclaves/allocator.yaml << 'EOF'
---
# 2GB memory for enclave (adjust based on model requirements)
memory_mib: 2048
# 2 CPUs for enclave
cpu_count: 2
EOF

# Start Nitro Enclave allocator
systemctl start nitro-enclaves-allocator
systemctl enable nitro-enclaves-allocator

# Add ec2-user to docker and ne groups
usermod -aG docker ec2-user
usermod -aG ne ec2-user

# -----------------------------------------------------------------------------
# Download Enclave files from S3 (source + EIF if available)
# -----------------------------------------------------------------------------
ENCLAVE_DIR="/home/ec2-user/enclave"
mkdir -p "$ENCLAVE_DIR"
chown ec2-user:ec2-user "$ENCLAVE_DIR"

if [ -n "$ENCLAVE_BUCKET" ]; then
    echo "Downloading enclave source files from S3..."
    aws s3 sync "s3://$ENCLAVE_BUCKET/$ENVIRONMENT/source/" "$ENCLAVE_DIR/" --region "$REGION" || echo "No enclave source in S3 yet"

    echo "Downloading enclave EIF from S3..."
    aws s3 cp "s3://$ENCLAVE_BUCKET/$ENVIRONMENT/enclave.eif" "$ENCLAVE_DIR/enclave.eif" --region "$REGION" || echo "No EIF found in S3 - will build from source"

    # Build EIF from source if it doesn't exist but Dockerfile does
    if [ ! -f "$ENCLAVE_DIR/enclave.eif" ] && [ -f "$ENCLAVE_DIR/Dockerfile.enclave" ]; then
        echo "Building enclave EIF from source (this may take a few minutes)..."
        cd "$ENCLAVE_DIR"
        docker build -t isol8-enclave:latest -f Dockerfile.enclave .

        # Set required environment variable for nitro-cli
        export NITRO_CLI_ARTIFACTS=/var/lib/nitro_enclaves

        nitro-cli build-enclave --docker-uri isol8-enclave:latest --output-file "$ENCLAVE_DIR/enclave.eif"
        echo "EIF built successfully!"

        # Upload the built EIF to S3 for future instances
        aws s3 cp "$ENCLAVE_DIR/enclave.eif" "s3://$ENCLAVE_BUCKET/$ENVIRONMENT/enclave.eif" --region "$REGION" && \
            echo "EIF uploaded to S3 for future instances" || \
            echo "Could not upload EIF to S3 (non-fatal)"
        cd /
    fi

    chown -R ec2-user:ec2-user "$ENCLAVE_DIR"

    # Install parent-side Python dependencies
    if [ -f "$ENCLAVE_DIR/requirements-parent.txt" ]; then
        echo "Installing parent-side Python dependencies..."
        python3 -m pip install -r "$ENCLAVE_DIR/requirements-parent.txt"
    fi

    # Create vsock-proxy systemd service (for enclave outbound HTTPS)
    if [ -f "$ENCLAVE_DIR/vsock_proxy.py" ]; then
        echo "Creating vsock-proxy systemd service..."
        cat > /etc/systemd/system/vsock-proxy.service << 'EOFSERVICE'
[Unit]
Description=vsock Proxy for Nitro Enclave
After=network.target nitro-enclaves-allocator.service

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/home/ec2-user/enclave
ExecStart=/usr/bin/python3 /home/ec2-user/enclave/vsock_proxy.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOFSERVICE
        systemctl daemon-reload
        systemctl enable vsock-proxy
        systemctl start vsock-proxy
        echo "vsock-proxy service started"
    fi

    # Create enclave systemd service (runs the Nitro Enclave)
    if [ -f "$ENCLAVE_DIR/enclave.eif" ]; then
        echo "Creating nitro-enclave systemd service..."
        cat > /etc/systemd/system/nitro-enclave.service << 'EOFSERVICE'
[Unit]
Description=Nitro Enclave for Isol8
After=nitro-enclaves-allocator.service vsock-proxy.service
Requires=nitro-enclaves-allocator.service

[Service]
Type=simple
User=root
ExecStartPre=-/usr/bin/nitro-cli terminate-enclave --all
ExecStart=/usr/bin/nitro-cli run-enclave --eif-path /home/ec2-user/enclave/enclave.eif --cpu-count 2 --memory 2048 --attach-console
ExecStop=/usr/bin/nitro-cli terminate-enclave --all
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOFSERVICE
        systemctl daemon-reload
        systemctl enable nitro-enclave
        systemctl start nitro-enclave
        echo "Nitro enclave service started"

        # Wait for enclave to be ready (up to 2 minutes)
        echo "Waiting for enclave to start..."
        ENCLAVE_CID=""
        for i in $(seq 1 24); do
            ENCLAVE_CID=$(nitro-cli describe-enclaves 2>/dev/null | jq -r '.[0].EnclaveCID // empty')
            if [ -n "$ENCLAVE_CID" ]; then
                echo "Enclave started with CID: $ENCLAVE_CID (attempt $i)"
                break
            fi
            echo "Waiting for enclave... (attempt $i/24)"
            sleep 5
        done

        if [ -z "$ENCLAVE_CID" ]; then
            echo "ERROR: Enclave failed to start within 2 minutes"
            systemctl status nitro-enclave --no-pager || true
        fi
    else
        echo "No enclave.eif found - will use MockEnclave"
    fi
fi

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

# -----------------------------------------------------------------------------
# Create environment file
# -----------------------------------------------------------------------------
# Use real Nitro Enclave if EIF exists, otherwise fall back to mock
# Get the enclave CID if enclave is running
ENCLAVE_CID_VALUE=""
if [ -f "/home/ec2-user/enclave/enclave.eif" ]; then
    ENCLAVE_MODE_VALUE="nitro"
    echo "EIF found - using real Nitro Enclave"
    # Get the CID from the running enclave (retry if needed)
    for i in $(seq 1 12); do
        ENCLAVE_CID_VALUE=$(nitro-cli describe-enclaves 2>/dev/null | jq -r '.[0].EnclaveCID // empty')
        if [ -n "$ENCLAVE_CID_VALUE" ]; then
            echo "Enclave CID for .env: $ENCLAVE_CID_VALUE"
            break
        fi
        echo "Waiting for enclave CID... ($i/12)"
        sleep 5
    done
    if [ -z "$ENCLAVE_CID_VALUE" ]; then
        echo "ERROR: Could not get enclave CID after 60s - container will fail to connect"
    fi
else
    ENCLAVE_MODE_VALUE="mock"
    echo "No EIF found - using MockEnclave"
fi

cat > /home/ec2-user/.env << EOF
DATABASE_URL=$DATABASE_URL
OM_METADATA_BACKEND=postgres
OM_PG_DSN=$OM_PG_DSN
OM_PG_SCHEMA=$ENVIRONMENT
HUGGINGFACE_TOKEN=$HUGGINGFACE_TOKEN
CLERK_ISSUER=$CLERK_ISSUER
CLERK_WEBHOOK_SECRET=$CLERK_WEBHOOK_SECRET
CORS_ORIGINS=$FRONTEND_URL
ENVIRONMENT=$ENVIRONMENT
DEBUG=false
ENCLAVE_MODE=$ENCLAVE_MODE_VALUE
ENCLAVE_CID=$ENCLAVE_CID_VALUE
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
    --device /dev/vsock \
    --privileged \
    -p 8000:8000 \
    $ECR_REPO:latest

[Install]
WantedBy=multi-user.target
EOF

# Reload and start service
systemctl daemon-reload
systemctl enable isol8
systemctl start isol8

echo "Isol8 backend setup complete!"
