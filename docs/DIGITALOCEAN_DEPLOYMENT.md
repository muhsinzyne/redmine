# DigitalOcean Deployment Guide for Redmine

Complete guide for deploying Redmine to DigitalOcean droplets.

---

## 🌊 **Why DigitalOcean?**

✅ **Advantages:**
- Simple pricing ($4-6/month for basic droplet)
- Easy to use interface
- Great documentation
- Fast SSD storage
- Free bandwidth (1TB+)
- Good for beginners
- Better price/performance than AWS t2.micro

---

## 💰 **DigitalOcean Pricing**

| Droplet | vCPU | RAM | Storage | Transfer | Cost/Month |
|---------|------|-----|---------|----------|------------|
| **Basic** | 1 | 512MB | 10GB | 500GB | $4 |
| **Basic** | 1 | 1GB | 25GB | 1TB | $6 ⭐ |
| **Basic** | 1 | 2GB | 50GB | 2TB | $12 |
| **Basic** | 2 | 2GB | 60GB | 3TB | $18 |

**Recommended: $6/month (1GB RAM)** or **$12/month (2GB RAM)** ⭐

---

## 🚀 **Quick Deployment (Automated)**

### **Prerequisites**

1. **DigitalOcean Account** (sign up at digitalocean.com)
2. **Droplet Created** with:
   - Ubuntu 22.04 LTS
   - 1GB RAM minimum ($6/month)
   - Your preferred region
   - Password or SSH key authentication

### **Step 1: Install sshpass (For Password Auth)**

```bash
# macOS
brew install hudochenkov/sshpass/sshpass

# Linux
sudo apt install sshpass

# Verify
sshpass -V
```

### **Step 2: Push Code to GitHub**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Commit and push latest changes
git add -A
git commit -m "Prepare for deployment"
git push origin master
```

### **Step 3: Run Deployment Script**

```bash
# Run the automated deployment
./deploy/digitalocean-deploy.sh

# The script will prompt for:
# - Droplet IP address
# - Username (usually 'root')
# - Password
# - Database configuration
# - Domain (optional)
# - Git deployment method
```

**Deployment time: 20-25 minutes** ⏱️

---

## 📋 **Manual Deployment Steps**

### **Step 1: Create Droplet**

**Via DigitalOcean Console:**

1. **Click**: Create → Droplets
2. **Image**: Ubuntu 22.04 (LTS) x64
3. **Plan**: 
   - Basic
   - Regular Intel - $6/mo (1GB / 1 CPU)
   - OR $12/mo (2GB / 1 CPU) ⭐ Recommended
4. **Datacenter**: Closest to you
5. **Authentication**: 
   - Password (simpler)
   - OR SSH key (more secure)
6. **Hostname**: redmine-server
7. **Create Droplet**

### **Step 2: Connect to Droplet**

**With Password:**
```bash
ssh root@YOUR_DROPLET_IP
# Enter password when prompted
```

**With SSH Key:**
```bash
ssh -i ~/.ssh/your_key root@YOUR_DROPLET_IP
```

### **Step 3: Update System**

```bash
apt update && apt upgrade -y
```

### **Step 4: Install Dependencies**

```bash
apt install -y git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx mysql-server
```

### **Step 5: Install Ruby via rbenv**

```bash
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
```

### **Step 6: Configure MySQL**

```bash
# Secure MySQL
mysql

# In MySQL prompt:
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your-strong-password';
CREATE DATABASE redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY 'your-redmine-password';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### **Step 7: Deploy Application**

**Option A: From Git (Recommended)**

```bash
# Generate SSH key for GitHub
ssh-keygen -t ed25519 -C "redmine-deploy" -f ~/.ssh/github_deploy -N ""

# Show public key
cat ~/.ssh/github_deploy.pub

# Add to GitHub: Repo → Settings → Deploy keys → Add key

# Configure SSH
cat > ~/.ssh/config << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github_deploy
EOF

# Clone repository
git clone git@github.com:muhsinzyne/redmine.git /var/www/redmine
```

**Option B: Upload via SCP (from local machine)**

```bash
# On local machine:
cd /Users/muhsinzyne/work/redmine-dev/redmine
./deploy/prepare-deployment.sh

# Upload
sshpass -p 'YOUR_PASSWORD' scp \
    deploy/package/redmine-deployment-*.tar.gz \
    root@YOUR_DROPLET_IP:/tmp/

# On droplet:
mkdir -p /var/www/redmine
cd /var/www/redmine
tar -xzf /tmp/redmine-deployment-*.tar.gz
```

### **Step 8: Configure Database**

```bash
cd /var/www/redmine

cat > config/database.yml << EOF
production:
  adapter: mysql2
  database: redmine_production
  host: localhost
  username: redmine
  password: "your-redmine-password"
  encoding: utf8mb4
  variables:
    transaction_isolation: "READ-COMMITTED"
EOF

# Generate secret
bundle exec rake secret

# Create environment file
cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=paste-generated-secret-here
RAILS_SERVE_STATIC_FILES=true
EOF
```

### **Step 9: Install and Setup**

```bash
cd /var/www/redmine

# Install gems
bundle install --without development test

# Run migrations
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Create directories
mkdir -p tmp tmp/pdf public/plugin_assets files log
chmod -R 755 files log tmp public/plugin_assets
```

### **Step 10: Configure Services**

Create Puma systemd service:

```bash
sudo nano /etc/systemd/system/redmine.service
```

```ini
[Unit]
Description=Redmine Application Server
After=network.target mysql.service

[Service]
Type=simple
User=root
WorkingDirectory=/var/www/redmine
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/redmine/.env.production
ExecStart=/root/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10
StandardOutput=append:/var/www/redmine/log/puma.log
StandardError=append:/var/www/redmine/log/puma.log

[Install]
WantedBy=multi-user.target
```

Start services:
```bash
sudo systemctl daemon-reload
sudo systemctl enable redmine
sudo systemctl start redmine
sudo systemctl status redmine
```

Configure Nginx:
```bash
sudo nano /etc/nginx/sites-available/redmine
```

```nginx
upstream redmine {
    server 127.0.0.1:3000 fail_timeout=0;
}

server {
    listen 80 default_server;
    server_name _;
    
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
    
    location ~* ^/(assets|plugin_assets)/ {
        expires 1y;
        add_header Cache-Control public;
    }
}
```

Enable site:
```bash
sudo ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## 🔐 **SSL Setup with Let's Encrypt**

### **After Domain DNS is Configured**

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d redmine.yourdomain.com

# Auto-renewal is configured automatically
# Test renewal:
sudo certbot renew --dry-run
```

---

## 🎛️ **DigitalOcean Specific Features**

### **Snapshots (Backups)**

```bash
# Via DigitalOcean Console:
# Droplet → Snapshots → Take Snapshot
# Cost: ~$0.06/GB/month
```

### **Managed Databases**

Instead of MySQL on droplet:
```
# DigitalOcean → Databases → Create Database Cluster
# MySQL 8, 1GB RAM: $15/month
# Benefits: Automated backups, scaling, monitoring
```

### **Block Storage**

For file uploads:
```bash
# Create volume in DO Console
# Attach to droplet
# Mount to /var/www/redmine/files
```

### **Monitoring**

DigitalOcean provides free:
- CPU usage graphs
- Memory usage
- Disk I/O
- Bandwidth

---

## 📊 **Recommended Droplet Sizes**

| Users | Droplet | RAM | Cost | Performance |
|-------|---------|-----|------|-------------|
| 5-15 | Basic | 1GB | $6/mo | Good |
| 15-30 | Basic | 2GB | $12/mo | Better ⭐ |
| 30-50 | Basic | 4GB | $24/mo | Great |
| 50+ | Premium | 8GB | $48/mo | Excellent |

---

## 🔍 **Monitoring & Maintenance**

### **Check Service Status**

```bash
# All services
systemctl status redmine mysql nginx

# Memory usage
free -h

# Disk usage
df -h

# Active connections
netstat -an | grep :80 | wc -l
```

### **View Logs**

```bash
# Application logs
tail -f /var/www/redmine/log/production.log

# Puma server
tail -f /var/www/redmine/log/puma.log

# System logs
journalctl -u redmine -f
```

### **Backup Database**

```bash
# Backup
mysqldump -u root -p redmine_production > backup.sql

# Restore
mysql -u root -p redmine_production < backup.sql
```

---

## 🆘 **Troubleshooting**

### **Cannot Connect to Droplet**

```bash
# Check firewall
sudo ufw status

# Allow SSH
sudo ufw allow 22
```

### **502 Bad Gateway**

```bash
# Check Redmine status
sudo systemctl status redmine

# Restart
sudo systemctl restart redmine

# Check logs
tail -f /var/www/redmine/log/puma.log
```

### **Out of Memory**

```bash
# Check memory
free -h

# Add swap if not present
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

---

## 🎯 **Quick Start Summary**

### **With Automated Script:**

```bash
# 1. Install sshpass
brew install hudochenkov/sshpass/sshpass

# 2. Push code to GitHub
git push origin master

# 3. Run deployment
./deploy/digitalocean-deploy.sh

# 4. Follow prompts
# Done! ✅
```

### **What You Need:**

✅ Droplet IP: `xxx.xxx.xxx.xxx`  
✅ Username: `root` (DigitalOcean default)  
✅ Password: (from DigitalOcean email/console)  
✅ GitHub repo: Already set up ✅  

---

## 📖 **Documentation**

- **This Guide**: Complete DigitalOcean deployment
- **SSL Setup**: See `SSL_DOMAIN_SETUP.md`
- **Email Setup**: Already configured in `config/configuration.yml`
- **General Deployment**: See `DEPLOYMENT_GUIDE.md`

---

## 🎉 **Benefits of DigitalOcean**

✅ **Simpler than AWS** (easier interface)  
✅ **Better value** ($6 vs $8.50 for similar specs)  
✅ **No free tier confusion** (straightforward pricing)  
✅ **Included bandwidth** (1TB vs AWS charges)  
✅ **Fast SSD storage** (included)  
✅ **Easy snapshots** (one-click backups)  
✅ **Great documentation** (beginner-friendly)  

---

**Ready to deploy? Run:**

```bash
./deploy/digitalocean-deploy.sh
```

And follow the prompts! 🚀

