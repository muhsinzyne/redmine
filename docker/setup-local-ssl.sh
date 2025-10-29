#!/bin/bash
# Setup local SSL certificates for HTTPS development

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
echo "Setup Local SSL for HTTPS Development"
echo "================================================"

# Check if mkcert is installed
if ! command -v mkcert &> /dev/null; then
    print_error "mkcert not found. Installing..."
    
    # Detect OS and install
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install mkcert
            brew install nss # for Firefox
        else
            print_error "Homebrew not found. Please install from https://brew.sh"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt &> /dev/null; then
            sudo apt update
            sudo apt install -y mkcert
        elif command -v yum &> /dev/null; then
            sudo yum install -y mkcert
        else
            print_error "Package manager not supported. Please install mkcert manually"
            print_warning "Visit: https://github.com/FiloSottile/mkcert#installation"
            exit 1
        fi
    else
        print_error "OS not supported. Please install mkcert manually"
        print_warning "Visit: https://github.com/FiloSottile/mkcert#installation"
        exit 1
    fi
fi

print_status "mkcert found"

# Install local CA
print_status "Installing local Certificate Authority..."
mkcert -install

# Create ssl directory
mkdir -p ssl

# Generate certificates
print_status "Generating SSL certificates..."
cd ssl

# For localhost and common local domains
mkcert \
    localhost \
    127.0.0.1 \
    ::1 \
    redmine.local \
    redmine.test \
    *.redmine.local

# Rename to standard names
mv localhost+5.pem cert.pem
mv localhost+5-key.pem key.pem

print_status "SSL certificates created in ssl/ directory"

# Update hosts file
print_warning "Optional: Add to /etc/hosts for custom domain:"
echo ""
echo "  127.0.0.1 redmine.local"
echo ""
print_warning "To add it automatically:"
echo ""
echo "  echo '127.0.0.1 redmine.local' | sudo tee -a /etc/hosts"
echo ""

# Create .env if not exists
cd ..
if [ ! -f .env ]; then
    print_status "Creating .env file..."
    cat > .env << EOF
# Database
DB_ROOT_PASSWORD=rootpassword
DB_NAME=redmine_production
DB_USERNAME=redmine
DB_PASSWORD=redminepassword

# Application - Generate proper secret in production!
SECRET_KEY_BASE=development_secret_key_change_in_production
EOF
    print_status ".env file created"
fi

echo ""
echo "================================================"
echo "Setup Complete!"
echo "================================================"
echo ""
print_status "SSL certificates are ready in ssl/ directory"
print_warning "To start with HTTPS:"
echo ""
echo "  docker-compose -f docker-compose.ssl.yml up -d"
echo ""
print_warning "Access your application:"
echo "  - https://localhost"
echo "  - https://redmine.local (if added to /etc/hosts)"
echo ""
print_warning "Default login: admin/admin (change immediately!)"

