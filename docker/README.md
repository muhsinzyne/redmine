# Docker Deployment for Redmine

Quick guide for Docker-based deployment options.

---

## 🚀 Quick Start Options

### Option 1: Local Development (Fastest)
```bash
# 1. Start services
docker-compose up -d

# 2. Run migrations (first time)
docker-compose exec redmine bundle exec rake db:migrate
docker-compose exec redmine bundle exec rake redmine:load_default_data REDMINE_LANG=en

# 3. Access
open http://localhost
```

### Option 2: AWS ECS Fargate (Production)
```bash
# 1. Build and push to ECR
./docker/build-and-push.sh

# 2. Deploy to ECS
./docker/deploy-to-ecs.sh

# See DOCKER_DEPLOYMENT.md for full guide
```

---

## 📁 Docker Files Overview

```
docker/
├── build-and-push.sh       # Build and push to AWS ECR
├── deploy-to-ecs.sh        # Deploy to AWS ECS Fargate
├── nginx/
│   └── nginx.conf          # Nginx reverse proxy config
└── mysql-init/
    └── 01-init.sql         # MySQL initialization script

Root level:
├── Dockerfile              # Main application container
├── docker-compose.yml      # Local development setup
└── .dockerignore          # Files to exclude from build
```

---

## 🔧 Configuration

### Environment Variables

Create `.env` file in project root:

```bash
# Database
DB_ROOT_PASSWORD=strongrootpassword
DB_NAME=redmine_production
DB_USERNAME=redmine
DB_PASSWORD=securepassword

# Application
SECRET_KEY_BASE=your-generated-secret-key-here
```

Generate secret key:
```bash
docker run --rm ruby:2.7.8-slim sh -c "gem install bundler && bundle exec rake secret"
```

---

## 🐳 Docker Commands

### Build & Run
```bash
# Build image
docker build -t redmine-workproof .

# Run locally with docker-compose
docker-compose up -d

# View logs
docker-compose logs -f redmine

# Stop services
docker-compose down
```

### Database Operations
```bash
# Run migrations
docker-compose exec redmine bundle exec rake db:migrate

# Load default data
docker-compose exec redmine bundle exec rake redmine:load_default_data REDMINE_LANG=en

# Backup database
docker-compose exec mysql mysqldump -u root -p redmine_production > backup.sql

# Restore database
docker-compose exec -T mysql mysql -u root -p redmine_production < backup.sql
```

### Debugging
```bash
# Access container shell
docker-compose exec redmine bash

# Check container status
docker-compose ps

# View container logs
docker logs -f container-name

# Inspect container
docker inspect container-name
```

---

## ☁️ AWS Deployment

### Prerequisites
- AWS CLI configured
- Docker installed
- AWS account with ECR and ECS permissions

### Deploy to ECS Fargate

```bash
# 1. Set environment variables
export AWS_REGION=us-east-1
export DB_HOST=your-rds-endpoint.rds.amazonaws.com
export DB_PASSWORD=your-db-password
export SECRET_KEY_BASE=$(docker run --rm ruby:2.7.8-slim sh -c "gem install bundler && bundle exec rake secret")

# 2. Build and push to ECR
./docker/build-and-push.sh

# 3. Deploy to ECS
./docker/deploy-to-ecs.sh
```

### Full AWS Setup

See `DOCKER_DEPLOYMENT.md` for complete guide including:
- ECS with Fargate (managed)
- ECS with EC2 (cost-effective)
- EKS (Kubernetes)
- RDS setup
- Load balancer configuration
- Domain and SSL setup

---

## 📊 Deployment Comparison

| Option | Cost/Month | Setup Time | Best For |
|--------|-----------|------------|----------|
| **Local Docker** | Free | 5 min | Development |
| **ECS Fargate** | ~$65 | 30 min | Production (managed) |
| **ECS EC2** | ~$60 | 45 min | Cost-effective |
| **EKS** | ~$133 | 60 min | Enterprise |

---

## 🔍 Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs container-id

# Common fixes:
docker-compose down -v  # Remove volumes
docker-compose up --build  # Rebuild
```

### Database Connection Error
```bash
# Test database connection
docker-compose exec mysql mysql -u redmine -p

# Check if MySQL is ready
docker-compose logs mysql
```

### Permission Issues
```bash
# Fix file permissions
docker-compose exec redmine chown -R nobody:nogroup /usr/src/redmine/files
```

### Rebuild After Code Changes
```bash
docker-compose down
docker-compose up -d --build
```

---

## 📚 Documentation

- **Full Docker Guide**: `../DOCKER_DEPLOYMENT.md`
- **General Deployment**: `../DEPLOYMENT_GUIDE.md`
- **Quick Start**: `../deploy/QUICK_START.md`

---

## 🎯 Recommended Path

1. **Start Local**: Use `docker-compose` for development
2. **Test**: Verify everything works locally
3. **Deploy**: Use ECS Fargate for production
4. **Scale**: Upgrade to EKS if needed

---

## ⚡ Quick Commands Reference

```bash
# Start everything
docker-compose up -d

# View logs
docker-compose logs -f

# Stop everything
docker-compose down

# Rebuild and restart
docker-compose up -d --build

# Run migrations
docker-compose exec redmine bundle exec rake db:migrate

# Access shell
docker-compose exec redmine bash

# Push to AWS ECR
./docker/build-and-push.sh

# Deploy to AWS ECS
./docker/deploy-to-ecs.sh
```

---

## 🔐 Security Notes

- Never commit `.env` files
- Use AWS Secrets Manager for production
- Rotate database passwords regularly
- Keep Docker images updated
- Use specific image tags (not `latest`) in production

---

## 📞 Support

- **Docker Issues**: Check logs with `docker logs`
- **AWS Issues**: See `DOCKER_DEPLOYMENT.md`
- **Application Issues**: Check `log/production.log`

---

**Ready to deploy? Start with `docker-compose up -d` for local testing!** 🚀

