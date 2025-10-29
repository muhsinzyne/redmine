# Redmine Deployment Resources

Welcome to the Redmine deployment resources folder! This contains everything you need to deploy your custom Redmine application (with WorkProof plugin) to AWS or GCP.

---

## 📁 What's Inside

### Documentation
- **📘 [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Comprehensive deployment guide for AWS and GCP
- **🚀 [QUICK_START.md](QUICK_START.md)** - Quick start guide with step-by-step instructions
- **⚖️ [PLATFORM_COMPARISON.md](PLATFORM_COMPARISON.md)** - Detailed comparison of deployment options

### Scripts
- **☁️ [aws-ec2-setup.sh](aws-ec2-setup.sh)** - Automated setup script for AWS EC2 instances
- **☁️ [gcp-compute-setup.sh](gcp-compute-setup.sh)** - Automated setup script for GCP Compute Engine
- **📦 [prepare-deployment.sh](prepare-deployment.sh)** - Prepare application package for deployment

---

## 🚀 Quick Start (30 seconds)

### Step 1: Prepare Your Application
```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
./deploy/prepare-deployment.sh
```

### Step 2: Choose Your Platform
Pick one based on your needs:

| Platform | Best For | Cost | Difficulty |
|----------|----------|------|------------|
| **AWS Elastic Beanstalk** | Quick deploy | ~$50/mo | ⭐ Easy |
| **GCP App Engine** | Easiest setup | ~$40/mo | ⭐ Easy |
| **GCP Compute + SQL** | Best value | ~$35/mo | ⭐⭐⭐ Moderate |
| **AWS EC2 + RDS** | Full control | ~$45/mo | ⭐⭐⭐ Moderate |

### Step 3: Deploy
Follow the instructions in [QUICK_START.md](QUICK_START.md) for your chosen platform.

---

## 📚 Documentation Guide

### New to Cloud Deployment?
Start here:
1. Read [PLATFORM_COMPARISON.md](PLATFORM_COMPARISON.md) to choose your platform
2. Follow [QUICK_START.md](QUICK_START.md) for step-by-step instructions
3. Refer to [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for detailed configuration

### Experienced with Cloud?
Quick path:
1. Run `./deploy/prepare-deployment.sh`
2. Jump to your platform section in [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
3. Deploy and configure

---

## 🎯 Recommended Deployment Path

### For Production (Recommended)
**GCP Compute Engine + Cloud SQL**
- ✅ Best value for money (~$35/month)
- ✅ Full control and customization
- ✅ Professional setup
- ⏱️ Setup time: 45-60 minutes

**How to deploy:**
```bash
# 1. Prepare package
./deploy/prepare-deployment.sh

# 2. Follow GCP Compute Engine section in QUICK_START.md
```

### For Quick MVP/Testing
**AWS Elastic Beanstalk**
- ✅ Fastest deployment (10-15 minutes)
- ✅ Auto-scaling included
- ✅ Managed infrastructure
- ⏱️ Setup time: 10-15 minutes

**How to deploy:**
```bash
# Install EB CLI
pip install awsebcli

# Deploy (from app root)
eb init -p ruby-2.7 redmine-app --region us-east-1
eb create redmine-production --instance-type t3.small
eb deploy
eb open
```

---

## 📋 Prerequisites

### All Platforms
- ✅ Ruby 2.7.8 installed locally
- ✅ Bundler installed
- ✅ Git installed
- ✅ Terminal/Command line access

### AWS Deployment
- ✅ AWS account
- ✅ AWS CLI installed (optional but recommended)
- ✅ Credit card for AWS billing

### GCP Deployment
- ✅ GCP account
- ✅ gcloud CLI installed (optional but recommended)
- ✅ Credit card for GCP billing

---

## 💰 Cost Estimates

### Monthly Costs (Small Production Setup)

| Component | AWS | GCP |
|-----------|-----|-----|
| Compute | $15 | $13 |
| Database | $15 | $10 |
| Storage | $4 | $2 |
| Network | $10 | $10 |
| **Total** | **~$45** | **~$35** |

### Ways to Reduce Costs
1. **Reserved Instances**: Save 30-70% with 1-year commitment
2. **Auto-scaling**: Scale down during off-hours
3. **Spot Instances**: Save up to 90% (for non-critical workloads)
4. **Right-sizing**: Start small, scale as needed
5. **Free Tier**: AWS/GCP offer 12 months free tier for new accounts

---

## 🔧 Scripts Overview

### prepare-deployment.sh
**Purpose:** Prepares your application for deployment
**Usage:** `./deploy/prepare-deployment.sh`
**Output:**
- Deployment package (tar.gz)
- Environment template
- Deployment instructions
- Server deployment script

### aws-ec2-setup.sh
**Purpose:** Sets up AWS EC2 instance with all dependencies
**Usage:** Run on fresh Ubuntu 22.04 EC2 instance
**What it does:**
- Installs system dependencies
- Installs Ruby 2.7.8 via rbenv
- Installs Nginx
- Creates application directory

### gcp-compute-setup.sh
**Purpose:** Sets up GCP Compute Engine with all dependencies
**Usage:** Run on fresh Ubuntu 22.04 GCP instance
**What it does:**
- Installs system dependencies
- Installs Ruby 2.7.8 via rbenv
- Installs Nginx
- Downloads Cloud SQL Proxy
- Creates application directory

---

## ⚡ Quick Commands Reference

### Prepare Deployment Package
```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
./deploy/prepare-deployment.sh
```

### Deploy to AWS Elastic Beanstalk
```bash
pip install awsebcli
eb init -p ruby-2.7 redmine-app
eb create redmine-production
eb deploy
```

### Deploy to GCP App Engine
```bash
gcloud app deploy
gcloud app browse
```

### Upload to EC2/Compute Engine
```bash
# AWS
scp -i key.pem package.tar.gz ubuntu@ec2-ip:/var/www/redmine/

# GCP
gcloud compute scp package.tar.gz instance-name:/var/www/redmine/
```

---

## 🆘 Troubleshooting

### Package Creation Fails
```bash
# Ensure you're in the right directory
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Ensure dependencies are installed
bundle install --without development test

# Check Ruby version
ruby -v  # Should be 2.7.8
```

### Deployment Fails
```bash
# Check application logs
tail -f /var/www/redmine/log/production.log

# Check service status
sudo systemctl status redmine

# Restart services
sudo systemctl restart redmine
sudo systemctl restart nginx
```

### Database Connection Issues
```bash
# Test database connection
mysql -h db-host -u username -p

# Check environment variables
cat /var/www/redmine/.env.production

# Verify database exists
mysql -h db-host -u username -p -e "SHOW DATABASES;"
```

---

## 📖 Learning Resources

### AWS
- [AWS EC2 Getting Started](https://docs.aws.amazon.com/ec2/index.html)
- [AWS RDS Documentation](https://docs.aws.amazon.com/rds/index.html)
- [AWS Elastic Beanstalk Guide](https://docs.aws.amazon.com/elasticbeanstalk/)

### GCP
- [GCP Compute Engine Guide](https://cloud.google.com/compute/docs)
- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [App Engine Ruby Guide](https://cloud.google.com/appengine/docs/standard/ruby)

### Redmine
- [Redmine Installation Guide](https://www.redmine.org/projects/redmine/wiki/RedmineInstall)
- [Redmine Administration](https://www.redmine.org/projects/redmine/wiki/RedmineAdministration)

---

## 🔐 Security Checklist

Before going to production:
- [ ] Change default admin password (admin/admin)
- [ ] Use strong database passwords
- [ ] Enable SSL/HTTPS
- [ ] Configure firewall rules
- [ ] Set up regular backups
- [ ] Enable 2FA for admin accounts
- [ ] Configure fail2ban (optional)
- [ ] Regular security updates
- [ ] Monitor access logs
- [ ] Use IAM roles (not access keys)

---

## 📞 Support

### Documentation
- **Main Guide**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- **Quick Start**: [QUICK_START.md](QUICK_START.md)
- **Platform Comparison**: [PLATFORM_COMPARISON.md](PLATFORM_COMPARISON.md)

### Community
- **Redmine Forums**: https://www.redmine.org/projects/redmine/boards
- **Stack Overflow**: Tag your questions with `redmine` and `ruby-on-rails`

### Cloud Support
- **AWS Support**: https://aws.amazon.com/support/
- **GCP Support**: https://cloud.google.com/support/

---

## 🎯 Next Steps

1. **Review Documentation**
   - Read [PLATFORM_COMPARISON.md](PLATFORM_COMPARISON.md) to choose your platform
   - Review [QUICK_START.md](QUICK_START.md) for deployment steps

2. **Prepare Application**
   ```bash
   ./deploy/prepare-deployment.sh
   ```

3. **Set Up Cloud Account**
   - Create AWS or GCP account
   - Set up billing
   - Install CLI tools

4. **Deploy Application**
   - Follow platform-specific instructions
   - Configure environment variables
   - Run migrations
   - Test application

5. **Post-Deployment**
   - Change default passwords
   - Set up SSL
   - Configure backups
   - Set up monitoring

---

## 📝 Notes

- All scripts are tested on Ubuntu 22.04 LTS
- Ruby 2.7.8 is used (matching your local development)
- MySQL 8.0 is recommended for database
- Puma is used as the application server
- Nginx is used as the reverse proxy

---

## 🔄 Updates

This deployment package is current as of October 2025.

Check for updates:
- Redmine: https://www.redmine.org/projects/redmine/wiki/Download
- Ruby: https://www.ruby-lang.org/en/downloads/
- Dependencies: Run `bundle update` regularly

---

**Ready to deploy? Start with [QUICK_START.md](QUICK_START.md)** 🚀

