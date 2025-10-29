# Docker Deployment Guide for Redmine

Complete guide for deploying Redmine with Docker on AWS (ECS, EKS, Fargate) and locally.

---

## Table of Contents
1. [Local Docker Development](#local-docker-development)
2. [AWS ECS with Fargate](#aws-ecs-with-fargate-recommended)
3. [AWS ECS with EC2](#aws-ecs-with-ec2)
4. [AWS EKS (Kubernetes)](#aws-eks-kubernetes)
5. [Docker Hub / ECR Setup](#docker-hub--ecr-setup)
6. [Environment Variables](#environment-variables)
7. [Troubleshooting](#troubleshooting)

---

## Local Docker Development

### Quick Start

```bash
# 1. Create environment file
cp .env.production.template .env

# 2. Edit .env with your values
nano .env

# 3. Generate secret key
docker run --rm ruby:2.7.8-slim \
  sh -c "gem install bundler && bundle exec rake secret" > secret.txt

# 4. Add secret to .env
echo "SECRET_KEY_BASE=$(cat secret.txt)" >> .env

# 5. Build and run
docker-compose up -d

# 6. Run migrations (first time only)
docker-compose exec redmine bundle exec rake db:migrate
docker-compose exec redmine bundle exec rake redmine:load_default_data REDMINE_LANG=en

# 7. Access Redmine
open http://localhost
```

### Environment File (.env)

```bash
# Database
DB_ROOT_PASSWORD=strongrootpassword
DB_NAME=redmine_production
DB_USERNAME=redmine
DB_PASSWORD=securepassword

# Application
SECRET_KEY_BASE=your-generated-secret-key-here
```

### Useful Commands

```bash
# View logs
docker-compose logs -f redmine

# Stop services
docker-compose down

# Rebuild after code changes
docker-compose up -d --build

# Access container shell
docker-compose exec redmine bash

# Database backup
docker-compose exec mysql mysqldump -u root -p redmine_production > backup.sql

# Database restore
docker-compose exec -T mysql mysql -u root -p redmine_production < backup.sql
```

---

## AWS ECS with Fargate (Recommended)

Fully managed container deployment without managing servers.

### Architecture
```
Internet → ALB → ECS Fargate Tasks → RDS MySQL
```

### Prerequisites
- AWS CLI installed and configured
- Docker installed locally
- AWS account with appropriate permissions

### Step 1: Create ECR Repository

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name redmine-workproof \
  --region us-east-1

# Get ECR login
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

### Step 2: Build and Push Docker Image

```bash
# Build image
docker build -t redmine-workproof:latest .

# Tag for ECR
docker tag redmine-workproof:latest \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest

# Push to ECR
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest
```

### Step 3: Create RDS MySQL Database

```bash
# Using AWS Console:
1. Go to RDS → Create database
2. Engine: MySQL 8.0
3. Template: Free tier (or Production)
4. DB instance identifier: redmine-db
5. Master username: admin
6. Master password: [secure password]
7. DB instance class: db.t3.micro (or larger)
8. Storage: 20 GB
9. VPC: Default (or custom)
10. Public access: No
11. Database name: redmine_production
12. Create database
```

### Step 4: Create ECS Cluster

```bash
# Create cluster
aws ecs create-cluster \
  --cluster-name redmine-cluster \
  --region us-east-1
```

### Step 5: Create Task Definition

Create `ecs-task-definition.json`:

```json
{
  "family": "redmine-task",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::ACCOUNT_ID:role/ecsTaskExecutionRole",
  "containerDefinitions": [
    {
      "name": "redmine",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "RAILS_ENV",
          "value": "production"
        },
        {
          "name": "DB_HOST",
          "value": "your-rds-endpoint.rds.amazonaws.com"
        },
        {
          "name": "DB_NAME",
          "value": "redmine_production"
        },
        {
          "name": "DB_USERNAME",
          "value": "admin"
        },
        {
          "name": "RAILS_SERVE_STATIC_FILES",
          "value": "true"
        },
        {
          "name": "RAILS_LOG_TO_STDOUT",
          "value": "true"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:redmine-db-password"
        },
        {
          "name": "SECRET_KEY_BASE",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:ACCOUNT_ID:secret:redmine-secret-key"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/redmine",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
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
```

Register task definition:

```bash
# Create CloudWatch log group
aws logs create-log-group \
  --log-group-name /ecs/redmine \
  --region us-east-1

# Register task definition
aws ecs register-task-definition \
  --cli-input-json file://ecs-task-definition.json
```

### Step 6: Create Application Load Balancer

```bash
# Using AWS Console:
1. EC2 → Load Balancers → Create Load Balancer
2. Choose Application Load Balancer
3. Name: redmine-alb
4. Scheme: Internet-facing
5. IP address type: IPv4
6. Availability Zones: Select at least 2
7. Security group: Create new (allow HTTP/HTTPS)
8. Target group: Create new
   - Name: redmine-targets
   - Target type: IP
   - Protocol: HTTP
   - Port: 3000
   - Health check path: /
9. Create load balancer
```

### Step 7: Create ECS Service

```bash
# Create service
aws ecs create-service \
  --cluster redmine-cluster \
  --service-name redmine-service \
  --task-definition redmine-task \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx,subnet-yyy],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:ACCOUNT_ID:targetgroup/redmine-targets/xxx,containerName=redmine,containerPort=3000"
```

### Step 8: Run Database Migrations

```bash
# Run one-off task for migrations
aws ecs run-task \
  --cluster redmine-cluster \
  --task-definition redmine-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "redmine",
      "command": ["bundle", "exec", "rake", "db:migrate"]
    }]
  }'

# Load default data (first time only)
aws ecs run-task \
  --cluster redmine-cluster \
  --task-definition redmine-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --overrides '{
    "containerOverrides": [{
      "name": "redmine",
      "command": ["bundle", "exec", "rake", "redmine:load_default_data", "REDMINE_LANG=en"]
    }]
  }'
```

### Cost Estimate (Fargate)
- ECS Fargate (512 CPU, 1GB RAM, 2 tasks): ~$25/month
- RDS db.t3.micro: ~$15/month
- Application Load Balancer: ~$15/month
- Data transfer: ~$10/month
- **Total: ~$65/month**

---

## AWS ECS with EC2

Run containers on EC2 instances for more control and lower cost.

### Step 1-3: Same as Fargate (ECR, Build, RDS)

### Step 4: Create ECS Cluster with EC2

```bash
# Create cluster with EC2 instances
aws ecs create-cluster \
  --cluster-name redmine-ec2-cluster \
  --region us-east-1

# Launch EC2 instances with ECS optimized AMI
# (Do this through EC2 console or CloudFormation)
# AMI: Amazon ECS-Optimized Amazon Linux 2
# Instance type: t3.small
# User data:
```

User data script:
```bash
#!/bin/bash
echo ECS_CLUSTER=redmine-ec2-cluster >> /etc/ecs/ecs.config
```

### Step 5: Create Task Definition (EC2 mode)

Same as Fargate but remove `requiresCompatibilities` and `networkMode`, change launch type:

```json
{
  "family": "redmine-ec2-task",
  "containerDefinitions": [
    {
      "name": "redmine",
      "image": "ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest",
      "memory": 512,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 0,
          "protocol": "tcp"
        }
      ]
      // ... rest same as Fargate
    }
  ]
}
```

### Cost Estimate (EC2)
- EC2 t3.small (2 instances): ~$30/month
- RDS db.t3.micro: ~$15/month
- Application Load Balancer: ~$15/month
- **Total: ~$60/month**

---

## AWS EKS (Kubernetes)

Enterprise-grade container orchestration.

### Prerequisites
- kubectl installed
- eksctl installed
- Helm installed (optional)

### Step 1: Create EKS Cluster

```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create cluster
eksctl create cluster \
  --name redmine-cluster \
  --region us-east-1 \
  --nodegroup-name redmine-nodes \
  --node-type t3.small \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3
```

### Step 2: Create Kubernetes Manifests

Create `k8s/namespace.yaml`:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: redmine
```

Create `k8s/secrets.yaml`:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: redmine-secrets
  namespace: redmine
type: Opaque
stringData:
  DB_PASSWORD: "your-db-password"
  SECRET_KEY_BASE: "your-secret-key-base"
```

Create `k8s/deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redmine
  namespace: redmine
spec:
  replicas: 2
  selector:
    matchLabels:
      app: redmine
  template:
    metadata:
      labels:
        app: redmine
    spec:
      containers:
      - name: redmine
        image: ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: "production"
        - name: DB_HOST
          value: "your-rds-endpoint.rds.amazonaws.com"
        - name: DB_NAME
          value: "redmine_production"
        - name: DB_USERNAME
          value: "admin"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redmine-secrets
              key: DB_PASSWORD
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: redmine-secrets
              key: SECRET_KEY_BASE
        - name: RAILS_SERVE_STATIC_FILES
          value: "true"
        - name: RAILS_LOG_TO_STDOUT
          value: "true"
        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

Create `k8s/service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: redmine
  namespace: redmine
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 3000
  selector:
    app: redmine
```

### Step 3: Deploy to EKS

```bash
# Apply manifests
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Check status
kubectl get pods -n redmine
kubectl get svc -n redmine

# Run migrations (one-off job)
kubectl run -n redmine migration \
  --image=ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest \
  --restart=Never \
  --command -- bundle exec rake db:migrate

# View logs
kubectl logs -n redmine -l app=redmine
```

### Cost Estimate (EKS)
- EKS cluster: ~$73/month
- EC2 t3.small nodes (2): ~$30/month
- RDS db.t3.micro: ~$15/month
- Load Balancer: ~$15/month
- **Total: ~$133/month**

---

## Docker Hub / ECR Setup

### Docker Hub

```bash
# Login to Docker Hub
docker login

# Tag image
docker tag redmine-workproof:latest yourusername/redmine-workproof:latest

# Push to Docker Hub
docker push yourusername/redmine-workproof:latest
```

### AWS ECR

```bash
# Create repository
aws ecr create-repository --repository-name redmine-workproof

# Get login command
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Tag and push
docker tag redmine-workproof:latest \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest
docker push ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/redmine-workproof:latest
```

---

## Environment Variables

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `RAILS_ENV` | Rails environment | `production` |
| `DB_HOST` | Database host | `mysql` or RDS endpoint |
| `DB_NAME` | Database name | `redmine_production` |
| `DB_USERNAME` | Database user | `redmine` |
| `DB_PASSWORD` | Database password | `securepassword` |
| `SECRET_KEY_BASE` | Rails secret key | Generate with `rake secret` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RAILS_SERVE_STATIC_FILES` | Serve static files | `false` |
| `RAILS_LOG_TO_STDOUT` | Log to stdout | `false` |
| `RAILS_MAX_THREADS` | Puma threads | `5` |
| `WEB_CONCURRENCY` | Puma workers | `2` |

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs redmine-container-id

# Common issues:
# 1. Database not accessible
# 2. Missing SECRET_KEY_BASE
# 3. Database not migrated
```

### Database Connection Issues

```bash
# Test database connection
docker run --rm -it mysql:8.0 \
  mysql -h YOUR_DB_HOST -u redmine -p

# Check security groups allow MySQL port 3306
```

### Run Migrations

```bash
# Docker Compose
docker-compose exec redmine bundle exec rake db:migrate

# ECS Fargate
aws ecs run-task --cluster redmine-cluster --task-definition redmine-task \
  --overrides '{"containerOverrides":[{"name":"redmine","command":["bundle","exec","rake","db:migrate"]}]}'

# EKS
kubectl run -n redmine migration \
  --image=your-image \
  --restart=Never \
  --command -- bundle exec rake db:migrate
```

### Check Container Health

```bash
# Docker
docker inspect --format='{{.State.Health.Status}}' container-id

# ECS
aws ecs describe-tasks --cluster redmine-cluster --tasks task-arn

# EKS
kubectl get pods -n redmine
kubectl describe pod pod-name -n redmine
```

---

## Quick Comparison

| Option | Cost | Complexity | Scalability | Best For |
|--------|------|------------|-------------|----------|
| **Local Docker** | Free | ⭐ Easy | Manual | Development |
| **ECS Fargate** | ~$65/mo | ⭐⭐ Moderate | Auto | Production (managed) |
| **ECS EC2** | ~$60/mo | ⭐⭐⭐ Complex | Manual | Cost-effective |
| **EKS** | ~$133/mo | ⭐⭐⭐⭐ Complex | Auto | Enterprise |

---

## Recommended Deployment

**For most use cases: AWS ECS with Fargate**
- Fully managed (no servers to maintain)
- Auto-scaling built-in
- Good balance of cost and complexity
- Production-ready

**Start here:**
1. Build Docker image
2. Push to ECR
3. Create RDS database
4. Deploy to ECS Fargate
5. Set up ALB
6. Configure domain and SSL

See detailed steps in [AWS ECS with Fargate](#aws-ecs-with-fargate-recommended) section above.

