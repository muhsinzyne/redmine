#!/bin/bash
# Deploy Redmine to DigitalOcean Droplet
# Supports password-based SSH authentication

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

echo "================================================"
echo "Redmine Deployment for DigitalOcean Droplet"
echo "================================================"
echo ""

# Check if sshpass is installed (needed for password auth)
if ! command -v sshpass &> /dev/null; then
    print_warning "Installing sshpass for password authentication..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install hudochenkov/sshpass/sshpass
        else
            print_error "Homebrew not found. Please install sshpass manually:"
            echo "  brew install hudochenkov/sshpass/sshpass"
            exit 1
        fi
    else
        # Linux
        sudo apt install -y sshpass
    fi
fi

# Prompt for droplet details
print_warning "DigitalOcean Droplet Information"
read -p "Droplet IP Address: " DROPLET_IP
read -p "Username [root]: " DROPLET_USER
DROPLET_USER=${DROPLET_USER:-root}
read -sp "Password: " DROPLET_PASSWORD
echo ""

# Validate inputs
if [ -z "$DROPLET_IP" ] || [ -z "$DROPLET_PASSWORD" ]; then
    print_error "IP address and password are required!"
    exit 1
fi

# Create SSH alias for easier commands
SSH_CMD="sshpass -p '$DROPLET_PASSWORD' ssh -o StrictHostKeyChecking=no $DROPLET_USER@$DROPLET_IP"
SCP_CMD="sshpass -p '$DROPLET_PASSWORD' scp -o StrictHostKeyChecking=no"

# Test connection
print_status "Testing connection to droplet..."
if ! $SSH_CMD "echo 'Connection successful'" &>/dev/null; then
    print_error "Cannot connect to droplet. Please check:"
    echo "  1. IP address is correct"
    echo "  2. Password is correct"
    echo "  3. Firewall allows SSH (port 22)"
    exit 1
fi
print_status "Connection successful!"

# Get droplet info
print_status "Checking droplet specifications..."
$SSH_CMD "echo 'Hostname:' \$(hostname) && echo 'Memory:' \$(free -h | grep Mem | awk '{print \$2}') && echo 'OS:' \$(lsb_release -ds)"

# Prompt for configuration
echo ""
print_warning "Configuration Options"
read -p "Install MySQL locally on droplet? [yes/no] (yes): " INSTALL_MYSQL
INSTALL_MYSQL=${INSTALL_MYSQL:-yes}

if [ "$INSTALL_MYSQL" = "yes" ]; then
    read -sp "Choose MySQL Root Password: " DB_ROOT_PASSWORD
    echo ""
    read -sp "Choose Redmine Database Password: " DB_PASSWORD
    echo ""
    DB_HOST="localhost"
    DB_NAME="redmine_production"
    DB_USERNAME="redmine"
else
    read -p "Database Host: " DB_HOST
    read -p "Database Name [redmine_production]: " DB_NAME
    DB_NAME=${DB_NAME:-redmine_production}
    read -p "Database Username [redmine]: " DB_USERNAME
    DB_USERNAME=${DB_USERNAME:-redmine}
    read -sp "Database Password: " DB_PASSWORD
    echo ""
fi

# Domain configuration
read -p "Do you have a domain name? [yes/no] (no): " HAS_DOMAIN
HAS_DOMAIN=${HAS_DOMAIN:-no}

if [ "$HAS_DOMAIN" = "yes" ]; then
    read -p "Domain name (e.g., redmine.yourdomain.com): " DOMAIN_NAME
    read -p "Setup SSL with Let's Encrypt? [yes/no] (yes): " SETUP_SSL
    SETUP_SSL=${SETUP_SSL:-yes}
fi

# Git configuration
echo ""
print_warning "Source Code Deployment Method"
echo "1. Git clone from GitHub (recommended - your SSH key already configured)"
echo "2. Upload via SCP (simpler, no git needed)"
read -p "Choose method [1/2] (1): " DEPLOY_METHOD
DEPLOY_METHOD=${DEPLOY_METHOD:-1}

if [ "$DEPLOY_METHOD" = "1" ]; then
    print_status "Will use git@github.com:muhsinzyne/redmine.git"
    print_status "Using your existing SSH key from server"
    GIT_REPO="git@github.com:muhsinzyne/redmine.git"
fi

# Generate secret key
print_status "Generating secret key..."
SECRET_KEY=$(openssl rand -hex 64)

echo ""
echo "================================================"
echo "Starting Deployment..."
echo "================================================"
echo ""

# Update system
print_status "Updating system packages..."
$SSH_CMD "sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y"

# Install dependencies
print_status "Installing dependencies..."
$SSH_CMD "sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx"

# Install MySQL if needed
if [ "$INSTALL_MYSQL" = "yes" ]; then
    print_status "Installing MySQL..."
    $SSH_CMD "sudo DEBIAN_FRONTEND=noninteractive apt install -y mysql-server"
    
    # Configure MySQL
    print_status "Configuring MySQL..."
    $SSH_CMD "sudo systemctl start mysql && sudo systemctl enable mysql"
    
    # Secure MySQL and create database
    $SSH_CMD "sudo mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASSWORD';
CREATE DATABASE redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EOF"
    print_status "MySQL configured"
fi

# Install rbenv and Ruby
print_status "Installing Ruby 2.7.8 (this takes 10-15 minutes)..."
$SSH_CMD "bash -s" << 'EOFRUBY'
# Install rbenv
if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
fi

# Install ruby-build
if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

# Load rbenv
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install Ruby 2.7.8
if ! rbenv versions | grep -q "2.7.8"; then
    rbenv install 2.7.8
fi
rbenv global 2.7.8
rbenv rehash

# Install Bundler (compatible with Ruby 2.7.8)
gem install bundler -v 2.4.22
rbenv rehash

echo "Ruby 2.7.8 installed"
EOFRUBY

print_status "Ruby installation complete"

# Deploy application
if [ "$DEPLOY_METHOD" = "1" ]; then
    # Git deployment
    print_status "Using your existing SSH key from the server..."
    
    # Configure SSH for GitHub (if not already done)
    $SSH_CMD "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
              if [ ! -f ~/.ssh/config ] || ! grep -q 'github.com' ~/.ssh/config; then \
                  cat >> ~/.ssh/config << EOF

Host github.com
    HostName github.com
    User git
    StrictHostKeyChecking no
EOF
              fi"
    
    # Test GitHub connection
    print_status "Testing GitHub SSH connection..."
    if $SSH_CMD "ssh -T git@github.com 2>&1 | grep -q 'successfully authenticated'"; then
        print_status "GitHub SSH authentication successful!"
    else
        print_warning "GitHub SSH test completed (this is normal)"
    fi
    
    # Clone repository
    print_status "Cloning repository from GitHub..."
    $SSH_CMD "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && \
              git clone git@github.com:muhsinzyne/redmine.git /var/www/redmine"
else
    # SCP deployment
    print_status "Preparing deployment package..."
    cd "$(dirname "$0")/.."
    ./deploy/prepare-deployment.sh
    
    PACKAGE=$(ls -t deploy/package/redmine-deployment-*.tar.gz | head -1)
    print_status "Uploading package to droplet..."
    
    $SCP_CMD "$PACKAGE" "$DROPLET_USER@$DROPLET_IP:/tmp/redmine-deployment.tar.gz"
    
    print_status "Extracting application..."
    $SSH_CMD "sudo mkdir -p /var/www/redmine && \
              sudo chown $DROPLET_USER:$DROPLET_USER /var/www/redmine && \
              cd /var/www/redmine && \
              tar -xzf /tmp/redmine-deployment.tar.gz"
fi

# Configure application
print_status "Configuring application..."
$SSH_CMD "cd /var/www/redmine && cat > config/database.yml << EOF
production:
  adapter: mysql2
  database: $DB_NAME
  host: $DB_HOST
  username: $DB_USERNAME
  password: \"$DB_PASSWORD\"
  encoding: utf8mb4
  variables:
    transaction_isolation: \"READ-COMMITTED\"
EOF"

# Copy configuration.yml
$SSH_CMD "cd /var/www/redmine && cp config/configuration.yml config/configuration.yml.production"

# Create environment file
$SSH_CMD "cd /var/www/redmine && cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY
RAILS_SERVE_STATIC_FILES=true
EOF"

# Install gems and setup
print_status "Installing gems (this takes 5-10 minutes)..."
$SSH_CMD "cd /var/www/redmine && \
          export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && \
          eval \"\$(rbenv init -)\" && \
          bundle install --without development test --jobs 1 && \
          mkdir -p tmp tmp/pdf public/plugin_assets files log && \
          chmod -R 755 files log tmp public/plugin_assets"

# Run migrations
print_status "Running database migrations..."
$SSH_CMD "cd /var/www/redmine && \
          export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && \
          eval \"\$(rbenv init -)\" && \
          RAILS_ENV=production bundle exec rake db:migrate && \
          RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data"

# Configure Puma (optimized for small droplet)
print_status "Configuring Puma..."
$SSH_CMD "cd /var/www/redmine && cat > config/puma.rb << 'EOF'
# Puma configuration optimized for small droplet
workers ENV.fetch(\"WEB_CONCURRENCY\") { 1 }
threads_count = ENV.fetch(\"RAILS_MAX_THREADS\") { 2 }
threads threads_count, threads_count

port ENV.fetch(\"PORT\") { 3000 }
environment ENV.fetch(\"RAILS_ENV\") { \"production\" }
pidfile ENV.fetch(\"PIDFILE\") { \"tmp/pids/server.pid\" }

preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

plugin :tmp_restart
EOF"

# Create systemd service
print_status "Creating systemd service..."
$SSH_CMD "sudo tee /etc/systemd/system/redmine.service > /dev/null << EOF
[Unit]
Description=Redmine Application Server
After=network.target mysql.service

[Service]
Type=simple
User=$DROPLET_USER
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
EOF"

$SSH_CMD "sudo systemctl daemon-reload && \
          sudo systemctl enable redmine && \
          sudo systemctl start redmine"

print_status "Redmine service started"

# Configure Nginx
print_status "Configuring Nginx..."
$SSH_CMD "sudo tee /etc/nginx/sites-available/redmine > /dev/null << 'EOF'
upstream redmine {
    server 127.0.0.1:3000 fail_timeout=0;
}

server {
    listen 80 default_server;
    server_name _;
    
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
        add_header Cache-Control public;
    }
    
    location ~* ^/plugin_assets/ {
        expires 1y;
        add_header Cache-Control public;
    }
}
EOF"

$SSH_CMD "sudo ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/ && \
          sudo rm -f /etc/nginx/sites-enabled/default && \
          sudo nginx -t && \
          sudo systemctl restart nginx && \
          sudo systemctl enable nginx"

print_status "Nginx configured"

# Setup swap if needed
print_status "Configuring swap space..."
$SSH_CMD "if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo 'Swap configured'
fi"

# Setup SSL if requested
if [ "$HAS_DOMAIN" = "yes" ] && [ "$SETUP_SSL" = "yes" ]; then
    print_status "Setting up SSL with Let's Encrypt..."
    
    # Install Certbot
    $SSH_CMD "sudo apt install -y certbot python3-certbot-nginx"
    
    # Update Nginx with domain
    $SSH_CMD "sudo sed -i 's/server_name _;/server_name $DOMAIN_NAME;/' /etc/nginx/sites-available/redmine && \
              sudo nginx -t && \
              sudo systemctl reload nginx"
    
    # Get SSL certificate
    print_warning "Getting SSL certificate for $DOMAIN_NAME..."
    print_warning "Make sure your domain points to $DROPLET_IP"
    read -p "Press ENTER when DNS is configured..."
    
    $SSH_CMD "sudo certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email tokbox786@gmail.com"
    
    print_status "SSL configured!"
fi

# Configure firewall
print_status "Configuring firewall..."
$SSH_CMD "sudo ufw allow 22 && \
          sudo ufw allow 80 && \
          sudo ufw allow 443 && \
          sudo ufw --force enable"

# Final checks
print_status "Running final checks..."
sleep 5
HEALTH_CHECK=$($SSH_CMD "curl -s -o /dev/null -w '%{http_code}' http://localhost/")

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""

if [ "$HEALTH_CHECK" = "200" ]; then
    print_status "✅ Application is running successfully!"
else
    print_warning "⚠️ Application returned HTTP $HEALTH_CHECK"
fi

echo ""
print_warning "Access Information:"
if [ "$HAS_DOMAIN" = "yes" ] && [ "$SETUP_SSL" = "yes" ]; then
    echo "  URL: https://$DOMAIN_NAME"
else
    echo "  URL: http://$DROPLET_IP"
fi
echo "  Default Login: admin"
echo "  Default Password: admin"
echo ""
print_warning "IMPORTANT: Change admin password immediately!"
echo ""
print_warning "Services:"
echo "  Check status: systemctl status redmine"
echo "  View logs: tail -f /var/www/redmine/log/production.log"
echo "  Restart: sudo systemctl restart redmine"
echo ""
print_warning "Useful Commands:"
echo "  SSH: sshpass -p 'YOUR_PASSWORD' ssh $DROPLET_USER@$DROPLET_IP"
echo "  Monitor: free -h (check memory)"
echo "  Logs: journalctl -u redmine -f"
echo ""

# Save connection info
cat > deployment-info.txt << EOF
DigitalOcean Redmine Deployment
================================

Droplet IP: $DROPLET_IP
Username: $DROPLET_USER
URL: http://$DROPLET_IP
$([ "$HAS_DOMAIN" = "yes" ] && echo "Domain: https://$DOMAIN_NAME")

Default Login:
  Username: admin
  Password: admin (CHANGE THIS!)

SSH Connection:
  sshpass -p 'YOUR_PASSWORD' ssh $DROPLET_USER@$DROPLET_IP

Services:
  Redmine: sudo systemctl status redmine
  MySQL: sudo systemctl status mysql
  Nginx: sudo systemctl status nginx

Logs:
  Application: tail -f /var/www/redmine/log/production.log
  Puma: tail -f /var/www/redmine/log/puma.log
  Nginx: sudo tail -f /var/log/nginx/error.log

Database:
  Host: $DB_HOST
  Name: $DB_NAME
  User: $DB_USERNAME

Deployed: $(date)
EOF

print_status "Deployment info saved to: deployment-info.txt"
echo ""
print_status "🎉 Deployment successful! Visit http://$DROPLET_IP to see your Redmine!"

