-- Initialize Redmine database
-- This script runs automatically when MySQL container starts for the first time

-- Ensure proper character set
ALTER DATABASE redmine_production CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant permissions
GRANT ALL PRIVILEGES ON redmine_production.* TO 'redmine'@'%';
FLUSH PRIVILEGES;

