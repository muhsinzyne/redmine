#!/bin/bash
# Prepare Redmine application for deployment
# Run this script from your LOCAL machine before deploying

set -e

echo "================================================"
echo "Redmine Deployment Package Preparation"
echo "================================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$APP_ROOT"

# Check if we're in the right directory
if [ ! -f "config.ru" ]; then
    echo "Error: This doesn't appear to be a Rails application directory"
    exit 1
fi

print_status "Application root: $APP_ROOT"

# Create deployment directory
DEPLOY_DIR="$APP_ROOT/deploy/package"
mkdir -p "$DEPLOY_DIR"

# Clean up old assets and temporary files
print_status "Cleaning up temporary files..."
rm -rf tmp/cache/* tmp/sessions/* tmp/sockets/* tmp/pids/*
rm -rf log/*.log
rm -rf public/assets/*

# Install production gems
print_status "Installing production gems..."
bundle install --without development test

# Generate a new secret key base
print_status "Generating secret key base..."
SECRET_KEY=$(bundle exec rake secret)
echo "SECRET_KEY_BASE=$SECRET_KEY" > "$DEPLOY_DIR/.env.production.template"

# Create environment template
print_status "Creating environment template..."
cat > "$DEPLOY_DIR/.env.production.template" << EOF
# Production Environment Configuration
# Copy this file to .env.production and update with your values

RAILS_ENV=production

# Database Configuration
DB_HOST=your-database-host
DB_USERNAME=redmine
DB_PASSWORD=your-secure-password
DB_NAME=redmine_production

# Secret Key (IMPORTANT: Keep this secret!)
SECRET_KEY_BASE=$SECRET_KEY

# Application Configuration
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Optional: Email Configuration
# SMTP_ADDRESS=smtp.gmail.com
# SMTP_PORT=587
# SMTP_DOMAIN=your-domain.com
# SMTP_USERNAME=your-email@gmail.com
# SMTP_PASSWORD=your-app-password
EOF

# Precompile assets for production
print_status "Precompiling assets (this may take a few minutes)..."
RAILS_ENV=production bundle exec rake assets:precompile

# Create deployment package
print_status "Creating deployment package..."
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
PACKAGE_NAME="redmine-deployment-$TIMESTAMP.tar.gz"

tar -czf "$DEPLOY_DIR/$PACKAGE_NAME" \
    --exclude='tmp/cache/*' \
    --exclude='log/*' \
    --exclude='node_modules' \
    --exclude='.git' \
    --exclude='deploy/package/*.tar.gz' \
    --exclude='*.log' \
    .

print_status "Deployment package created: deploy/package/$PACKAGE_NAME"
print_status "Package size: $(du -h "$DEPLOY_DIR/$PACKAGE_NAME" | cut -f1)"

# Create deployment instructions
cat > "$DEPLOY_DIR/DEPLOY_INSTRUCTIONS.txt" << EOF
Redmine Deployment Package
===========================

Package: $PACKAGE_NAME
Created: $(date)

Deployment Steps:
-----------------

1. Upload this package to your server:
   scp $PACKAGE_NAME user@your-server:/var/www/redmine/

2. SSH into your server:
   ssh user@your-server

3. Extract the package:
   cd /var/www/redmine
   tar -xzf $PACKAGE_NAME

4. Copy and configure environment file:
   cp .env.production.template .env.production
   nano .env.production  # Update with your actual values

5. Run database migrations:
   RAILS_ENV=production bundle exec rake db:migrate

6. Load default data (first time only):
   RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

7. Set proper permissions:
   mkdir -p tmp tmp/pdf public/plugin_assets files
   sudo chown -R www-data:www-data files log tmp public/plugin_assets
   sudo chmod -R 755 files log tmp public/plugin_assets

8. Restart the application:
   sudo systemctl restart redmine
   sudo systemctl restart nginx

9. Check application status:
   sudo systemctl status redmine
   curl http://localhost

For detailed instructions, see DEPLOYMENT_GUIDE.md

Default Login (CHANGE IMMEDIATELY):
-----------------------------------
Username: admin
Password: admin
EOF

print_status "Deployment instructions created: deploy/package/DEPLOY_INSTRUCTIONS.txt"

# Create quick deploy script for server
cat > "$DEPLOY_DIR/server-deploy.sh" << 'EOF'
#!/bin/bash
# Run this script on the server after uploading the package

set -e

PACKAGE_FILE=$1

if [ -z "$PACKAGE_FILE" ]; then
    echo "Usage: ./server-deploy.sh <package-file.tar.gz>"
    exit 1
fi

echo "Deploying Redmine from $PACKAGE_FILE..."

# Extract
tar -xzf "$PACKAGE_FILE"

# Check for environment file
if [ ! -f ".env.production" ]; then
    echo "Error: .env.production not found!"
    echo "Please copy .env.production.template to .env.production and configure it"
    exit 1
fi

# Load environment
source .env.production

# Run migrations
RAILS_ENV=production bundle exec rake db:migrate

# Create directories
mkdir -p tmp tmp/pdf public/plugin_assets files

# Restart services
if systemctl is-active --quiet redmine; then
    echo "Restarting Redmine..."
    sudo systemctl restart redmine
fi

if systemctl is-active --quiet nginx; then
    echo "Restarting Nginx..."
    sudo systemctl restart nginx
fi

echo "Deployment complete!"
echo "Check status with: sudo systemctl status redmine"
EOF

chmod +x "$DEPLOY_DIR/server-deploy.sh"

print_status "Server deployment script created: deploy/package/server-deploy.sh"

# Summary
echo ""
echo "================================================"
echo "Deployment Package Ready!"
echo "================================================"
print_warning "Files created in deploy/package/:"
echo "  - $PACKAGE_NAME (application package)"
echo "  - .env.production.template (environment template)"
echo "  - DEPLOY_INSTRUCTIONS.txt (deployment guide)"
echo "  - server-deploy.sh (automated deployment script)"
echo ""
print_warning "Next Steps:"
echo "1. Review DEPLOYMENT_GUIDE.md for platform-specific instructions"
echo "2. Upload package to your server (AWS EC2 or GCP Compute Engine)"
echo "3. Follow the instructions in DEPLOY_INSTRUCTIONS.txt"
echo ""
print_warning "Security Reminders:"
echo "  - Keep SECRET_KEY_BASE secret and secure"
echo "  - Change the default admin password immediately after deployment"
echo "  - Use strong database passwords"
echo "  - Enable SSL/HTTPS in production"

