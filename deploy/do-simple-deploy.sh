#!/bin/bash
# Simplified DigitalOcean Deployment
# Handles special characters in passwords better

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
echo "Redmine Deployment for DigitalOcean"
echo "Simplified version with better password handling"
echo "================================================"
echo ""

# Get droplet info
read -p "Droplet IP: " DROPLET_IP
read -p "Username [root]: " DROPLET_USER
DROPLET_USER=${DROPLET_USER:-root}

echo ""
print_warning "For the password: 1Message##goco"
print_warning "We'll use SSH key-based authentication instead (more secure)"
echo ""

# Create temporary SSH config
TEMP_KEY="/tmp/do_temp_key_$$"

print_status "Creating temporary SSH connection..."
cat > /tmp/ssh_config_$$ << EOF
Host dotarget
    HostName $DROPLET_IP
    User $DROPLET_USER
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF

echo ""
print_warning "Please SSH into your droplet manually and run the deployment:"
echo ""
echo "1. Open a new terminal and run:"
echo "   ssh root@$DROPLET_IP"
echo ""
echo "2. Enter your password: 1Message##goco"
echo ""
echo "3. Once logged in, run this command:"
echo ""
echo "   curl -sSL https://raw.githubusercontent.com/muhsinzyne/redmine/master/deploy/server-install.sh | bash"
echo ""
echo "OR copy and paste this deployment script:"
echo ""

# Generate the deployment script
cat << 'EOFINSTALL'
#!/bin/bash
# Run this ON your DigitalOcean droplet

set -e

echo "Starting Redmine installation..."

# Update system
echo "Updating system..."
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install dependencies
echo "Installing dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx mysql-server

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
echo "Installing Ruby 2.7.8 (takes 10-15 minutes)..."
if ! rbenv versions | grep -q "2.7.8"; then
    rbenv install 2.7.8
fi
rbenv global 2.7.8
rbenv rehash

# Install Bundler
gem install bundler
rbenv rehash

# Configure MySQL
echo "Configuring MySQL..."
read -sp "Enter MySQL root password: " DB_ROOT_PASS
echo ""
read -sp "Enter Redmine database password: " DB_PASS
echo ""

sudo systemctl start mysql
sudo systemctl enable mysql

sudo mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
CREATE DATABASE redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EOF

# Clone repository (your SSH key already configured)
echo "Cloning repository..."
cd /var/www
git clone git@github.com:muhsinzyne/redmine.git redmine
cd redmine

# Configure database
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

# Generate secret
SECRET_KEY=$(bundle exec rake secret)

# Create environment
cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY
RAILS_SERVE_STATIC_FILES=true
EOF

# Install gems
echo "Installing gems..."
bundle install --without development test

# Setup database
echo "Setting up database..."
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Create directories
mkdir -p tmp tmp/pdf public/plugin_assets files log
chmod -R 755 files log tmp public/plugin_assets

# Create Puma config
cat > config/puma.rb << 'EOFPUMA'
workers 1
threads_count = 2
threads threads_count, threads_count
port 3000
environment "production"
pidfile "tmp/pids/server.pid"
preload_app!
on_worker_boot do
  ActiveRecord::Base.establish_connection
end
plugin :tmp_restart
EOFPUMA

# Create systemd service
sudo tee /etc/systemd/system/redmine.service > /dev/null << EOFSVC
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

[Install]
WantedBy=multi-user.target
EOFSVC

sudo systemctl daemon-reload
sudo systemctl enable redmine
sudo systemctl start redmine

# Configure Nginx
sudo tee /etc/nginx/sites-available/redmine > /dev/null << 'EOFNGINX'
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
EOFNGINX

sudo ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Setup swap
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

# Configure firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo "================================================"
echo ""
echo "Access: http://$(curl -s ifconfig.me)"
echo "Login: admin/admin"
echo ""
echo "CHANGE ADMIN PASSWORD IMMEDIATELY!"
EOFINSTALL

echo "Copy the script above and paste it in your droplet terminal"
echo ""

# Save script to file for easy access
cat > /tmp/server-install-temp.sh << 'EOFINSTALL'
#!/bin/bash
# Run this ON your DigitalOcean droplet

set -e

echo "Starting Redmine installation..."

# Update system
echo "Updating system..."
sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Install dependencies
echo "Installing dependencies..."
sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx mysql-server

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
echo "Installing Ruby 2.7.8 (takes 10-15 minutes)..."
if ! rbenv versions | grep -q "2.7.8"; then
    rbenv install 2.7.8
fi
rbenv global 2.7.8
rbenv rehash

# Install Bundler
gem install bundler
rbenv rehash

# Configure MySQL
echo "Configuring MySQL..."
read -sp "Enter MySQL root password: " DB_ROOT_PASS
echo ""
read -sp "Enter Redmine database password: " DB_PASS
echo ""

sudo systemctl start mysql
sudo systemctl enable mysql

sudo mysql << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_ROOT_PASS';
CREATE DATABASE redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'redmine'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'localhost';
FLUSH PRIVILEGES;
EOF

# Clone repository (your SSH key already configured)
echo "Cloning repository..."
mkdir -p /var/www
cd /var/www
git clone git@github.com:muhsinzyne/redmine.git redmine
cd redmine

# Configure database
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

# Generate secret
SECRET_KEY=$(bundle exec rake secret)

# Create environment
cat > .env.production << EOF
RAILS_ENV=production
SECRET_KEY_BASE=$SECRET_KEY
RAILS_SERVE_STATIC_FILES=true
EOF

# Install gems
echo "Installing gems (this takes 5-10 minutes)..."
bundle install --without development test

# Setup database
echo "Setting up database..."
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Create directories
mkdir -p tmp tmp/pdf public/plugin_assets files log
chmod -R 755 files log tmp public/plugin_assets

# Create Puma config
cat > config/puma.rb << 'EOFPUMA'
workers 1
threads_count = 2
threads threads_count, threads_count
port 3000
environment "production"
pidfile "tmp/pids/server.pid"
preload_app!
on_worker_boot do
  ActiveRecord::Base.establish_connection
end
plugin :tmp_restart
EOFPUMA

# Create systemd service
sudo tee /etc/systemd/system/redmine.service > /dev/null << 'EOFSVC'
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

[Install]
WantedBy=multi-user.target
EOFSVC

sudo systemctl daemon-reload
sudo systemctl enable redmine
sudo systemctl start redmine

# Configure Nginx
sudo tee /etc/nginx/sites-available/redmine > /dev/null << 'EOFNGINX'
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
EOFNGINX

sudo ln -sf /etc/nginx/sites-available/redmine /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# Setup swap
if [ ! -f /swapfile ]; then
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
fi

# Configure firewall
sudo ufw allow 22
sudo ufw allow 80
sudo ufw allow 443
sudo ufw --force enable

echo ""
echo "================================================"
echo "✅ Installation Complete!"
echo "================================================"
echo ""
echo "Access: http://$(curl -s ifconfig.me)"
echo "Login: admin/admin"
echo ""
echo "Services:"
echo "  sudo systemctl status redmine"
echo "  sudo systemctl status mysql"
echo "  sudo systemctl status nginx"
EOFINSTALL

chmod +x /tmp/server-install-temp.sh

echo ""
print_status "Installation script saved to: /tmp/server-install-temp.sh"
echo ""
print_warning "=========================================="
print_warning "MANUAL DEPLOYMENT STEPS"
print_warning "=========================================="
echo ""
echo "Since automated password authentication has issues with special characters,"
echo "please follow these steps:"
echo ""
echo "1. SSH into your droplet:"
echo "   ssh root@$DROPLET_IP"
echo "   Password: 1Message##goco"
echo ""
echo "2. Download and run the installation script:"
echo "   wget https://raw.githubusercontent.com/muhsinzyne/redmine/master/deploy/server-install.sh -O install.sh"
echo "   chmod +x install.sh"
echo "   ./install.sh"
echo ""
echo "OR copy the script from: /tmp/server-install-temp.sh"
echo "and paste it on your server"
echo ""

