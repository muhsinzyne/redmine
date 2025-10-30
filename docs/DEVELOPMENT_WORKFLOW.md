# Development and Deployment Workflow

Complete guide for developing plugins/features locally and deploying to production.

---

## 🔄 **Development Workflow**

### **Local Development → Production Deployment**

```
1. Develop locally
2. Test locally
3. Commit to git
4. Push to GitHub
5. Deploy to production
6. Test on production
7. Monitor
```

---

## 💻 **Local Development**

### **1. Start Local Development Server**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Start MySQL (if using local MySQL)
# Or use existing database

# Start Rails server
rails server -p 3000

# Access: http://localhost:3000
```

### **2. Develop New Plugin**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Create new plugin
bundle exec rails generate redmine_plugin YourPluginName

# Plugin structure created at:
plugins/your_plugin_name/
├── init.rb
├── app/
│   ├── controllers/
│   ├── models/
│   └── views/
├── config/
│   ├── locales/
│   └── routes.rb
├── db/migrate/
└── assets/
```

### **3. Create Plugin Migration**

```bash
# Generate migration
cd plugins/your_plugin_name
bundle exec rails generate redmine_plugin_migration YourPluginName CreateYourTable

# Edit migration file in db/migrate/
# Then run:
bundle exec rake redmine:plugins:migrate NAME=your_plugin_name
```

### **4. Test Locally**

```bash
# Restart server
# Ctrl+C to stop, then:
rails server -p 3000

# Test your plugin functionality
# Check logs:
tail -f log/development.log
```

---

## 🚀 **Deploy to Production**

### **Method 1: Quick Update (Code Only)**

```bash
# 1. On local machine - commit and push
cd /Users/muhsinzyne/work/redmine-dev/redmine
git add .
git commit -m "Add new feature: YourFeature"
git push origin master

# 2. On production server - update
ssh root@209.38.123.1
cd /var/www/redmine
git pull origin master
bundle install --without development test
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
systemctl restart redmine

# Done!
```

### **Method 2: Full Update with Backup (Recommended)**

```bash
# On production server
ssh root@209.38.123.1

# Download and run update script
wget https://raw.githubusercontent.com/muhsinzyne/redmine/master/deploy/update-production.sh -O update.sh
chmod +x update.sh
./update.sh

# Script will:
# - Backup database
# - Backup files
# - Pull latest code
# - Install gems
# - Run migrations
# - Restart services
# - Verify deployment
```

---

## 📦 **Plugin Development Workflow**

### **Example: Creating a New Plugin**

#### **1. Generate Plugin Locally**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Generate plugin structure
bundle exec rails generate redmine_plugin MyFeature

cd plugins/my_feature

# Edit init.rb
cat > init.rb << 'EOF'
Redmine::Plugin.register :my_feature do
  name 'My Feature Plugin'
  author 'Your Name'
  description 'Description of my plugin'
  version '1.0.0'
  
  # Add menu item
  menu :project_menu, 
       :my_feature, 
       { controller: 'my_features', action: 'index' }, 
       caption: 'My Feature',
       param: :project_id
  
  # Define permissions
  project_module :my_feature do
    permission :view_my_feature, { my_features: [:index] }
  end
end
EOF
```

#### **2. Create Controller**

```bash
mkdir -p app/controllers
cat > app/controllers/my_features_controller.rb << 'EOF'
class MyFeaturesController < ApplicationController
  before_action :find_project
  before_action :authorize
  
  def index
    @items = MyFeature.where(project_id: @project.id)
  end
  
  private
  
  def find_project
    @project = Project.find(params[:project_id])
  end
end
EOF
```

#### **3. Create Model and Migration**

```bash
# Generate migration
bundle exec rails generate redmine_plugin_migration MyFeature CreateMyFeatures

# Edit the migration file
# Then create model
mkdir -p app/models
cat > app/models/my_feature.rb << 'EOF'
class MyFeature < ActiveRecord::Base
  belongs_to :project
  belongs_to :user
  
  validates :name, presence: true
end
EOF
```

#### **4. Test Locally**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Run plugin migrations
bundle exec rake redmine:plugins:migrate NAME=my_feature

# Restart server
rails server -p 3000

# Test your plugin
```

#### **5. Commit and Push**

```bash
git add plugins/my_feature
git commit -m "Add MyFeature plugin"
git push origin master
```

#### **6. Deploy to Production**

```bash
# SSH to production
ssh root@209.38.123.1

# Update
cd /var/www/redmine
git pull origin master
bundle install --without development test
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
systemctl restart redmine

# Verify
curl -I https://track.gocomart.com
```

---

## 🔄 **Quick Deployment Commands**

### **On Your Local Machine (After Development)**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Stage changes
git add .

# Commit
git commit -m "Add: Your feature description"

# Push to GitHub
git push origin master

# Trigger production update
ssh root@209.38.123.1 "cd /var/www/redmine && git pull && bundle install --without development test && RAILS_ENV=production bundle exec rake db:migrate && RAILS_ENV=production bundle exec rake redmine:plugins:migrate && systemctl restart redmine"
```

### **One-Line Deploy**

Save this as an alias in your `~/.bashrc` or `~/.zshrc`:

```bash
alias deploy-redmine='cd /Users/muhsinzyne/work/redmine-dev/redmine && git push origin master && ssh root@209.38.123.1 "cd /var/www/redmine && git pull && bundle install --without development test && RAILS_ENV=production bundle exec rake db:migrate && RAILS_ENV=production bundle exec rake redmine:plugins:migrate && systemctl restart redmine && echo \"✅ Deployed!\"" && echo "✅ Check: https://track.gocomart.com"'
```

Then just run:
```bash
deploy-redmine
```

---

## 🛡️ **Safe Deployment Practices**

### **Pre-Deployment Checklist**

```bash
# 1. Test locally
rails server -p 3000
# Verify everything works

# 2. Run tests (if you have them)
RAILS_ENV=test bundle exec rake test

# 3. Check for syntax errors
ruby -c plugins/my_plugin/init.rb

# 4. Commit with descriptive message
git commit -m "Feature: Clear description of what changed"

# 5. Push to GitHub
git push origin master
```

### **Production Deployment Checklist**

```bash
# 1. Backup first!
ssh root@209.38.123.1 './update.sh'

# 2. Monitor logs during deployment
ssh root@209.38.123.1 'tail -f /var/www/redmine/log/production.log'

# 3. Test after deployment
curl -I https://track.gocomart.com
# Visit site and test features

# 4. Monitor for errors
# Check for 5-10 minutes after deployment
```

---

## 📁 **Plugin Structure Best Practices**

### **Recommended Plugin Layout**

```
plugins/your_plugin/
├── init.rb                      # Plugin registration
├── README.md                    # Documentation
├── app/
│   ├── controllers/
│   │   └── your_controller.rb
│   ├── models/
│   │   └── your_model.rb
│   ├── views/
│   │   └── your_views/
│   │       ├── index.html.erb
│   │       └── show.html.erb
│   └── helpers/
│       └── your_helper.rb
├── config/
│   ├── locales/
│   │   ├── en.yml
│   │   └── [other languages].yml
│   └── routes.rb
├── db/
│   └── migrate/
│       └── 001_create_your_table.rb
├── assets/
│   ├── javascripts/
│   │   └── your_plugin.js
│   └── stylesheets/
│       └── your_plugin.css
├── lib/
│   └── your_plugin/
│       └── hooks.rb
└── test/
    ├── functional/
    ├── unit/
    └── fixtures/
```

---

## 🔧 **Common Update Scenarios**

### **Scenario 1: New Plugin Added**

```bash
# Local
git add plugins/new_plugin
git commit -m "Add new_plugin"
git push

# Production
ssh root@209.38.123.1
cd /var/www/redmine
git pull
bundle install --without development test
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
systemctl restart redmine
```

### **Scenario 2: Plugin Updated**

```bash
# Local
git add plugins/existing_plugin
git commit -m "Update existing_plugin: new features"
git push

# Production
ssh root@209.38.123.1
cd /var/www/redmine
git pull
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
systemctl restart redmine
```

### **Scenario 3: Core Code Changes**

```bash
# Local
git add app/controllers/...
git commit -m "Update controller logic"
git push

# Production
ssh root@209.38.123.1
cd /var/www/redmine
git pull
bundle install --without development test
systemctl restart redmine
```

### **Scenario 4: Database Schema Changes**

```bash
# Local - create migration
bundle exec rails generate migration AddFieldToTable

# Edit migration file
# Test locally
bundle exec rake db:migrate

# Commit and push
git add db/migrate/
git commit -m "Add migration: description"
git push

# Production
ssh root@209.38.123.1
cd /var/www/redmine
git pull
RAILS_ENV=production bundle exec rake db:migrate
systemctl restart redmine
```

### **Scenario 5: Configuration Changes**

```bash
# Local
git add config/
git commit -m "Update configuration"
git push

# Production - DON'T overwrite config files!
ssh root@209.38.123.1
cd /var/www/redmine
git pull
# Manually merge config changes if needed
systemctl restart redmine
```

---

## 🚨 **Rollback Procedure**

### **If Deployment Goes Wrong**

```bash
# SSH to production
ssh root@209.38.123.1

# 1. Rollback code
cd /var/www/redmine
git log --oneline -5  # Find previous commit
git reset --hard PREVIOUS_COMMIT_HASH

# 2. Rollback database (if needed)
BACKUP_FILE="/root/redmine-backups/db_backup_TIMESTAMP.sql"
mysql -u root -p redmine_production < $BACKUP_FILE

# 3. Rollback plugins (if needed)
cd /var/www/redmine
tar -xzf /root/redmine-backups/plugins_backup_TIMESTAMP.tar.gz

# 4. Restart
bundle install --without development test
RAILS_ENV=production bundle exec rake db:migrate
systemctl restart redmine

# 5. Verify
curl -I https://track.gocomart.com
```

---

## 📊 **Monitoring After Deployment**

### **Check Application Health**

```bash
# On production server
# Watch logs in real-time
tail -f /var/www/redmine/log/production.log

# Check for errors
grep -i error /var/www/redmine/log/production.log | tail -20

# Monitor service
watch -n 5 'systemctl status redmine'

# Monitor memory
watch -n 5 'free -h'
```

### **Performance Monitoring**

```bash
# Response time
time curl -s https://track.gocomart.com > /dev/null

# Active connections
netstat -an | grep :80 | wc -l

# Process status
ps aux | grep puma

# Database connections
mysql -u root -p -e "SHOW PROCESSLIST;"
```

---

## 🔧 **Troubleshooting Deployments**

### **Issue: Code updated but changes not visible**

```bash
# Clear cache
RAILS_ENV=production bundle exec rake tmp:cache:clear

# Restart server
systemctl restart redmine

# Hard refresh browser (Ctrl+Shift+R)
```

### **Issue: Migration failed**

```bash
# Check migration status
RAILS_ENV=production bundle exec rake db:migrate:status

# Rollback last migration
RAILS_ENV=production bundle exec rake db:rollback

# Fix and re-run
RAILS_ENV=production bundle exec rake db:migrate
```

### **Issue: Plugin not loading**

```bash
# Check plugin is in plugins/ directory
ls -la /var/www/redmine/plugins/

# Run plugin migrations
RAILS_ENV=production bundle exec rake redmine:plugins:migrate

# Check logs
tail -f /var/www/redmine/log/production.log

# Restart
systemctl restart redmine
```

---

## 📝 **Deployment Scripts Summary**

### **Initial Deployment**

```bash
# Run once to setup production server
./deploy/complete-server-deploy.sh
```

### **Update Deployment**

```bash
# Run when deploying updates
./deploy/update-production.sh
```

### **Quick Update**

```bash
# For small changes
ssh root@209.38.123.1 "cd /var/www/redmine && git pull && systemctl restart redmine"
```

---

## 🎯 **Recommended Workflow**

### **For Small Changes (CSS, views, minor code)**

```bash
# Local
git add .
git commit -m "Update: description"
git push

# Production (quick)
ssh root@209.38.123.1 "cd /var/www/redmine && git pull && systemctl restart redmine"
```

### **For New Features/Plugins**

```bash
# Local
git add .
git commit -m "Feature: description"
git push

# Production (with backup)
ssh root@209.38.123.1
./update.sh  # Use update script for safety
```

### **For Database Changes**

```bash
# Local
git add db/migrate
git commit -m "Migration: description"
git push

# Production (with backup!)
ssh root@209.38.123.1
./update.sh  # Always use update script for migrations
```

---

## 🔐 **Security Best Practices**

### **Sensitive Files**

**Never commit these to git:**
```
config/database.yml         # Has DB password
config/configuration.yml    # Has email password
.env.production            # Has secret keys
files/*                    # User uploads
```

**Your .gitignore already excludes these** ✅

### **Handling Secrets**

```bash
# On production, create config files manually
ssh root@209.38.123.1

# Database config (never in git)
cat > /var/www/redmine/config/database.yml << EOF
production:
  adapter: mysql2
  database: redmine_production
  host: localhost
  username: redmine
  password: "ACTUAL_PASSWORD_HERE"
  encoding: utf8mb4
EOF

# Email config (use template from git)
cp config/configuration.yml.example config/configuration.yml
nano config/configuration.yml  # Edit with real credentials
```

---

## 📊 **Version Control Best Practices**

### **Commit Messages**

```bash
# Good commit messages
git commit -m "Feature: Add work proof export functionality"
git commit -m "Fix: Resolve issue list pagination bug"
git commit -m "Update: Improve WorkProof UI/UX"
git commit -m "Plugin: Add new analytics plugin"

# Bad commit messages
git commit -m "changes"
git commit -m "fix"
git commit -m "update"
```

### **Branching Strategy**

```bash
# Create feature branch
git checkout -b feature/new-analytics

# Develop and test
# ...

# Merge to master
git checkout master
git merge feature/new-analytics

# Push to production
git push origin master

# Deploy
ssh root@209.38.123.1 './update.sh'
```

---

## 🎨 **Plugin Development Tips**

### **WorkProof Plugin Example**

Your existing WorkProof plugin structure:

```
plugins/work_proof/
├── init.rb                    # Plugin registration
├── app/
│   ├── controllers/
│   │   └── work_proofs_controller.rb
│   ├── models/
│   │   └── work_proof.rb
│   └── views/
│       └── work_proofs/
│           └── index.html.erb
├── config/
│   ├── locales/en.yml
│   └── routes.rb
└── db/migrate/
    └── 001_create_work_proofs.rb
```

### **Adding New Features to WorkProof**

```bash
# 1. Add new migration
cd plugins/work_proof
bundle exec rails generate redmine_plugin_migration work_proof AddFieldToWorkProofs

# 2. Edit migration
# db/migrate/002_add_field_to_work_proofs.rb

# 3. Run locally
bundle exec rake redmine:plugins:migrate NAME=work_proof

# 4. Add model methods
# Edit app/models/work_proof.rb

# 5. Update controller
# Edit app/controllers/work_proofs_controller.rb

# 6. Update views
# Edit app/views/work_proofs/*.html.erb

# 7. Test, commit, push, deploy!
```

---

## 📚 **Documentation**

### **Document Your Changes**

Create `CHANGELOG.md` in your project:

```markdown
# Changelog

## [1.1.0] - 2025-10-29
### Added
- New analytics plugin
- Export to CSV functionality
- Email notifications for work proof

### Changed
- Improved WorkProof UI
- Updated email templates

### Fixed
- Pagination bug in issue list
- Date picker timezone issue
```

---

## 🚀 **Quick Reference**

### **Local Development**

```bash
# Start server
rails server -p 3000

# Run console
rails console

# Run migrations
bundle exec rake db:migrate

# Plugin migrations
bundle exec rake redmine:plugins:migrate NAME=plugin_name

# View routes
bundle exec rake routes | grep plugin
```

### **Production Deployment**

```bash
# Quick update
ssh root@209.38.123.1 "cd /var/www/redmine && git pull && systemctl restart redmine"

# Full update with backup
ssh root@209.38.123.1 './update.sh'

# Check logs
ssh root@209.38.123.1 'tail -f /var/www/redmine/log/production.log'

# Check status
ssh root@209.38.123.1 'systemctl status redmine'
```

---

## 🎯 **Complete Workflow Example**

### **Developing a New Feature**

```bash
# Day 1: Local Development
cd /Users/muhsinzyne/work/redmine-dev/redmine
git checkout -b feature/export-reports
# ... develop feature ...
rails server -p 3000  # Test locally

# Day 2: Finalize and Commit
git add .
git commit -m "Feature: Add export reports functionality"
git checkout master
git merge feature/export-reports
git push origin master

# Day 2: Deploy to Production
ssh root@209.38.123.1
cd /var/www/redmine

# Backup first
./update.sh

# Or manual
git pull origin master
bundle install --without development test
RAILS_ENV=production bundle exec rake db:migrate
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
systemctl restart redmine

# Verify
curl -I https://track.gocomart.com
# Test the new feature

# Day 2: Monitor
tail -f /var/www/redmine/log/production.log
# Watch for errors for 10-15 minutes

# Success! ✅
```

---

## 📦 **Update Script Usage**

### **On Production Server**

```bash
# Download update script (first time)
wget https://raw.githubusercontent.com/muhsinzyne/redmine/master/deploy/update-production.sh -O /root/update.sh
chmod +x /root/update.sh

# Run it whenever you need to update
./update.sh

# Or create alias
echo "alias redmine-update='/root/update.sh'" >> /root/.bashrc
source /root/.bashrc

# Then just run
redmine-update
```

---

## 🎉 **Summary**

**You now have:**

✅ **Complete deployment script** - `complete-server-deploy.sh`
✅ **Update script** - `update-production.sh`  
✅ **Clear workflow** - Develop → Test → Deploy
✅ **Backup system** - Auto-backup before updates
✅ **Rollback procedure** - If something goes wrong
✅ **Plugin development guide** - Add new features easily

**Your complete development workflow:**

```
Local (Mac) → GitHub → Production (DigitalOcean)
    ↓            ↓              ↓
  Develop     Version      Deploy & Monitor
              Control
```

**Happy coding!** 🚀




