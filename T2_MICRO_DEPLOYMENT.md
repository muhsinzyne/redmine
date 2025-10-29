# Redmine Deployment on AWS t2.micro (Free Tier)

Optimized deployment guide for AWS t2.micro EC2 instances (1GB RAM).

---

## ⚠️ **Important: t2.micro Limitations**

**Specs:**
- vCPU: 1
- RAM: 1 GB
- Free Tier: 750 hours/month for 12 months

**Suitable for:**
- ✅ Testing and evaluation
- ✅ Personal projects
- ✅ Small teams (5-15 users)
- ✅ Learning AWS

**NOT suitable for:**
- ❌ High-traffic production
- ❌ Large teams (>20 users)
- ❌ Running Docker containers
- ❌ Heavy concurrent usage

---

## 🚀 **Quick Deployment (Automated)**

### **Step 1: Launch t2.micro EC2 Instance**

**Via AWS Console:**
1. Go to **EC2 Dashboard** → **Launch Instance**
2. **Name**: `redmine-server`
3. **AMI**: Ubuntu Server 22.04 LTS (Free tier eligible)
4. **Instance type**: `t2.micro` ⭐
5. **Key pair**: Create new or select existing (download .pem file)
6. **Network settings**:
   - Allow SSH (port 22) from your IP
   - Allow HTTP (port 80) from anywhere
   - Allow HTTPS (port 443) from anywhere
7. **Storage**: 20 GB gp3 (free tier: 30GB)
8. **Launch instance**

### **Step 2: Configure SSH Key**

```bash
# Set correct permissions
chmod 400 /path/to/your-key.pem

# Test connection
ssh -i /path/to/your-key.pem ubuntu@YOUR_EC2_IP
```

### **Step 3: Run Automated Deployment**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Run deployment script
./deploy/t2-micro-deploy.sh

# Follow the prompts:
# - EC2 Public IP: (from AWS console)
# - SSH Key Path: /path/to/your-key.pem
# - EC2 Username: ubuntu
# - Database: localhost (install MySQL on EC2)
# - Passwords: (choose strong passwords)
```

**Deployment time: 20-30 minutes**

---

## 📋 **Manual Deployment Steps**

If you prefer step-by-step control:

### **Step 1: Connect to EC2**

```bash
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
```

### **Step 2: Install System Dependencies**

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y \
    git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx mysql-server
```

### **Step 3: Install Ruby**

```bash
# Install rbenv
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc

# Install ruby-build
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build

# Install Ruby 2.7.8 (takes 10-15 minutes on t2.micro)
rbenv install 2.7.8
rbenv global 2.7.8

# Install Bundler
gem install bundler
```

### **Step 4: Configure MySQL**

```bash
# Secure MySQL
sudo mysql

# In MySQL prompt:
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'your-root-password';
CREATE DATABASE redmine_production CHARACTER SET utf8mb4;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY 'your-redmine-password';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# Start MySQL
sudo systemctl start mysql
sudo systemctl enable mysql
```

### **Step 5: Deploy Application (From Local Machine)**

```bash
# Prepare deployment package
cd /Users/muhsinzyne/work/redmine-dev/redmine
./deploy/prepare-deployment.sh

# Upload to EC2
scp -i your-key.pem deploy/package/redmine-deployment-*.tar.gz \
    ubuntu@YOUR_EC2_IP:/tmp/

# Extract on EC2
ssh -i your-key.pem ubuntu@YOUR_EC2_IP
sudo mkdir -p /var/www/redmine
sudo chown ubuntu:ubuntu /var/www/redmine
cd /var/www/redmine
tar -xzf /tmp/redmine-deployment-*.tar.gz
```

### **Step 6: Configure Database**

```bash
cd /var/www/redmine

# Create database.yml
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

# Generate secret key
bundle exec rake secret

# Create environment file
cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=paste-secret-key-here
RAILS_SERVE_STATIC_FILES=true
EOF
```

### **Step 7: Install Gems and Migrate**

```bash
# Install gems (use --jobs 1 for low memory)
bundle install --without development test --jobs 1

# Run migrations
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Create directories
mkdir -p tmp tmp/pdf public/plugin_assets files log
chmod -R 755 files log tmp public/plugin_assets
```

### **Step 8: Configure Puma (Optimized for t2.micro)**

```bash
# Create optimized Puma config
cat > config/puma.rb << 'EOF'
# Optimized for t2.micro (1GB RAM)
workers ENV.fetch("WEB_CONCURRENCY") { 1 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 2 }
threads threads_count, threads_count

port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "production" }
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

plugin :tmp_restart
EOF
```

### **Step 9: Create Systemd Service**

```bash
sudo nano /etc/systemd/system/redmine.service
```

```ini
[Unit]
Description=Redmine Application Server
After=network.target mysql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/var/www/redmine
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/redmine/.env.production
ExecStart=/home/ubuntu/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10
StandardOutput=append:/var/www/redmine/log/puma.log
StandardError=append:/var/www/redmine/log/puma.log

# Memory limits
MemoryMax=800M
MemoryHigh=700M

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable redmine
sudo systemctl start redmine
sudo systemctl status redmine
```

### **Step 10: Configure Nginx**

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

```bash
# Enable site
sudo ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

### **Step 11: Setup Swap (CRITICAL for t2.micro)**

```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Optimize swappiness (lower = use RAM more)
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Verify
free -h
```

---

## ✅ **Verification**

### **Check Services**

```bash
# Check Redmine service
sudo systemctl status redmine

# Check Nginx
sudo systemctl status nginx

# Check MySQL
sudo systemctl status mysql

# Check memory usage
free -h
```

### **Test Application**

```bash
# From EC2
curl -I http://localhost/

# From your browser
http://YOUR_EC2_IP

# Should see Redmine login page
```

---

## 🎛️ **t2.micro Optimizations**

### **Memory Optimizations Applied**

1. **✅ Puma Configuration:**
   - Only 1 worker (instead of 2+)
   - Only 2 threads per worker
   - Memory limit: 800MB max

2. **✅ Swap Space:**
   - 2GB swap file
   - Handles memory spikes
   - Swappiness set to 10 (prefer RAM)

3. **✅ MySQL Tuning:**
   ```bash
   # Edit MySQL config for low memory
   sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
   
   # Add under [mysqld]:
   innodb_buffer_pool_size = 128M  # Default is 128M (good for t2.micro)
   max_connections = 50              # Lower than default
   ```

4. **✅ System Tuning:**
   ```bash
   # Reduce background processes
   sudo systemctl disable snapd
   sudo systemctl disable unattended-upgrades
   ```

---

## 📊 **Expected Performance on t2.micro**

### **What to Expect:**

| Metric | Performance |
|--------|-------------|
| Page Load Time | 1-3 seconds |
| Concurrent Users | 5-15 max |
| Memory Usage | 70-90% |
| Swap Usage | 10-30% |
| Response Time | 500ms-2s |
| Uptime | 99%+ |

### **Performance Tips:**

1. **Enable Caching:**
   ```ruby
   # config/environments/production.rb
   config.cache_store = :memory_store, { size: 64.megabytes }
   ```

2. **Limit File Upload Size:**
   ```ruby
   # Administration → Settings → Files
   # Maximum attachment size: 5-10 MB (not 100MB)
   ```

3. **Optimize Database:**
   ```bash
   # Regular maintenance
   sudo mysqlcheck -o redmine_production -u root -p
   ```

4. **Monitor Memory:**
   ```bash
   # Install htop
   sudo apt install htop
   htop
   ```

---

## 🔍 **Monitoring**

### **Check Memory Usage**

```bash
# Quick check
free -h

# Detailed
htop

# Log to file
watch -n 60 'free -h >> /var/log/memory.log'
```

### **Check Application Logs**

```bash
# Application logs
tail -f /var/www/redmine/log/production.log

# Puma logs
tail -f /var/www/redmine/log/puma.log

# Nginx logs
sudo tail -f /var/nginx/error.log
```

### **Monitor Service Status**

```bash
# Check all services
sudo systemctl status redmine mysql nginx

# Restart if needed
sudo systemctl restart redmine
```

---

## 🆘 **Troubleshooting t2.micro Issues**

### **Issue: Out of Memory (OOM)**

**Symptoms:**
- MySQL crashes
- Puma workers killed
- System unresponsive

**Solutions:**
```bash
# 1. Verify swap is active
free -h
sudo swapon -s

# 2. Increase swap if needed
sudo swapoff /swapfile
sudo fallocate -l 4G /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 3. Reduce Puma workers
nano /var/www/redmine/config/puma.rb
# Set: workers 1, threads 1, 1

# 4. Restart services
sudo systemctl restart redmine
```

### **Issue: Slow Performance**

**Solutions:**
```bash
# 1. Check memory usage
free -h

# 2. Check swap usage (high swap = slow)
# If swap > 500MB, you need more RAM

# 3. Optimize MySQL
sudo mysql
SET GLOBAL innodb_buffer_pool_size=67108864;  # 64MB

# 4. Clear old logs
cd /var/www/redmine
rm log/*.log.*
```

### **Issue: MySQL Won't Start**

**Solutions:**
```bash
# 1. Check logs
sudo journalctl -u mysql -n 50

# 2. Try starting manually
sudo systemctl start mysql

# 3. If still fails, reduce MySQL memory
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# Set innodb_buffer_pool_size = 64M

# 4. Restart
sudo systemctl restart mysql
```

---

## 💰 **Cost Breakdown**

### **Free Tier (First 12 Months)**

```
t2.micro instance:     FREE (750 hours/month)
20 GB EBS storage:     FREE (30 GB/month)
Data transfer out:     FREE (15 GB/month)
──────────────────────────────
Total:                 $0/month for 12 months!
```

### **After Free Tier**

```
t2.micro instance:     $8.50/month
20 GB gp3 storage:     $2.00/month
Data transfer:         ~$5/month
──────────────────────────────
Total:                 ~$15.50/month
```

---

## 🔧 **t2.micro Specific Configuration**

### **Puma Configuration**

File: `config/puma.rb`

```ruby
# Optimized for 1GB RAM
workers 1                              # Only 1 worker
threads_count = 2                      # Only 2 threads
threads threads_count, threads_count

port ENV.fetch("PORT") { 3000 }
environment "production"

pidfile "tmp/pids/server.pid"
preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

# Lower memory footprint
before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
end
```

### **MySQL Configuration**

File: `/etc/mysql/mysql.conf.d/mysqld.cnf`

```ini
[mysqld]
# Memory optimizations for t2.micro
innodb_buffer_pool_size = 128M    # Reduced from default
max_connections = 50               # Reduced from 151
table_open_cache = 128            # Reduced from 400
innodb_log_buffer_size = 4M       # Reduced from 16M

# Performance optimizations
innodb_flush_log_at_trx_commit = 2
innodb_flush_method = O_DIRECT
```

### **Nginx Configuration**

Optimized for low memory in `/etc/nginx/nginx.conf`:

```nginx
user www-data;
worker_processes 1;  # Only 1 worker for t2.micro

events {
    worker_connections 512;  # Reduced from 1024
}

http {
    # ... rest of config ...
}
```

---

## 📈 **Upgrade Path**

### **When to Upgrade from t2.micro:**

**Signs you need more resources:**
- Memory usage consistently > 90%
- Swap usage > 500MB
- Page load times > 5 seconds
- Frequent 502/503 errors
- More than 15 concurrent users

### **Recommended Upgrade:**

**t2.micro → t3.small**

```bash
# Stop instance
aws ec2 stop-instances --instance-ids i-xxxxx

# Change instance type
aws ec2 modify-instance-attribute \
    --instance-id i-xxxxx \
    --instance-type t3.small

# Start instance
aws ec2 start-instances --instance-ids i-xxxxx
```

**Benefits:**
- 2x RAM (1GB → 2GB)
- 2x vCPU
- Better network performance
- Only $6.50/month more

---

## 🔐 **Security Hardening**

### **Basic Security**

```bash
# Update packages regularly
sudo apt update && sudo apt upgrade -y

# Configure firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable

# Change admin password
# Login to Redmine → My Account → Change Password

# Secure MySQL
sudo mysql_secure_installation
```

### **Optional: Fail2ban**

```bash
# Install fail2ban
sudo apt install fail2ban

# Configure
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

---

## 📊 **Monitoring Commands**

### **Quick Health Check**

```bash
#!/bin/bash
# Save as /usr/local/bin/redmine-health.sh

echo "=== Redmine Health Check ==="
echo ""
echo "Memory:"
free -h | grep -E "(Mem|Swap)"
echo ""
echo "Services:"
systemctl is-active redmine mysql nginx
echo ""
echo "Disk Usage:"
df -h / | tail -1
echo ""
echo "Application:"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://localhost/
```

### **Set Up Monitoring**

```bash
# Create monitoring script
sudo nano /usr/local/bin/redmine-health.sh
# Paste script above

# Make executable
sudo chmod +x /usr/local/bin/redmine-health.sh

# Add to crontab (check every hour)
echo "0 * * * * /usr/local/bin/redmine-health.sh >> /var/log/redmine-health.log" | crontab -
```

---

## 🎯 **What You Get with t2.micro**

### **Capabilities:**

✅ **Working Redmine installation**
✅ **5-15 concurrent users**
✅ **All Redmine features**
✅ **WorkProof plugin**
✅ **Email notifications**
✅ **File uploads (with size limits)**
✅ **Database functionality**

### **Limitations:**

⚠️ **Performance:**
- Slower page loads (1-3s)
- Limited concurrent users
- Will use swap memory

⚠️ **Scalability:**
- Not suitable for growth
- Need to upgrade for more users

⚠️ **Reliability:**
- May crash under heavy load
- Need monitoring

---

## 📖 **Summary**

**t2.micro Deployment:**
- ✅ **Cost**: Free for 12 months, then ~$15/month
- ✅ **Setup**: Automated script available
- ✅ **Performance**: Good for small teams (5-15 users)
- ✅ **Reliability**: Works with proper configuration
- ⚠️ **Not for**: Production with >20 users

**To deploy:**
```bash
./deploy/t2-micro-deploy.sh
```

**Remember:**
- Swap space is CRITICAL (2GB minimum)
- Monitor memory usage
- Optimize Puma (1 worker, 2 threads)
- Plan to upgrade if usage grows

---

## 🚀 **Ready to Deploy?**

Run the automated deployment:

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
./deploy/t2-micro-deploy.sh
```

You'll need:
- EC2 IP address
- SSH key path
- Database passwords

**Deployment takes ~25 minutes** and you'll have a working Redmine installation! 🎉

