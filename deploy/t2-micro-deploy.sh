#!/bin/bash
# Deploy Redmine to AWS t2.micro EC2 Instance
# Optimized for 1GB RAM - Direct installation (no Docker)

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
echo "Redmine Deployment for t2.micro EC2"
echo "Optimized for 1GB RAM"
echo "================================================"
echo ""

# Prompt for EC2 details
read -p "EC2 Public IP: " EC2_IP
read -p "SSH Key Path (e.g., ~/.ssh/my-key.pem): " SSH_KEY
read -p "EC2 Username [ubuntu]: " EC2_USER
EC2_USER=${EC2_USER:-ubuntu}

# Validate inputs
if [ -z "$EC2_IP" ] || [ -z "$SSH_KEY" ]; then
    print_error "EC2 IP and SSH Key are required!"
    exit 1
fi

if [ ! -f "$SSH_KEY" ]; then
    print_error "SSH key not found: $SSH_KEY"
    exit 1
fi

# Test SSH connection
print_status "Testing SSH connection..."
if ! ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" "echo 'Connection successful'" &>/dev/null; then
    print_error "Cannot connect to EC2. Please check:"
    echo "  1. IP address is correct"
    echo "  2. Security group allows SSH from your IP"
    echo "  3. SSH key permissions (chmod 400 $SSH_KEY)"
    exit 1
fi
print_status "SSH connection successful"

# Prompt for database configuration
echo ""
print_warning "Database Configuration"
read -p "Database Host [localhost]: " DB_HOST
DB_HOST=${DB_HOST:-localhost}

if [ "$DB_HOST" = "localhost" ]; then
    print_status "Will install MySQL locally on EC2"
    read -p "MySQL Root Password: " -s DB_ROOT_PASSWORD
    echo ""
    read -p "Redmine DB Password: " -s DB_PASSWORD
    echo ""
else
    print_status "Will connect to external database: $DB_HOST"
    read -p "Database Username [admin]: " DB_USERNAME
    DB_USERNAME=${DB_USERNAME:-admin}
    read -p "Database Password: " -s DB_PASSWORD
    echo ""
    read -p "Database Name [redmine_production]: " DB_NAME
    DB_NAME=${DB_NAME:-redmine_production}
fi

# Generate secret key
print_status "Generating secret key..."
SECRET_KEY=$(openssl rand -hex 64)

# Prepare deployment package
print_status "Preparing deployment package..."
cd "$(dirname "$0")/.."
./deploy/prepare-deployment.sh

PACKAGE=$(ls -t deploy/package/redmine-deployment-*.tar.gz | head -1)
print_status "Package ready: $PACKAGE"

# Upload package to EC2
print_status "Uploading application to EC2..."
scp -i "$SSH_KEY" "$PACKAGE" "$EC2_USER@$EC2_IP:/tmp/redmine-deployment.tar.gz"

# Create deployment script for EC2
print_status "Creating server-side deployment script..."
cat > /tmp/ec2-install.sh << 'EOFSCRIPT'
#!/bin/bash
set -e

echo "Starting t2.micro optimized installation..."

# Update system
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install dependencies (minimal for t2.micro)
sudo apt install -y \
    git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx

# Install rbenv
if [ ! -d "$HOME/.rbenv" ]; then
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(~/.rbenv/bin/rbenv init -)"
fi

# Install ruby-build
if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

# Install Ruby 2.7.8
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(~/.rbenv/bin/rbenv init -)"

if ! rbenv versions | grep -q "2.7.8"; then
    rbenv install 2.7.8
fi
rbenv global 2.7.8
rbenv rehash

# Install Bundler (compatible with Ruby 2.7.8)
gem install bundler -v 2.4.22
rbenv rehash

echo "✓ Dependencies installed"
EOFSCRIPT

# Upload and run installation script
scp -i "$SSH_KEY" /tmp/ec2-install.sh "$EC2_USER@$EC2_IP:/tmp/"
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" "bash /tmp/ec2-install.sh"

# Install and configure MySQL if needed
if [ "$DB_HOST" = "localhost" ]; then
    print_status "Installing MySQL on EC2..."
    ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" << EOFMYSQL
sudo apt install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL and create database
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASSWORD';"
sudo mysql -u root -p'$DB_ROOT_PASSWORD' << EOF
CREATE DATABASE redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EOF

echo "✓ MySQL installed and configured"
EOFMYSQL
fi

# Deploy application
print_status "Deploying Redmine application..."
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" << EOFDEPLOY
# Create application directory
sudo mkdir -p /var/www/redmine
sudo chown $EC2_USER:$EC2_USER /var/www/redmine
cd /var/www/redmine

# Extract application
tar -xzf /tmp/redmine-deployment.tar.gz

# Create production database configuration
cat > config/database.yml << EOF
production:
  adapter: mysql2
  database: ${DB_NAME:-redmine_production}
  host: $DB_HOST
  username: ${DB_USERNAME:-redmine}
  password: "$DB_PASSWORD"
  encoding: utf8mb4
  variables:
    transaction_isolation: "READ-COMMITTED"
EOF

# Create environment file
cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY
RAILS_SERVE_STATIC_FILES=true
EOF

# Install gems (with minimal memory usage)
export PATH="$HOME/.rbenv/bin:$PATH"
eval "\$(rbenv init -)"
bundle install --without development test --jobs 1 --retry 3

# Create directories
mkdir -p tmp tmp/pdf public/plugin_assets files log
chmod -R 755 files log tmp public/plugin_assets

# Run migrations
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

echo "✓ Application deployed"
EOFDEPLOY

# Configure Puma for low memory
print_status "Configuring Puma for t2.micro (low memory)..."
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" << 'EOFPUMA'
cd /var/www/redmine

# Create optimized puma config for 1GB RAM
cat > config/puma.rb << 'EOF'
# Puma configuration optimized for t2.micro (1GB RAM)

# Use fewer workers and threads to save memory
workers ENV.fetch("WEB_CONCURRENCY") { 1 }  # Only 1 worker for t2.micro
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 2 }
threads threads_count, threads_count

port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "production" }

pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Reduce memory usage
preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

plugin :tmp_restart
EOF

echo "✓ Puma configured for low memory"
EOFPUMA

# Create systemd service
print_status "Creating systemd service..."
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" << EOFSYSTEMD
sudo tee /etc/systemd/system/redmine.service > /dev/null << EOF
[Unit]
Description=Redmine Application Server
After=network.target mysql.service

[Service]
Type=simple
User=$EC2_USER
WorkingDirectory=/var/www/redmine
Environment=RAILS_ENV=production
EnvironmentFile=/var/www/redmine/.env.production
ExecStart=/home/$EC2_USER/.rbenv/shims/bundle exec puma -C config/puma.rb
Restart=always
RestartSec=10
StandardOutput=append:/var/www/redmine/log/puma.log
StandardError=append:/var/www/redmine/log/puma.log

# Memory limits for t2.micro
MemoryMax=800M
MemoryHigh=700M

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable redmine
sudo systemctl start redmine

echo "✓ Redmine service created and started"
EOFSYSTEMD

# Configure Nginx
print_status "Configuring Nginx..."
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" << 'EOFNGINX'
sudo tee /etc/nginx/sites-available/redmine > /dev/null << 'EOF'
upstream redmine {
    server 127.0.0.1:3000 fail_timeout=0;
}

server {
    listen 80 default_server;
    server_name _;
    
    root /var/www/redmine/public;
    client_max_body_size 20M;
    
    # Optimize for low memory
    keepalive_timeout 30;
    keepalive_requests 50;
    
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
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Static assets
    location ~* ^/assets/ {
        expires 1y;
        add_header Cache-Control public;
    }
    
    # Plugin assets
    location ~* ^/plugin_assets/ {
        expires 1y;
        add_header Cache-Control public;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "✓ Nginx configured"
EOFNGINX

# Configure swap for t2.micro (important!)
print_status "Setting up swap space (crucial for t2.micro)..."
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" << EOFSWAP
# Create 2GB swap file
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    
    # Optimize swap usage
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    
    echo "✓ Swap configured (2GB)"
fi
EOFSWAP

# Check service status
print_status "Checking service status..."
ssh -i "$SSH_KEY" "$EC2_USER@$EC2_IP" << EOFSTATUS
echo "Service Status:"
sudo systemctl status redmine --no-pager | head -10
echo ""
echo "Testing application:"
sleep 5
curl -I http://localhost/ | head -5
EOFSTATUS

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
print_status "Your Redmine is now running!"
print_warning "Access URL: http://$EC2_IP"
print_warning "Default login: admin/admin (CHANGE IMMEDIATELY!)"
echo ""
print_warning "Important for t2.micro:"
echo "  - 2GB swap space configured (handles memory spikes)"
echo "  - Puma configured with minimal workers (1 worker, 2 threads)"
echo "  - Good for 5-15 concurrent users"
echo "  - Monitor memory: ssh -i $SSH_KEY $EC2_USER@$EC2_IP 'free -h'"
echo ""
print_warning "Next steps:"
echo "  1. Test: http://$EC2_IP"
echo "  2. Change admin password"
echo "  3. Configure email in Admin panel"
echo "  4. Optionally setup domain and SSL (see SSL_DOMAIN_SETUP.md)"
echo ""
print_warning "To setup SSL with your domain, run:"
echo "  ssh -i $SSH_KEY $EC2_USER@$EC2_IP"
echo "  sudo certbot --nginx -d yourdomain.com"

