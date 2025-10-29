#!/bin/bash
# Redmine Installation Script
# Run this directly ON your DigitalOcean droplet (or any Ubuntu server)

set -e

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

echo "================================================"
echo "Redmine Installation for Ubuntu Server"
echo "Optimized for DigitalOcean Droplets"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root (or use sudo)"
    exit 1
fi

# Get current user
CURRENT_USER=${SUDO_USER:-$USER}

# Update system
print_status "Updating system packages..."
apt update && DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install dependencies
print_status "Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx mysql-server

# Install rbenv for root
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

# Load rbenv in current session
export PATH="/root/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install Ruby 2.7.8
print_status "Installing Ruby 2.7.8 (this takes 10-15 minutes, please wait)..."
if ! rbenv versions 2>/dev/null | grep -q "2.7.8"; then
    rbenv install 2.7.8
fi
rbenv global 2.7.8
rbenv rehash

# Install Bundler
print_status "Installing Bundler..."
gem install bundler
rbenv rehash

print_status "Ruby 2.7.8 installed successfully"

# Configure MySQL
print_status "Configuring MySQL database..."
systemctl start mysql
systemctl enable mysql

echo ""
print_warning "MySQL Configuration"
read -sp "Choose MySQL root password: " DB_ROOT_PASS
echo ""
read -sp "Choose Redmine database password: " DB_PASS
echo ""

# Configure MySQL
mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
CREATE DATABASE IF NOT EXISTS redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'redmine'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EOF

print_status "MySQL configured"

# Clone repository
print_status "Cloning Redmine repository from GitHub..."
echo ""
print_warning "Make sure your SSH key is added to GitHub!"
echo "Testing GitHub connection..."

if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    print_status "GitHub SSH key is configured"
else
    print_warning "GitHub SSH connection test (this message is normal)"
fi

mkdir -p /var/www
if [ -d "/var/www/redmine" ]; then
    print_warning "Directory /var/www/redmine exists. Removing..."
    rm -rf /var/www/redmine
fi

cd /var/www
git clone git@github.com:muhsinzyne/redmine.git redmine
cd redmine

print_status "Repository cloned"

# Configure database
print_status "Creating database configuration..."
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
SECRET_KEY=$(bundle exec rake secret)

# Create environment file
cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY
RAILS_SERVE_STATIC_FILES=true
EOF

# Install gems
print_status "Installing Ruby gems (this takes 5-10 minutes)..."
bundle install --without development test --jobs 2

# Create directories
mkdir -p tmp tmp/pdf public/plugin_assets files log
chmod -R 755 files log tmp public/plugin_assets

# Run migrations
print_status "Running database migrations..."
RAILS_ENV=production bundle exec rake db:migrate

print_status "Loading default Redmine data..."
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Create optimized Puma configuration
print_status "Configuring Puma server..."
cat > config/puma.rb << 'EOFPUMA'
# Optimized Puma configuration
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
EOFPUMA

# Create systemd service
print_status "Creating systemd service..."
cat > /etc/systemd/system/redmine.service << 'EOFSVC'
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
EOFSVC

systemctl daemon-reload
systemctl enable redmine
systemctl start redmine

print_status "Redmine service started"

# Configure Nginx
print_status "Configuring Nginx..."
cat > /etc/nginx/sites-available/redmine << 'EOFNGINX'
upstream redmine {
    server 127.0.0.1:3000 fail_timeout=0;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
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
EOFNGINX

ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx
systemctl enable nginx

print_status "Nginx configured"

# Setup swap space
print_status "Configuring swap space (2GB)..."
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
    sysctl -p
    print_status "Swap configured"
else
    print_status "Swap already exists"
fi

# Configure firewall
print_status "Configuring firewall..."
ufw allow 22
ufw allow 80
ufw allow 443
ufw --force enable

# Get public IP
PUBLIC_IP=$(curl -s ifconfig.me)

# Final health check
print_status "Running health check..."
sleep 5
if curl -s -o /dev/null -w "%{http_code}" http://localhost/ | grep -q "200"; then
    HEALTH="✅ Healthy"
else
    HEALTH="⚠️ Check logs"
fi

echo ""
echo "================================================"
echo "🎉 Installation Complete!"
echo "================================================"
echo ""
print_status "Your Redmine is ready!"
echo ""
print_warning "Access Information:"
echo "  URL: http://$PUBLIC_IP"
echo "  Login: admin"
echo "  Password: admin"
echo ""
print_warning "⚠️ CHANGE ADMIN PASSWORD IMMEDIATELY!"
echo ""
print_warning "Service Status:"
echo "  Redmine: $(systemctl is-active redmine)"
echo "  MySQL: $(systemctl is-active mysql)"
echo "  Nginx: $(systemctl is-active nginx)"
echo "  Health: $HEALTH"
echo ""
print_warning "Useful Commands:"
echo "  Check status: systemctl status redmine"
echo "  View logs: tail -f /var/www/redmine/log/production.log"
echo "  Restart: systemctl restart redmine"
echo "  Monitor: free -h"
echo ""
print_warning "Next Steps:"
echo "  1. Visit http://$PUBLIC_IP"
echo "  2. Login with admin/admin"
echo "  3. Change admin password"
echo "  4. Configure email in Admin → Settings → Email notifications"
echo "  5. Optional: Setup domain and SSL (see SSL_DOMAIN_SETUP.md)"
echo ""
print_status "Deployment successful! 🚀"

