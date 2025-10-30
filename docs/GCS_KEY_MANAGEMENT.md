# GCS Key Management Guide

How to manage Google Cloud Storage service account keys across development and production.

---

## ✅ **Yes - You Can Use the Same Key!**

**The same service account key can be used in:**
- ✅ Development environment
- ✅ Production server
- ✅ Multiple servers
- ✅ Staging environment

---

## 🔑 **Key Management Strategies**

### **Option 1: Single Key for All Environments (Simple)**

**Setup:**
```
Google Cloud Storage
       ↓
  Service Account: redmine-storage
       ↓
     One Key
       ↓
    ┌──────┼──────┐
    ↓      ↓      ↓
  Dev   Staging  Prod
```

**Pros:**
- ✅ Simple to manage
- ✅ One key to rotate
- ✅ Same configuration everywhere
- ✅ Works for most use cases

**Cons:**
- ⚠️ If key compromised, affects all environments
- ⚠️ Can't revoke access to just one environment

**Best for:** Small teams, single bucket, simple setup

---

### **Option 2: Separate Keys per Environment (Recommended)**

**Setup:**
```
Google Cloud Storage
       ↓
┌──────┴──────┐
↓             ↓
Dev Service   Prod Service
Account       Account
↓             ↓
Dev Key       Prod Key
↓             ↓
Dev Server    Prod Server
```

**Pros:**
- ✅ Better security isolation
- ✅ Revoke one environment without affecting others
- ✅ Track which environment accessed what
- ✅ Different permissions per environment

**Cons:**
- ⚠️ More keys to manage
- ⚠️ More setup required

**Best for:** Production deployments, teams, compliance requirements

---

### **Option 3: Separate Buckets per Environment (Most Secure)**

**Setup:**
```
┌─────────────────┬─────────────────┐
↓                 ↓                 ↓
Dev Bucket        Staging Bucket    Prod Bucket
↓                 ↓                 ↓
Dev Service       Staging Service   Prod Service
Account           Account           Account
↓                 ↓                 ↓
Dev Key          Staging Key        Prod Key
↓                 ↓                 ↓
Dev Server       Staging Server     Prod Server
```

**Pros:**
- ✅ Complete isolation
- ✅ Dev can't accidentally affect prod
- ✅ Different bucket settings per environment
- ✅ Audit trail per environment

**Cons:**
- ⚠️ More resources to manage
- ⚠️ More cost (still minimal)

**Best for:** Large teams, strict compliance, multiple environments

---

## 🚀 **Quick Setup: Use Same Key Everywhere**

### **Step 1: Run Setup Script Once**

```bash
./setup-gcs.sh
```

This creates:
- Project: `redmine-workproof`
- Bucket: `redmine-workproof-images`
- Service Account: `redmine-storage@redmine-workproof.iam.gserviceaccount.com`
- Key: `~/gcp-key-redmine-workproof.json`

---

### **Step 2: Copy Key to Development**

```bash
# If running script on development machine, it's already installed
ls -lh config/gcp/gcp-key.json
```

---

### **Step 3: Copy Key to Production**

```bash
# From your local machine, copy to production server
scp ~/gcp-key-redmine-workproof.json root@209.38.123.1:/tmp/

# On production server
ssh root@209.38.123.1
sudo mkdir -p /var/www/redmine/config/gcp
sudo mv /tmp/gcp-key-redmine-workproof.json /var/www/redmine/config/gcp/gcp-key.json
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json

# Restart Redmine
sudo systemctl restart redmine
```

---

### **Step 4: Verify on Both**

**Development:**
```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
bundle exec rails console

# Test
require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(
  project_id: 'redmine-workproof',
  credentials: 'config/gcp/gcp-key.json'
)
bucket = storage.bucket('redmine-workproof-images')
puts bucket.name  # Should print: redmine-workproof-images
```

**Production:**
```bash
cd /var/www/redmine
bundle exec rails console

# Same test as above
```

---

## 🔐 **Security Best Practices**

### **1. File Permissions**

Always set correct permissions on key file:

```bash
# Development
chmod 600 config/gcp/gcp-key.json

# Production
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json
```

**Verify:**
```bash
ls -lh config/gcp/gcp-key.json
# Should show: -rw------- (600)
```

---

### **2. Never Commit to Git**

The key file is already in `.gitignore`:

```bash
# .gitignore already has:
config/gcp/*config/gcp/gcp-key.json
```

**Verify:**
```bash
git status
# Should NOT show gcp-key.json
```

---

### **3. Secure Transfer**

When copying key to production:

**✅ DO:**
```bash
# Use SCP with SSH key
scp -i ~/.ssh/id_rsa key.json user@server:/tmp/

# Or use rsync with SSH
rsync -avz -e ssh key.json user@server:/tmp/
```

**❌ DON'T:**
```bash
# Don't email key file
# Don't paste key contents in chat/slack
# Don't upload to public storage
# Don't commit to git
```

---

### **4. Key Rotation**

Rotate keys periodically:

```bash
# List existing keys
gcloud iam service-accounts keys list \
  --iam-account=redmine-storage@redmine-workproof.iam.gserviceaccount.com

# Create new key
gcloud iam service-accounts keys create ~/new-gcp-key.json \
  --iam-account=redmine-storage@redmine-workproof.iam.gserviceaccount.com

# Deploy new key to all environments
# (Copy to dev, staging, prod)

# Delete old key
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=redmine-storage@redmine-workproof.iam.gserviceaccount.com
```

**Recommended rotation schedule:**
- Every 90 days (normal)
- Immediately if compromised
- When employee leaves

---

## 🎯 **Recommended Setup for Your Case**

### **For Small to Medium Projects:**

**Use Option 1: Single Key, Single Bucket**

**Why:**
- ✅ Simple
- ✅ Easy to manage
- ✅ Lower cost
- ✅ Works perfectly for most cases

**Setup:**
1. Run `./setup-gcs.sh` once
2. Copy key to all environments
3. Use same bucket name everywhere
4. Done!

---

### **Configuration:**

**`.env` (same on all environments):**
```bash
GCP_PROJECT_ID=redmine-workproof
GCS_BUCKET=redmine-workproof-images
GCS_KEY_PATH=config/gcp/gcp-key.json
```

**Key location (same path on all):**
```
config/gcp/gcp-key.json
```

---

## 📁 **Organizing Images by Environment**

Even with one bucket, you can organize by environment using prefixes:

### **Option A: Folder Structure in Bucket**

```
redmine-workproof-images/
├── dev/
│   ├── 1730211234_15_abc123.jpg
│   └── 1730211456_20_def456.jpg
├── staging/
│   └── ...
└── prod/
    ├── 1730211789_5_ghi789.jpg
    └── 1730211890_8_jkl012.jpg
```

**Update controller:**
```ruby
def upload_to_gcs(image_file)
  # Add environment prefix
  env_prefix = Rails.env.production? ? 'prod' : Rails.env
  filename = "#{env_prefix}/#{Time.now.to_i}_#{User.current.id}_#{SecureRandom.hex(8)}#{extension}"
  
  file = bucket.create_file(
    image_file.tempfile,
    filename,
    content_type: image_file.content_type
  )
  
  file.public_url
end
```

---

### **Option B: Separate Buckets (Advanced)**

**Development:**
```bash
GCS_BUCKET=redmine-workproof-images-dev
```

**Production:**
```bash
GCS_BUCKET=redmine-workproof-images-prod
```

**Same key, different buckets!**

---

## 🔧 **Deployment Script Integration**

### **Add to Deployment Script**

Update your `deploy/complete-server-deploy.sh`:

```bash
# GCS Key Setup
print_step "Setting up Google Cloud Storage..."

if [ -f "$HOME/gcp-key.json" ]; then
    print_info "GCS key found in home directory"
    sudo mkdir -p /var/www/redmine/config/gcp
    sudo cp "$HOME/gcp-key.json" /var/www/redmine/config/gcp/gcp-key.json
    sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
    sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json
    print_success "GCS key installed"
else
    print_info "GCS key not found - images will be stored locally"
    print_info "To enable GCS:"
    print_info "  1. Run ./setup-gcs.sh on your local machine"
    print_info "  2. Copy key to server: scp ~/gcp-key-*.json root@SERVER:/root/"
    print_info "  3. Re-run this deployment script"
fi
```

---

## 📝 **Quick Reference**

### **One Key for Everything**

```bash
# 1. Setup GCS (run once, anywhere)
./setup-gcs.sh

# 2. Copy key to production
scp ~/gcp-key-redmine-workproof.json root@YOUR_SERVER:/tmp/
ssh root@YOUR_SERVER
sudo mv /tmp/gcp-key-*.json /var/www/redmine/config/gcp/gcp-key.json
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json

# 3. Restart
sudo systemctl restart redmine

# Done! ✅
```

---

### **Environment Variables**

**Development (local):**
```bash
# .env.development
GCP_PROJECT_ID=redmine-workproof
GCS_BUCKET=redmine-workproof-images
```

**Production:**
```bash
# /etc/systemd/system/redmine.service
[Service]
Environment="GCP_PROJECT_ID=redmine-workproof"
Environment="GCS_BUCKET=redmine-workproof-images"
```

Or hardcoded in controller (simpler):
```ruby
storage = Google::Cloud::Storage.new(
  project_id: ENV['GCP_PROJECT_ID'] || 'redmine-workproof',
  credentials: Rails.root.join('config/gcp/gcp-key.json')
)
bucket_name = ENV['GCS_BUCKET'] || 'redmine-workproof-images'
```

---

## ✅ **Summary**

### **Can I use the same key in dev and prod?**
**YES!** ✅

### **Is it secure?**
**YES!** ✅ As long as:
- ✅ Key file has 600 permissions
- ✅ Key not committed to git
- ✅ Key transferred securely
- ✅ Rotated periodically

### **What's the simplest setup?**
1. Run `./setup-gcs.sh` once
2. Copy `gcp-key.json` to all environments
3. Use same bucket everywhere
4. Done!

### **Do I need separate buckets?**
**NO** - One bucket works fine for:
- ✅ Development
- ✅ Staging  
- ✅ Production

Optionally organize with folder prefixes (`dev/`, `prod/`).

### **When should I use separate keys?**
Only if:
- Large team with multiple developers
- Strict compliance requirements
- Need to revoke access per environment
- Otherwise, one key is fine!

---

## 🚀 **Your Next Steps**

**For your DigitalOcean production server:**

```bash
# 1. On your Mac (if not done already)
./setup-gcs.sh

# 2. Copy key to production
scp ~/gcp-key-redmine-workproof.json root@209.38.123.1:/tmp/

# 3. On production server
ssh root@209.38.123.1
sudo mkdir -p /var/www/redmine/config/gcp
sudo mv /tmp/gcp-key-*.json /var/www/redmine/config/gcp/gcp-key.json
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json

# 4. Verify
ls -lh /var/www/redmine/config/gcp/gcp-key.json
# Should show: -rw------- 1 www-data www-data 2.3K

# 5. Restart Redmine
sudo systemctl restart redmine

# 6. Test from mobile app
# Upload a work proof - image should go to GCS!
```

**That's it!** Same key, works everywhere. 🎉

---

**Related Docs:**
- [GCS_QUICK_SETUP.md](GCS_QUICK_SETUP.md) - Automated setup
- [GCS_SETUP_GUIDE.md](GCS_SETUP_GUIDE.md) - Manual setup
- [WORKPROOF_IMAGE_STORAGE.md](WORKPROOF_IMAGE_STORAGE.md) - Storage architecture

