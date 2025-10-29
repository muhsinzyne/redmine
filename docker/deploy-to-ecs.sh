#!/bin/bash
# Deploy Redmine to AWS ECS Fargate

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Configuration
AWS_REGION=${AWS_REGION:-us-east-1}
CLUSTER_NAME=${CLUSTER_NAME:-redmine-cluster}
SERVICE_NAME=${SERVICE_NAME:-redmine-service}
TASK_FAMILY=${TASK_FAMILY:-redmine-task}

echo "================================================"
echo "Deploy Redmine to AWS ECS Fargate"
echo "================================================"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install it first."
    exit 1
fi

# Check for required environment variables
if [ -z "$DB_HOST" ] || [ -z "$DB_PASSWORD" ] || [ -z "$SECRET_KEY_BASE" ]; then
    print_error "Missing required environment variables:"
    print_error "  DB_HOST, DB_PASSWORD, SECRET_KEY_BASE"
    print_error "Please set these before running the script"
    exit 1
fi

# Get AWS account ID
print_status "Getting AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/redmine-workproof:latest"

# Check if cluster exists
print_status "Checking if cluster exists..."
if ! aws ecs describe-clusters --clusters ${CLUSTER_NAME} --region ${AWS_REGION} --query 'clusters[0].status' --output text | grep -q ACTIVE; then
    print_warning "Cluster doesn't exist. Creating..."
    aws ecs create-cluster --cluster-name ${CLUSTER_NAME} --region ${AWS_REGION}
    print_status "Cluster created"
else
    print_status "Cluster exists"
fi

# Register task definition
print_status "Registering task definition..."
TASK_DEF=$(cat <<EOF
{
  "family": "${TASK_FAMILY}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "redmine",
      "image": "${ECR_IMAGE}",
      "essential": true,
      "portMappings": [{
        "containerPort": 3000,
        "protocol": "tcp"
      }],
      "environment": [
        {"name": "RAILS_ENV", "value": "production"},
        {"name": "DB_HOST", "value": "${DB_HOST}"},
        {"name": "DB_NAME", "value": "${DB_NAME:-redmine_production}"},
        {"name": "DB_USERNAME", "value": "${DB_USERNAME:-admin}"},
        {"name": "DB_PASSWORD", "value": "${DB_PASSWORD}"},
        {"name": "SECRET_KEY_BASE", "value": "${SECRET_KEY_BASE}"},
        {"name": "RAILS_SERVE_STATIC_FILES", "value": "true"},
        {"name": "RAILS_LOG_TO_STDOUT", "value": "true"}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/redmine",
          "awslogs-region": "${AWS_REGION}",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:3000/ || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF
)

echo "$TASK_DEF" > /tmp/task-definition.json
aws ecs register-task-definition \
    --cli-input-json file:///tmp/task-definition.json \
    --region ${AWS_REGION} > /dev/null
print_status "Task definition registered"

print_warning "Next steps:"
echo "1. Create an Application Load Balancer"
echo "2. Create a target group (port 3000)"
echo "3. Create ECS service with:"
echo ""
echo "aws ecs create-service \\"
echo "  --cluster ${CLUSTER_NAME} \\"
echo "  --service-name ${SERVICE_NAME} \\"
echo "  --task-definition ${TASK_FAMILY} \\"
echo "  --desired-count 2 \\"
echo "  --launch-type FARGATE \\"
echo "  --network-configuration 'awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-xxx],assignPublicIp=ENABLED}' \\"
echo "  --load-balancers 'targetGroupArn=arn:aws:elasticloadbalancing:...,containerName=redmine,containerPort=3000'"

echo ""
echo "================================================"
echo "Task Definition Registered!"
echo "================================================"

