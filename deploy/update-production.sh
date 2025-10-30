#!/bin/bash
# Update Production Redmine Server
# Use this to deploy new plugins, features, and updates to your live server

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
echo "  Redmine Production Update Script"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

print_warning "This script will:"
echo "  1. Backup current database and files"
echo "  2. Pull latest code from GitHub"
echo "  3. Install new gems/dependencies"
echo "  4. Run database migrations"
echo "  5. Restart services"
echo ""
read -p "Continue? [yes/no]: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Update cancelled."
    exit 0
fi

# Configuration
REDMINE_DIR="/var/www/redmine"
BACKUP_DIR="/root/redmine-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo ""
print_warning "=== Pre-Update Backup ==="
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup database
print_status "Backing up database..."
read -sp "Enter MySQL root password: " MYSQL_PASS
echo ""

mysqldump -u root -p"$MYSQL_PASS" redmine_production > "$BACKUP_DIR/db_backup_$TIMESTAMP.sql"
print_status "Database backed up to: $BACKUP_DIR/db_backup_$TIMESTAMP.sql"

# Backup files directory
print_status "Backing up uploaded files..."
if [ -d "$REDMINE_DIR/files" ]; then
    tar -czf "$BACKUP_DIR/files_backup_$TIMESTAMP.tar.gz" -C "$REDMINE_DIR" files
    print_status "Files backed up to: $BACKUP_DIR/files_backup_$TIMESTAMP.tar.gz"
fi

# Backup plugins
print_status "Backing up plugins..."
if [ -d "$REDMINE_DIR/plugins" ]; then
    tar -czf "$BACKUP_DIR/plugins_backup_$TIMESTAMP.tar.gz" -C "$REDMINE_DIR" plugins
    print_status "Plugins backed up to: $BACKUP_DIR/plugins_backup_$TIMESTAMP.tar.gz"
fi

# Backup configuration
print_status "Backing up configuration files..."
cp "$REDMINE_DIR/config/database.yml" "$BACKUP_DIR/database.yml_$TIMESTAMP"
cp "$REDMINE_DIR/config/configuration.yml" "$BACKUP_DIR/configuration.yml_$TIMESTAMP" 2>/dev/null || true
cp "$REDMINE_DIR/.env.production" "$BACKUP_DIR/env.production_$TIMESTAMP" 2>/dev/null || true

print_status "Backup completed!"

echo ""
print_warning "=== Updating Application ==="
echo ""

# Go to application directory
cd "$REDMINE_DIR"

# Check current git status
print_info "Current version:"
git log -1 --oneline

# Stash any local changes
print_status "Stashing local changes (if any)..."
git stash

# Pull latest code
print_status "Pulling latest code from GitHub..."
git pull origin master

print_info "Updated to:"
git log -1 --oneline

# Check for new dependencies
echo ""
read -p "Install/update Ruby gems? [yes/no] (yes): " UPDATE_GEMS
UPDATE_GEMS=${UPDATE_GEMS:-yes}

if [ "$UPDATE_GEMS" = "yes" ]; then
    print_status "Installing/updating Ruby gems..."
    bundle install --without development test
    print_status "Gems updated"
fi

# Run migrations
echo ""
read -p "Run database migrations? [yes/no] (yes): " RUN_MIGRATIONS
RUN_MIGRATIONS=${RUN_MIGRATIONS:-yes}

if [ "$RUN_MIGRATIONS" = "yes" ]; then
    print_status "Running database migrations..."
    RAILS_ENV=production bundle exec rake db:migrate
    print_status "Migrations completed"
fi

# Update plugins
echo ""
read -p "Update plugins? [yes/no] (yes): " UPDATE_PLUGINS
UPDATE_PLUGINS=${UPDATE_PLUGINS:-yes}

if [ "$UPDATE_PLUGINS" = "yes" ]; then
    print_status "Updating plugins..."
    RAILS_ENV=production bundle exec rake redmine:plugins:migrate
    print_status "Plugins updated"
fi

# Clear cache
print_status "Clearing cache..."
RAILS_ENV=production bundle exec rake tmp:cache:clear
RAILS_ENV=production bundle exec rake tmp:sessions:clear

# Update file permissions
print_status "Updating file permissions..."
chmod -R 755 files log tmp public/plugin_assets
chown -R root:root "$REDMINE_DIR"

echo ""
print_warning "=== Restarting Services ==="
echo ""

# Restart Redmine
print_status "Restarting Redmine..."
systemctl restart redmine

# Wait for service to start
sleep 3

# Check service status
if systemctl is-active --quiet redmine; then
    print_status "Redmine restarted successfully"
else
    print_error "Redmine failed to start!"
    print_info "Check logs: journalctl -u redmine -n 50"
    exit 1
fi

# Optionally restart Nginx
read -p "Restart Nginx? [yes/no] (no): " RESTART_NGINX
RESTART_NGINX=${RESTART_NGINX:-no}

if [ "$RESTART_NGINX" = "yes" ]; then
    print_status "Restarting Nginx..."
    systemctl restart nginx
fi

echo ""
print_warning "=== Health Check ==="
echo ""

# Check application
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    print_status "✅ Application is healthy (HTTP $HTTP_CODE)"
else
    print_warning "⚠️  Application returned HTTP $HTTP_CODE"
    print_info "Check logs for issues"
fi

# Check services
print_info "Service Status:"
echo "  Redmine: $(systemctl is-active redmine)"
echo "  MySQL: $(systemctl is-active mysql)"
echo "  Nginx: $(systemctl is-active nginx)"

# Memory usage
echo ""
print_info "Memory Usage:"
free -h | grep -E "(Mem|Swap)"

echo ""
echo "================================================"
echo "  🎉 Update Complete!"
echo "================================================"
echo ""

PUBLIC_IP=$(curl -s ifconfig.me)
print_status "Your Redmine is updated and running!"
echo ""
print_info "Access: http://$PUBLIC_IP"
echo ""
print_warning "Backups saved in: $BACKUP_DIR"
echo "  Database: db_backup_$TIMESTAMP.sql"
echo "  Files: files_backup_$TIMESTAMP.tar.gz"
echo "  Plugins: plugins_backup_$TIMESTAMP.tar.gz"
echo ""
print_info "To rollback if needed:"
echo "  mysql -u root -p redmine_production < $BACKUP_DIR/db_backup_$TIMESTAMP.sql"
echo ""
print_info "View logs:"
echo "  tail -f /var/www/redmine/log/production.log"
echo "  journalctl -u redmine -f"
echo ""




