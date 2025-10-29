# Redmine Deployment Guide - AWS & GCP

This guide covers deploying your custom Redmine (with WorkProof plugin) to AWS and GCP.

---

## Table of Contents
1. [AWS Deployment](#aws-deployment)
2. [GCP Deployment](#gcp-deployment)
3. [Common Prerequisites](#common-prerequisites)
4. [Production Configuration](#production-configuration)
5. [Domain & SSL Setup](#domain--ssl-setup)
6. [Backup & Monitoring](#backup--monitoring)

---

## Common Prerequisites

Before deploying to either platform, ensure you have:

### 1. Update Your Configuration

**config/database.yml** - Update for production:
```yaml
production:
  adapter: mysql2
  database: redmine_production
  host: <%= ENV['DB_HOST'] || 'localhost' %>
  username: <%= ENV['DB_USERNAME'] || 'redmine' %>
  password: <%= ENV['DB_PASSWORD'] %>
  encoding: utf8mb4
  variables:
    transaction_isolation: "READ-COMMITTED"
```

**config/environments/production.rb** - Ensure these settings:
```ruby
config.action_mailer.perform_deliveries = true
config.action_mailer.raise_delivery_errors = true
config.serve_static_files = ENV['RAILS_SERVE_STATIC_FILES'].present?
config.log_level = :info
```

### 2. Create Environment Variables File

Create `.env.production`:
```bash
RAILS_ENV=production
REDMINE_DB_MYSQL=redmine_production
DB_HOST=your-database-host
DB_USERNAME=redmine
DB_PASSWORD=your-secure-password
SECRET_KEY_BASE=your-secret-key-base
RAILS_SERVE_STATIC_FILES=true
```

### 3. Prepare Your Application

```bash
# Install production gems
bundle install --without development test

# Generate secret key
bundle exec rake secret

# Precompile assets
RAILS_ENV=production bundle exec rake assets:precompile

# Create deployment package
tar -czf redmine-deployment.tar.gz \
  --exclude='tmp/cache/*' \
  --exclude='log/*' \
  --exclude='files/*' \
  --exclude='.git' \
  .
```

---

## AWS Deployment

### Option 1: AWS EC2 + RDS (Recommended for Production)

#### Step 1: Set Up RDS MySQL Database

1. **Create RDS Instance:**
   ```
   - Go to AWS Console → RDS → Create database
   - Choose MySQL 8.0
   - Template: Production (or Dev/Test for lower cost)
   - DB instance identifier: redmine-db
   - Master username: admin
   - Master password: [secure password]
   - DB instance class: db.t3.micro (start small)
   - Storage: 20 GB (auto-scaling enabled)
   - VPC: Default or custom
   - Public access: No (for security)
   - VPC security group: Create new (redmine-db-sg)
   - Database name: redmine_production
   ```

2. **Configure Security Group:**
   ```
   - Inbound rule: MySQL/Aurora (3306)
   - Source: EC2 security group (will create next)
   ```

#### Step 2: Launch EC2 Instance

1. **Create EC2 Instance:**
   ```
   - Go to AWS Console → EC2 → Launch Instance
   - Name: redmine-server
   - AMI: Ubuntu Server 22.04 LTS
   - Instance type: t3.small (2 vCPU, 2 GB RAM minimum)
   - Key pair: Create new or use existing
   - Network: Same VPC as RDS
   - Security group: Create new (redmine-web-sg)
     - SSH (22): Your IP
     - HTTP (80): 0.0.0.0/0
     - HTTPS (443): 0.0.0.0/0
   - Storage: 20 GB gp3
   ```

#### Step 3: Connect and Setup EC2

```bash
# Connect to EC2
ssh -i your-key.pem ubuntu@your-ec2-public-ip

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y git curl libssl-dev libreadline-dev \
  zlib1g-dev autoconf bison build-essential libyaml-dev \
  libreadline-dev libncurses5-dev libffi-dev libgdbm-dev \
  imagemagick libmagickwand-dev libmysqlclient-dev nginx

# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install ruby-build
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Install Ruby 2.7.8
rbenv install 2.7.8
rbenv global 2.7.8

# Install Bundler
gem install bundler

# Create application directory
sudo mkdir -p /var/www/redmine
sudo chown ubuntu:ubuntu /var/www/redmine
cd /var/www/redmine
```

#### Step 4: Deploy Application

```bash
# Upload your application (from local machine)
scp -i your-key.pem redmine-deployment.tar.gz ubuntu@your-ec2-ip:/var/www/redmine/

# Extract on server
cd /var/www/redmine
tar -xzf redmine-deployment.tar.gz

# Set up environment
cat > .env.production << EOF
RAILS_ENV=production
DB_HOST=your-rds-endpoint.rds.amazonaws.com
DB_USERNAME=admin
DB_PASSWORD=your-rds-password
DB_NAME=redmine_production
SECRET_KEY_BASE=$(bundle exec rake secret)
RAILS_SERVE_STATIC_FILES=true
EOF

# Install gems
bundle install --without development test --path vendor/bundle

# Set up database
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Precompile assets
RAILS_ENV=production bundle exec rake assets:precompile

# Set permissions
mkdir -p tmp tmp/pdf public/plugin_assets
sudo chown -R ubuntu:ubuntu files log tmp public/plugin_assets
sudo chmod -R 755 files log tmp public/plugin_assets
```

#### Step 5: Configure Nginx + Puma

**Create systemd service for Puma:**
```bash
sudo nano /etc/systemd/system/redmine.service
```

```ini
[Unit]
Description=Redmine Puma Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/redmine
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/redmine/.env.production
ExecStart=/home/ubuntu/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
```

**Configure Nginx:**
```bash
sudo nano /etc/nginx/sites-available/redmine
```

```nginx
upstream redmine {
  server 127.0.0.1:3000 fail_timeout=0;
}

server {
  listen 80;
  server_name your-domain.com;  # or use EC2 IP initially

  root /var/www/redmine/public;
  
  client_max_body_size 20M;

  location / {
    try_files $uri @redmine;
  }

  location @redmine {
    proxy_pass http://redmine;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_redirect off;
  }

  location ~* ^/assets/ {
    expires 1y;
    add_header Cache-Control public;
    add_header ETag "";
    break;
  }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

# Test and restart Nginx
sudo nginx -t
sudo systemctl restart nginx

# Start Redmine
sudo systemctl daemon-reload
sudo systemctl enable redmine
sudo systemctl start redmine

# Check status
sudo systemctl status redmine
```

#### Step 6: Set Up Elastic IP (Optional but Recommended)

```
1. Go to EC2 → Elastic IPs → Allocate Elastic IP
2. Associate with your EC2 instance
3. This gives you a permanent IP address
```

---

### Option 2: AWS Elastic Beanstalk (Easier Deployment)

#### Step 1: Install EB CLI

```bash
pip install awsebcli
```

#### Step 2: Initialize EB Application

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Initialize
eb init -p ruby-2.7 redmine-app --region us-east-1

# Create environment
eb create redmine-production \
  --instance-type t3.small \
  --database.engine mysql \
  --database.username admin \
  --database.password your-secure-password \
  --envvars SECRET_KEY_BASE=$(bundle exec rake secret)

# Deploy
eb deploy

# Open in browser
eb open
```

---

## GCP Deployment

### Option 1: GCP Compute Engine + Cloud SQL (Recommended)

#### Step 1: Set Up Cloud SQL MySQL

```bash
# Using gcloud CLI (or use Cloud Console)
gcloud sql instances create redmine-db \
  --database-version=MYSQL_8_0 \
  --tier=db-f1-micro \
  --region=us-central1 \
  --root-password=your-secure-password

# Create database
gcloud sql databases create redmine_production --instance=redmine-db

# Create user
gcloud sql users create redmine \
  --instance=redmine-db \
  --password=your-secure-password

# Get connection name
gcloud sql instances describe redmine-db --format="value(connectionName)"
```

#### Step 2: Create Compute Engine Instance

```bash
# Create instance
gcloud compute instances create redmine-server \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=e2-small \
  --zone=us-central1-a \
  --tags=http-server,https-server \
  --scopes=sql-admin

# Create firewall rules
gcloud compute firewall-rules create allow-http \
  --allow tcp:80 \
  --target-tags http-server

gcloud compute firewall-rules create allow-https \
  --allow tcp:443 \
  --target-tags https-server
```

#### Step 3: Connect and Setup

```bash
# SSH into instance
gcloud compute ssh redmine-server --zone=us-central1-a

# Follow same setup steps as AWS EC2 (Step 3 & 4)
# ... (install dependencies, Ruby, deploy app)
```

#### Step 4: Configure Cloud SQL Proxy

```bash
# Download Cloud SQL Proxy
wget https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 -O cloud_sql_proxy
chmod +x cloud_sql_proxy

# Create systemd service
sudo nano /etc/systemd/system/cloud-sql-proxy.service
```

```ini
[Unit]
Description=Cloud SQL Proxy
After=network.target

[Service]
Type=simple
User=ubuntu
ExecStart=/home/ubuntu/cloud_sql_proxy -instances=YOUR-PROJECT:us-central1:redmine-db=tcp:3306
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
# Start proxy
sudo systemctl enable cloud-sql-proxy
sudo systemctl start cloud-sql-proxy

# Update database.yml to use localhost:3306
```

#### Step 5: Configure Nginx + Puma

Follow the same Nginx and Puma configuration as AWS (Step 5)

---

### Option 2: GCP App Engine (Platform-as-a-Service)

#### Step 1: Create app.yaml

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
nano app.yaml
```

```yaml
runtime: ruby27
entrypoint: bundle exec puma -C config/puma.rb

env_variables:
  RAILS_ENV: production
  SECRET_KEY_BASE: your-secret-key-base
  RAILS_SERVE_STATIC_FILES: true

automatic_scaling:
  min_instances: 1
  max_instances: 3
  target_cpu_utilization: 0.65

handlers:
- url: /assets
  static_dir: public/assets
  expiration: 1y

- url: /.*
  script: auto
```

#### Step 2: Deploy

```bash
# Deploy to App Engine
gcloud app deploy

# View your app
gcloud app browse
```

---

## Production Configuration

### 1. Email Configuration (for both AWS & GCP)

Add to `config/configuration.yml`:

```yaml
production:
  email_delivery:
    delivery_method: :smtp
    smtp_settings:
      address: smtp.gmail.com  # or AWS SES, SendGrid
      port: 587
      domain: your-domain.com
      authentication: :plain
      user_name: your-email@gmail.com
      password: your-app-password
      enable_starttls_auto: true
```

### 2. File Storage

**For AWS S3:**
```ruby
# Add to Gemfile
gem 'aws-sdk-s3'

# Configure in environment
config.active_storage.service = :amazon
```

**For GCP Cloud Storage:**
```ruby
# Add to Gemfile
gem 'google-cloud-storage'

# Configure in environment
config.active_storage.service = :google
```

---

## Domain & SSL Setup

### AWS with Certificate Manager

```bash
1. Request certificate in ACM
2. Set up Application Load Balancer
3. Add EC2 instance to target group
4. Update Route 53 with domain
5. Configure SSL termination at ALB
```

### GCP with Let's Encrypt

```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d your-domain.com -d www.your-domain.com

# Auto-renewal is configured automatically
```

---

## Backup & Monitoring

### Database Backups

**AWS:**
```bash
# RDS automatic backups are enabled by default
# Manual backup:
aws rds create-db-snapshot \
  --db-instance-identifier redmine-db \
  --db-snapshot-identifier redmine-backup-$(date +%Y%m%d)
```

**GCP:**
```bash
# Enable automatic backups
gcloud sql instances patch redmine-db --backup-start-time=03:00

# Manual backup
gcloud sql backups create --instance=redmine-db
```

### Files Backup

```bash
# Cron job for file backups
0 2 * * * tar -czf /backup/redmine-files-$(date +\%Y\%m\%d).tar.gz /var/www/redmine/files
```

### Monitoring

**AWS CloudWatch:**
```bash
# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

**GCP Cloud Monitoring:**
```bash
# Install monitoring agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install
```

---

## Cost Estimates

### AWS (Monthly)
- EC2 t3.small: ~$15
- RDS db.t3.micro: ~$15
- Storage (40GB): ~$4
- Data transfer: ~$10
- **Total: ~$45/month**

### GCP (Monthly)
- e2-small: ~$13
- Cloud SQL db-f1-micro: ~$10
- Storage (40GB): ~$2
- Data transfer: ~$10
- **Total: ~$35/month**

---

## Troubleshooting

### Check Logs
```bash
# Application logs
tail -f /var/www/redmine/log/production.log

# Puma logs
sudo journalctl -u redmine -f

# Nginx logs
sudo tail -f /var/nginx/error.log
```

### Common Issues

1. **502 Bad Gateway:** Puma not running
   ```bash
   sudo systemctl restart redmine
   ```

2. **Database connection issues:**
   ```bash
   # Test MySQL connection
   mysql -h your-db-host -u redmine -p
   ```

3. **Permission issues:**
   ```bash
   sudo chown -R ubuntu:ubuntu /var/www/redmine
   sudo chmod -R 755 /var/www/redmine/public
   ```

---

## Next Steps

1. Set up regular database backups
2. Configure monitoring and alerts
3. Set up SSL certificates
4. Configure email delivery
5. Set up log rotation
6. Configure firewall rules
7. Implement Redis for caching (optional)
8. Set up CI/CD pipeline (optional)

---

## Security Checklist

- [ ] Change default admin password
- [ ] Use strong database passwords
- [ ] Enable SSL/HTTPS
- [ ] Configure firewall rules
- [ ] Regular security updates
- [ ] Set up database backups
- [ ] Configure fail2ban (optional)
- [ ] Use IAM roles (not access keys)
- [ ] Enable CloudWatch/Cloud Monitoring
- [ ] Regular vulnerability scanning

---

## Support

For issues specific to:
- **Redmine**: https://www.redmine.org/projects/redmine/wiki
- **AWS**: https://aws.amazon.com/support/
- **GCP**: https://cloud.google.com/support/

For this deployment configuration, refer to your team's documentation or DevOps lead.

