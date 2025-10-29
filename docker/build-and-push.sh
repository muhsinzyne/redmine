#!/bin/bash
# Build and push Docker image to AWS ECR

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
ECR_REPOSITORY=${ECR_REPOSITORY:-redmine-workproof}
IMAGE_TAG=${IMAGE_TAG:-latest}

echo "================================================"
echo "Build and Push Docker Image to ECR"
echo "================================================"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install it first."
    exit 1
fi

# Get AWS account ID
print_status "Getting AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
print_status "AWS Account ID: $AWS_ACCOUNT_ID"

# ECR repository URL
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE_NAME="${ECR_URL}/${ECR_REPOSITORY}:${IMAGE_TAG}"

# Check if repository exists, create if not
print_status "Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names ${ECR_REPOSITORY} --region ${AWS_REGION} &> /dev/null; then
    print_warning "Repository doesn't exist. Creating..."
    aws ecr create-repository \
        --repository-name ${ECR_REPOSITORY} \
        --region ${AWS_REGION}
    print_status "Repository created"
else
    print_status "Repository exists"
fi

# Login to ECR
print_status "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_URL}

# Build Docker image
print_status "Building Docker image..."
docker build -t ${ECR_REPOSITORY}:${IMAGE_TAG} .

# Tag for ECR
print_status "Tagging image for ECR..."
docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${FULL_IMAGE_NAME}

# Push to ECR
print_status "Pushing image to ECR..."
docker push ${FULL_IMAGE_NAME}

print_status "Image successfully pushed!"
print_warning "Image URL: ${FULL_IMAGE_NAME}"
print_warning "Use this URL in your ECS task definition or Kubernetes manifests"

# Also tag and push as 'latest'
if [ "${IMAGE_TAG}" != "latest" ]; then
    LATEST_IMAGE="${ECR_URL}/${ECR_REPOSITORY}:latest"
    print_status "Tagging as latest..."
    docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${LATEST_IMAGE}
    docker push ${LATEST_IMAGE}
    print_status "Also pushed as: ${LATEST_IMAGE}"
fi

echo ""
echo "================================================"
echo "Build and Push Complete!"
echo "================================================"

