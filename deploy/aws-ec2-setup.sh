#!/bin/bash
# AWS EC2 Setup Script for Redmine
# Run this script on a fresh Ubuntu 22.04 EC2 instance

set -e

echo "================================================"
echo "Redmine AWS EC2 Setup Script"
echo "================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install dependencies
print_status "Installing dependencies..."
sudo apt install -y \
    git curl libssl-dev libreadline-dev zlib1g-dev \
    autoconf bison build-essential libyaml-dev \
    libreadline-dev libncurses5-dev libffi-dev libgdbm-dev \
    imagemagick libmagickwand-dev libmysqlclient-dev \
    nginx

# Install rbenv
if [ ! -d "$HOME/.rbenv" ]; then
    print_status "Installing rbenv..."
    git clone https://github.com/rbenv/rbenv.git ~/.rbenv
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    export PATH="$HOME/.rbenv/bin:$PATH"
    eval "$(~/.rbenv/bin/rbenv init -)"
else
    print_status "rbenv already installed"
fi

# Install ruby-build
if [ ! -d "$HOME/.rbenv/plugins/ruby-build" ]; then
    print_status "Installing ruby-build..."
    git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
else
    print_status "ruby-build already installed"
fi

# Install Ruby 2.7.8
print_status "Installing Ruby 2.7.8 (this may take a while)..."
if ! rbenv versions | grep -q "2.7.8"; then
    rbenv install 2.7.8
fi
rbenv global 2.7.8
rbenv rehash

# Install Bundler
print_status "Installing Bundler..."
gem install bundler
rbenv rehash

# Create application directory
print_status "Creating application directory..."
sudo mkdir -p /var/www/redmine
sudo chown $USER:$USER /var/www/redmine

print_status "Setup complete!"
print_warning "Next steps:"
echo "1. Upload your Redmine application to /var/www/redmine"
echo "2. Create .env.production with database credentials"
echo "3. Run bundle install"
echo "4. Run database migrations"
echo "5. Configure Nginx and Puma"
echo ""
echo "See DEPLOYMENT_GUIDE.md for detailed instructions"

