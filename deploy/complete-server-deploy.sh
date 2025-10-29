#!/bin/bash
# Complete Redmine Deployment Script for DigitalOcean/Ubuntu Server
# Handles all issues encountered during deployment
# Run this directly ON your server as root

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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

print_info() {
    echo -e "${BLUE}[ℹ]${NC} $1"
}

clear
echo "================================================"
echo "  Redmine Complete Deployment Script"
echo "  For Ubuntu 22.04 LTS Servers"
echo "================================================"
echo ""
print_info "This script will install and configure:"
echo "  ✓ Ruby 2.7.8 via rbenv"
echo "  ✓ MySQL 8.0 database"
echo "  ✓ Redmine with WorkProof plugin"
echo "  ✓ Nginx web server"
echo "  ✓ Optional: SSL with Let's Encrypt"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    echo "Run: sudo su"
    echo "Then run this script again"
    exit 1
fi

# Confirm to proceed
read -p "Continue with installation? [yes/no]: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

# Collect configuration
echo ""
print_warning "=== Configuration ==="
echo ""

# MySQL passwords
read -sp "Choose MySQL root password: " MYSQL_ROOT_PASS
echo ""
read -sp "Choose Redmine database password: " DB_PASS
echo ""

# Domain configuration
read -p "Do you have a domain name? [yes/no] (no): " HAS_DOMAIN
HAS_DOMAIN=${HAS_DOMAIN:-no}

if [ "$HAS_DOMAIN" = "yes" ]; then
    read -p "Enter domain name (e.g., track.gocomart.com): " DOMAIN_NAME
    read -p "Setup SSL with Let's Encrypt? [yes/no] (yes): " SETUP_SSL
    SETUP_SSL=${SETUP_SSL:-yes}
    
    if [ "$SETUP_SSL" = "yes" ]; then
        read -p "Email for SSL certificate: " SSL_EMAIL
    fi
fi

echo ""
print_warning "=== Starting Installation ==="
echo ""

# Update system
print_status "Updating system packages..."
apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install system dependencies
print_status "Installing system dependencies..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    git curl wget build-essential \
    libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev \
    libmysqlclient-dev pkg-config \
    nginx mysql-server

print_status "Dependencies installed"

# Install rbenv
print_status "Installing rbenv..."
if [ ! -d "/root/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git /root/.rbenv
    echo 'export PATH="/root/.rbenv/bin:$PATH"' >> /root/.bashrc
    echo 'eval "$(rbenv init -)"' >> /root/.bashrc
fi

# Install ruby-build
if [ ! -d "/root/.rbenv/plugins/ruby-build" ]; then
    git clone https://github.com/rbenv/ruby-build.git /root/.rbenv/plugins/ruby-build
fi

# Load rbenv
export PATH="/root/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install Ruby 2.7.8
print_status "Installing Ruby 2.7.8 (this takes 10-15 minutes)..."
if ! rbenv versions 2>/dev/null | grep -q "2.7.8"; then
    rbenv install 2.7.8
fi
rbenv global 2.7.8
rbenv rehash

# Install Bundler (compatible version)
print_status "Installing Bundler 2.4.22..."
gem install bundler -v 2.4.22
rbenv rehash

print_status "Ruby environment ready"

# Configure MySQL
print_status "Configuring MySQL..."
systemctl start mysql
systemctl enable mysql

# Reset MySQL root password (works on fresh or existing MySQL)
print_info "Resetting MySQL root password..."
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS'; FLUSH PRIVILEGES;" 2>/dev/null || \
mysql -u root -p"$MYSQL_ROOT_PASS" -e "SELECT 1;" 2>/dev/null || \
print_warning "Setting MySQL password..."

# Try with sudo if password doesn't work yet
sudo mysql << EOF 2>/dev/null || true
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASS';
FLUSH PRIVILEGES;
EOF

# Create database and user
print_status "Creating Redmine database..."
mysql -u root -p"$MYSQL_ROOT_PASS" << EOF
DROP DATABASE IF EXISTS redmine_production;
CREATE DATABASE redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP USER IF EXISTS 'redmine'@'localhost';
CREATE USER 'redmine'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EOF

print_status "MySQL configured successfully"

# Clone Redmine repository
print_status "Cloning Redmine from GitHub..."
mkdir -p /var/www
if [ -d "/var/www/redmine" ]; then
    print_warning "Removing existing /var/www/redmine directory..."
    rm -rf /var/www/redmine
fi

cd /var/www
git clone git@github.com:muhsinzyne/redmine.git redmine || {
    print_error "Git clone failed. Make sure SSH key is added to GitHub!"
    print_info "Check: ssh -T git@github.com"
    exit 1
}

cd redmine
print_status "Repository cloned"

# Configure database connection
print_status "Configuring database connection..."
cat > config/database.yml << EOF
production:
  adapter: mysql2
  database: redmine_production
  host: localhost
  username: redmine
  password: "$DB_PASS"
  encoding: utf8mb4
  variables:
    transaction_isolation: "READ-COMMITTED"
EOF

# Generate secret key
print_status "Generating secret key..."
SECRET_KEY=$(openssl rand -hex 64)

# Create environment file
cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=false
EOF

# Install Ruby gems
print_status "Installing Ruby gems (this takes 5-10 minutes)..."
bundle install --without development test --jobs 2

# Create necessary directories
mkdir -p tmp tmp/pdf tmp/pids public/plugin_assets files log
chmod -R 755 files log tmp public/plugin_assets

print_status "Gems installed"

# Run database migrations
print_status "Running database migrations..."
RAILS_ENV=production bundle exec rake db:migrate

# Load default Redmine data
print_status "Loading default Redmine data..."
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

print_status "Database setup complete"

# Create optimized Puma configuration
print_status "Configuring Puma server..."
cat > config/puma.rb << 'EOF'
# Puma configuration
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

# Create systemd service
print_status "Creating systemd service..."
cat > /etc/systemd/system/redmine.service << 'EOF'
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
EOF

systemctl daemon-reload
systemctl enable redmine
systemctl start redmine

print_status "Redmine service started"

# Configure Nginx
print_status "Configuring Nginx..."

if [ "$HAS_DOMAIN" = "yes" ]; then
    SERVER_NAME="$DOMAIN_NAME"
else
    SERVER_NAME="_"
fi

cat > /etc/nginx/sites-available/redmine << EOF
upstream redmine {
    server 127.0.0.1:3000 fail_timeout=0;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name $SERVER_NAME;
    
    root /var/www/redmine/public;
    client_max_body_size 20M;
    
    location / {
        try_files \$uri @redmine;
    }
    
    location @redmine {
        proxy_pass http://redmine;
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    location ~* ^/assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
    
    location ~* ^/plugin_assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl restart nginx
systemctl enable nginx

print_status "Nginx configured"

# Setup SSL if domain provided
if [ "$HAS_DOMAIN" = "yes" ] && [ "$SETUP_SSL" = "yes" ]; then
    print_status "Setting up SSL with Let's Encrypt..."
    
    # Install Certbot if not already installed
    apt install -y certbot python3-certbot-nginx
    
    print_warning "Make sure DNS for $DOMAIN_NAME points to this server!"
    print_info "Testing DNS resolution..."
    
    if host "$DOMAIN_NAME" | grep -q "$(curl -s ifconfig.me)"; then
        print_status "DNS is configured correctly"
    else
        print_warning "DNS may not be ready yet. SSL setup might fail."
        print_warning "You can run this later: sudo certbot --nginx -d $DOMAIN_NAME"
        read -p "Continue anyway? [yes/no] (yes): " CONTINUE_SSL
        CONTINUE_SSL=${CONTINUE_SSL:-yes}
        
        if [ "$CONTINUE_SSL" != "yes" ]; then
            print_info "Skipping SSL for now"
            SETUP_SSL="no"
        fi
    fi
    
    if [ "$SETUP_SSL" = "yes" ]; then
        certbot --nginx -d "$DOMAIN_NAME" --email "$SSL_EMAIL" --agree-tos --non-interactive --redirect
        print_status "SSL certificate installed!"
    fi
fi

# Setup swap space
print_status "Configuring swap space (2GB)..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    sysctl -p > /dev/null
    print_status "Swap configured"
else
    print_status "Swap already exists"
fi

# Configure firewall
print_status "Configuring firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
print_status "Firewall configured"

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)

# Final health checks
print_status "Running health checks..."
sleep 5

echo ""
echo "================================================"
echo "  Service Status"
echo "================================================"
echo ""

# Check services
REDMINE_STATUS=$(systemctl is-active redmine)
MYSQL_STATUS=$(systemctl is-active mysql)
NGINX_STATUS=$(systemctl is-active nginx)

echo "Redmine: $REDMINE_STATUS"
echo "MySQL: $MYSQL_STATUS"
echo "Nginx: $NGINX_STATUS"

# Check application
echo ""
print_info "Testing application..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    print_status "Application is responding correctly!"
else
    print_warning "Application returned HTTP $HTTP_CODE"
    print_info "Check logs: tail -f /var/www/redmine/log/production.log"
fi

# Display final information
echo ""
echo "================================================"
echo "  🎉 Installation Complete!"
echo "================================================"
echo ""

if [ "$HAS_DOMAIN" = "yes" ] && [ "$SETUP_SSL" = "yes" ]; then
    ACCESS_URL="https://$DOMAIN_NAME"
else
    if [ "$HAS_DOMAIN" = "yes" ]; then
        ACCESS_URL="http://$DOMAIN_NAME"
    else
        ACCESS_URL="http://$PUBLIC_IP"
    fi
fi

print_warning "Access Information:"
echo "  URL: $ACCESS_URL"
echo "  IP: http://$PUBLIC_IP"
echo "  Login: admin"
echo "  Password: admin"
echo ""

print_warning "⚠️  IMPORTANT: Change admin password immediately!"
echo ""

print_warning "Database Credentials (SAVE THESE!):"
echo "  MySQL Root Password: $MYSQL_ROOT_PASS"
echo "  Redmine DB Password: $DB_PASS"
echo ""

print_warning "Useful Commands:"
echo "  Check status: systemctl status redmine"
echo "  View logs: tail -f /var/www/redmine/log/production.log"
echo "  Restart: systemctl restart redmine"
echo "  Monitor memory: free -h"
echo ""

print_warning "Services:"
echo "  Redmine: systemctl {start|stop|restart|status} redmine"
echo "  MySQL: systemctl {start|stop|restart|status} mysql"
echo "  Nginx: systemctl {start|stop|restart|status} nginx"
echo ""

# Save deployment info
cat > /root/redmine-deployment-info.txt << EOF
Redmine Deployment Information
===============================
Date: $(date)
Server IP: $PUBLIC_IP
Access URL: $ACCESS_URL

Login Credentials:
  Username: admin
  Password: admin (CHANGE THIS!)

Database Credentials:
  MySQL Root: $MYSQL_ROOT_PASS
  Redmine DB User: redmine
  Redmine DB Pass: $DB_PASS
  Database Name: redmine_production

Application Location:
  Directory: /var/www/redmine
  Logs: /var/www/redmine/log/
  Files: /var/www/redmine/files/

Services:
  Redmine: systemctl status redmine
  MySQL: systemctl status mysql
  Nginx: systemctl status nginx

Configuration Files:
  Database: /var/www/redmine/config/database.yml
  Environment: /var/www/redmine/.env.production
  Nginx: /etc/nginx/sites-available/redmine
  Systemd: /etc/systemd/system/redmine.service

Logs:
  Application: tail -f /var/www/redmine/log/production.log
  Puma: tail -f /var/www/redmine/log/puma.log
  Nginx Access: tail -f /var/log/nginx/access.log
  Nginx Error: tail -f /var/log/nginx/error.log
  System: journalctl -u redmine -f

Maintenance:
  Update code: cd /var/www/redmine && git pull && bundle install && systemctl restart redmine
  Backup DB: mysqldump -u root -p redmine_production > backup.sql
  Restore DB: mysql -u root -p redmine_production < backup.sql

Email Configuration:
  Already configured in config/configuration.yml
  SMTP: smtp.gmail.com:465
  Username: tokbox786@gmail.com

SSL Certificate (if configured):
  Domain: $DOMAIN_NAME
  Renewal: certbot renew (automatic)
  Check: certbot certificates
EOF

print_status "Deployment info saved to: /root/redmine-deployment-info.txt"

echo ""
print_status "🚀 Redmine is now running!"
print_info "Visit $ACCESS_URL and login with admin/admin"
echo ""

# Display quick health summary
echo "================================================"
echo "  Quick Health Check"
echo "================================================"
free -h | grep -E "(Mem|Swap)"
echo ""
df -h / | tail -1
echo ""
print_status "Installation script completed successfully!"

