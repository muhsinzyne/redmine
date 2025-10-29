# Quick Start Deployment Guide

Choose your deployment platform and follow the steps below.

---

## 🚀 Quick Deployment Options

### Option 1: AWS EC2 (Most Control)
**Best for:** Production, custom requirements, full control
**Cost:** ~$45/month
**Setup Time:** 30-60 minutes

### Option 2: GCP Compute Engine (Most Control)
**Best for:** Production, GCP ecosystem integration
**Cost:** ~$35/month
**Setup Time:** 30-60 minutes

### Option 3: AWS Elastic Beanstalk (Easiest)
**Best for:** Quick deployment, managed infrastructure
**Cost:** ~$50/month
**Setup Time:** 10-15 minutes

### Option 4: GCP App Engine (Easiest)
**Best for:** Auto-scaling, managed infrastructure
**Cost:** ~$40/month
**Setup Time:** 10-15 minutes

---

## 📦 Step 1: Prepare Your Application (LOCAL MACHINE)

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Run the preparation script
./deploy/prepare-deployment.sh
```

This will:
- ✅ Clean temporary files
- ✅ Install production gems
- ✅ Generate secret keys
- ✅ Precompile assets
- ✅ Create deployment package
- ✅ Generate configuration templates

**Output:** `deploy/package/redmine-deployment-TIMESTAMP.tar.gz`

---

## 🔧 Step 2: Choose Your Platform

### AWS EC2 Deployment

#### 2.1 Set Up AWS Infrastructure

**Create RDS Database:**
```bash
# Using AWS Console:
1. Go to RDS → Create database
2. MySQL 8.0, db.t3.micro
3. Database name: redmine_production
4. Note the endpoint URL
```

**Launch EC2 Instance:**
```bash
# Using AWS Console:
1. EC2 → Launch Instance
2. Ubuntu 22.04 LTS, t3.small
3. Create or select key pair
4. Allow HTTP (80), HTTPS (443), SSH (22)
```

#### 2.2 Set Up EC2 Server

```bash
# Connect to EC2
ssh -i your-key.pem ubuntu@your-ec2-ip

# Upload and run setup script
scp -i your-key.pem deploy/aws-ec2-setup.sh ubuntu@your-ec2-ip:~
ssh -i your-key.pem ubuntu@your-ec2-ip
chmod +x aws-ec2-setup.sh
./aws-ec2-setup.sh
```

#### 2.3 Deploy Application

```bash
# Upload deployment package (from local machine)
scp -i your-key.pem deploy/package/redmine-deployment-*.tar.gz ubuntu@your-ec2-ip:/var/www/redmine/

# On server
cd /var/www/redmine
tar -xzf redmine-deployment-*.tar.gz

# Configure environment
cp .env.production.template .env.production
nano .env.production  # Update DB_HOST, DB_PASSWORD, etc.

# Run migrations
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Set up systemd service (see DEPLOYMENT_GUIDE.md)
# Configure Nginx (see DEPLOYMENT_GUIDE.md)
```

---

### GCP Compute Engine Deployment

#### 2.1 Set Up GCP Infrastructure

```bash
# Install gcloud CLI first if not installed
# https://cloud.google.com/sdk/docs/install

# Create Cloud SQL instance
gcloud sql instances create redmine-db \
  --database-version=MYSQL_8_0 \
  --tier=db-f1-micro \
  --region=us-central1

# Create database
gcloud sql databases create redmine_production --instance=redmine-db

# Create Compute Engine instance
gcloud compute instances create redmine-server \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=e2-small \
  --zone=us-central1-a \
  --tags=http-server,https-server
```

#### 2.2 Set Up Compute Instance

```bash
# Connect
gcloud compute ssh redmine-server --zone=us-central1-a

# Upload and run setup script
gcloud compute scp deploy/gcp-compute-setup.sh redmine-server:~ --zone=us-central1-a
gcloud compute ssh redmine-server --zone=us-central1-a
chmod +x gcp-compute-setup.sh
./gcp-compute-setup.sh
```

#### 2.3 Deploy Application

```bash
# Upload package
gcloud compute scp deploy/package/redmine-deployment-*.tar.gz \
  redmine-server:/var/www/redmine/ --zone=us-central1-a

# On server (similar to AWS steps)
cd /var/www/redmine
tar -xzf redmine-deployment-*.tar.gz
# ... follow AWS deployment steps ...
```

---

### AWS Elastic Beanstalk (Easiest)

```bash
# Install EB CLI
pip install awsebcli

# From application directory
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Initialize
eb init -p ruby-2.7 redmine-app --region us-east-1

# Create environment with database
eb create redmine-production \
  --instance-type t3.small \
  --database.engine mysql \
  --database.username admin

# Deploy
eb deploy

# Open in browser
eb open
```

**Done!** 🎉

---

### GCP App Engine (Easiest)

```bash
# From application directory
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Ensure app.yaml exists (see DEPLOYMENT_GUIDE.md)

# Deploy
gcloud app deploy

# Open in browser
gcloud app browse
```

**Done!** 🎉

---

## 🔐 Step 3: Post-Deployment Security

```bash
# On your server:

# 1. Change admin password immediately
# Login at http://your-ip with admin/admin
# Go to My Account → Change Password

# 2. Set up SSL (Let's Encrypt - for EC2/Compute Engine)
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com

# 3. Set up firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# 4. Configure email (edit config/configuration.yml)
# See DEPLOYMENT_GUIDE.md for SMTP settings
```

---

## 📊 Step 4: Monitoring & Backups

### Set Up Automated Backups

**Database Backups (AWS):**
```bash
# Automatic backups enabled by default in RDS
# Retention period: 7 days

# Manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier redmine-db \
  --db-snapshot-identifier redmine-backup-$(date +%Y%m%d)
```

**Database Backups (GCP):**
```bash
# Enable automatic backups
gcloud sql instances patch redmine-db --backup-start-time=03:00

# Manual backup
gcloud sql backups create --instance=redmine-db
```

**Files Backup:**
```bash
# Create backup script
sudo nano /usr/local/bin/backup-redmine-files.sh
```

```bash
#!/bin/bash
BACKUP_DIR=/backup/redmine
mkdir -p $BACKUP_DIR
tar -czf $BACKUP_DIR/files-$(date +%Y%m%d).tar.gz /var/www/redmine/files
# Keep only last 7 days
find $BACKUP_DIR -name "files-*.tar.gz" -mtime +7 -delete
```

```bash
# Make executable
sudo chmod +x /usr/local/bin/backup-redmine-files.sh

# Add to crontab
echo "0 2 * * * /usr/local/bin/backup-redmine-files.sh" | sudo crontab -
```

---

## 🔍 Troubleshooting

### Check Application Status
```bash
# View logs
tail -f /var/www/redmine/log/production.log

# Check Puma service
sudo systemctl status redmine

# Restart services
sudo systemctl restart redmine
sudo systemctl restart nginx
```

### Common Issues

**502 Bad Gateway:**
```bash
# Puma not running
sudo systemctl restart redmine
journalctl -u redmine -n 50
```

**Database Connection Error:**
```bash
# Test connection
mysql -h your-db-host -u redmine -p

# Check environment variables
cat /var/www/redmine/.env.production
```

**Assets Not Loading:**
```bash
# Check file permissions
cd /var/www/redmine
sudo chown -R www-data:www-data public/
sudo chmod -R 755 public/
# Restart services
sudo systemctl restart redmine
sudo systemctl restart nginx
```

---

## 📞 Getting Help

- **Redmine Documentation:** https://www.redmine.org/guide
- **AWS Documentation:** https://docs.aws.amazon.com
- **GCP Documentation:** https://cloud.google.com/docs
- **Your Team:** Contact your DevOps lead

---

## ✅ Deployment Checklist

- [ ] Prepared deployment package locally
- [ ] Created cloud infrastructure (database, compute)
- [ ] Deployed application to server
- [ ] Configured environment variables
- [ ] Ran database migrations
- [ ] Changed default admin password
- [ ] Set up SSL certificate
- [ ] Configured email delivery
- [ ] Set up automated backups
- [ ] Configured monitoring/alerts
- [ ] Tested application functionality
- [ ] Documented server details
- [ ] Set up log rotation

---

## 💰 Cost Optimization Tips

1. **Use Reserved Instances:** Save 30-70% with 1-year commitment
2. **Right-size instances:** Monitor and adjust instance sizes
3. **Schedule dev environments:** Turn off during non-work hours
4. **Use S3/Cloud Storage:** For file attachments instead of disk
5. **Implement caching:** Redis for better performance
6. **CDN for assets:** CloudFront/Cloud CDN for static files

---

## 🚀 Performance Tips

1. **Enable Redis caching**
2. **Use CDN for assets**
3. **Optimize database queries**
4. **Enable gzip compression**
5. **Use connection pooling**
6. **Monitor slow queries**
7. **Regular maintenance tasks**

---

For detailed documentation, see **DEPLOYMENT_GUIDE.md**

