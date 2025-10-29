#!/bin/bash
# Reset MySQL root password on Ubuntu 22.04
# Run this ON your server if you don't know the MySQL root password

set -e

echo "================================================"
echo "MySQL Root Password Reset"
echo "================================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

echo "This will reset your MySQL root password."
read -p "Continue? [yes/no]: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Stop MySQL
echo "Stopping MySQL..."
systemctl stop mysql

# Create temporary config file
echo "Creating temporary MySQL config..."
cat > /tmp/mysql-init.sql << 'EOF'
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'TEMP_PASSWORD_123';
FLUSH PRIVILEGES;
EOF

# Start MySQL with init file
echo "Starting MySQL in recovery mode..."
mysqld --init-file=/tmp/mysql-init.sql --daemonize

# Wait for MySQL to start
sleep 5

# Now we can login with the temp password
echo ""
read -sp "Enter your NEW MySQL root password: " NEW_PASSWORD
echo ""

# Set the new password
mysql -u root -p'TEMP_PASSWORD_123' << EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$NEW_PASSWORD';
FLUSH PRIVILEGES;
EOF

# Cleanup
rm /tmp/mysql-init.sql

# Restart MySQL normally
echo "Restarting MySQL..."
killall mysqld 2>/dev/null || true
sleep 2
systemctl start mysql

# Test connection
echo ""
echo "Testing connection..."
if mysql -u root -p"$NEW_PASSWORD" -e "SELECT 1;" &>/dev/null; then
    echo "✅ Success! MySQL root password has been reset."
    echo ""
    echo "New root password: $NEW_PASSWORD"
    echo "Save this password!"
else
    echo "❌ Something went wrong. MySQL may need manual intervention."
fi

