# Simple GCS Setup - One Bucket for Dev & Production

Quick guide for using a single Google Cloud Storage bucket across all environments.

---

## ✅ **Your Setup: One Bucket, One Key**

```
Google Cloud Storage
       ↓
   One Project: redmine-workproof
       ↓
   One Bucket: redmine-workproof-images
       ↓
   One Service Account
       ↓
      One Key
       ↓
    ┌────┴────┐
    ↓         ↓
 Dev Mac   Production
           (209.38.123.1)
```

**Benefits:**
- ✅ Simple to setup
- ✅ Easy to manage
- ✅ Free (under 5GB)
- ✅ One key to maintain
- ✅ Same configuration everywhere

---

## 🚀 **Complete Setup Steps**

### **Step 1: Setup GCS (Run Once)**

On your Mac:

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Run automated setup
./setup-gcs.sh
```

**Interactive prompts:**
- Project ID: `redmine-workproof`
- Bucket name: `redmine-workproof-images`
- Region: `6` (Mumbai) or closest to you
- Make public: `y`
- Auto-delete: `n` (or `y` if you want)

**Result:**
- ✅ GCS project created
- ✅ Bucket created
- ✅ Service account created
- ✅ Key saved to: `~/gcp-key-redmine-workproof.json`
- ✅ Key installed to: `config/gcp/gcp-key.json`
- ✅ Works in development immediately!

---

### **Step 2: Copy Key to Production**

```bash
# Copy key to production server
scp ~/gcp-key-redmine-workproof.json root@209.38.123.1:/tmp/gcp-key.json
```

---

### **Step 3: Install Key on Production**

```bash
# SSH to production
ssh root@209.38.123.1

# Create directory
sudo mkdir -p /var/www/redmine/config/gcp

# Move key
sudo mv /tmp/gcp-key.json /var/www/redmine/config/gcp/gcp-key.json

# Set permissions
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json

# Verify
ls -lh /var/www/redmine/config/gcp/gcp-key.json
# Should show: -rw------- 1 www-data www-data 2.3K
```

---

### **Step 4: Restart Redmine**

```bash
# On production server
sudo systemctl restart redmine

# Check status
sudo systemctl status redmine
```

---

### **Step 5: Test**

Upload a work proof from your mobile app. The image should:
- ✅ Upload successfully
- ✅ Return URL like: `https://storage.googleapis.com/redmine-workproof-images/1730211234_15_abc123.jpg`
- ✅ Be visible in web interface
- ✅ Be viewable at the URL

---

## 📁 **How Images Are Organized**

All images go to the same bucket:

```
gs://redmine-workproof-images/
├── 1730211234_15_abc123.jpg    ← From dev
├── 1730211456_20_def456.jpg    ← From production
├── 1730211789_5_ghi789.jpg     ← From dev
└── 1730211890_8_jkl012.jpg     ← From production
```

**Filename format:**
```
{timestamp}_{user_id}_{random_hex}.{extension}

Example:
1730211234_15_a1b2c3d4e5f6g7h8.jpg
└─ timestamp (unique)
    └─ user ID
        └─ random string (prevents collision)
```

**No conflicts because:**
- ✅ Timestamp is unique
- ✅ Random hex adds uniqueness
- ✅ User ID for tracking

---

## 🔐 **Security**

### **Key File Protection**

**✅ Protected:**
- File permissions: `600` (owner read/write only)
- Owner: `www-data` (Redmine user)
- Location: `config/gcp/` (not in public/)
- Git ignored: Already in `.gitignore`

**✅ Never:**
- ❌ Don't commit to git
- ❌ Don't share publicly
- ❌ Don't email
- ❌ Don't paste in chat

### **Bucket Access**

**✅ Public read access:**
- Anyone can view images (needed for URLs)
- Only service account can upload
- Only service account can delete

---

## 💰 **Cost**

**Google Cloud Storage Pricing:**

| Storage | Cost/month |
|---------|------------|
| 0-5 GB  | **FREE**   |
| 5-10 GB | $0.10      |
| 10-20 GB| $0.30      |
| 50 GB   | $1.00      |
| 100 GB  | $2.00      |

**Your expected usage:**
- Average image: 200 KB
- 100 images/day
- 3,000 images/month = 600 MB
- **Cost: $0 (free tier)** ✅

---

## 🔄 **Fallback Behavior**

If GCS fails or is not configured, images automatically save locally:

```
/var/www/redmine/public/uploads/work_proofs/20251030/
```

**URLs become:**
```
/uploads/work_proofs/20251030/1730211234_15_abc123.jpg
```

**This means:**
- ✅ System always works
- ✅ No downtime if GCS issues
- ✅ Easy to migrate to GCS later

---

## 🧪 **Testing**

### **Test from Development**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
bundle exec rails console

# Test GCS connection
require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(
  project_id: 'redmine-workproof',
  credentials: 'config/gcp/gcp-key.json'
)
bucket = storage.bucket('redmine-workproof-images')
puts bucket.name
# Should print: redmine-workproof-images

# Test upload
file = bucket.create_file(
  StringIO.new('test content'),
  'test-dev.txt'
)
puts file.public_url
file.delete
```

### **Test from Production**

```bash
ssh root@209.38.123.1
cd /var/www/redmine
bundle exec rails console

# Same test as above
```

### **Test from Mobile App**

1. Open your mobile app
2. Create a work proof with image
3. Submit
4. Check response - should have `image_url`
5. Copy URL
6. Open in browser - should show image
7. Check Redmine web interface - should display image

---

## 🔍 **Verification**

### **Check Key Exists**

**Development:**
```bash
ls -lh /Users/muhsinzyne/work/redmine-dev/redmine/config/gcp/gcp-key.json
```

**Production:**
```bash
ssh root@209.38.123.1
ls -lh /var/www/redmine/config/gcp/gcp-key.json
```

### **Check Bucket**

```bash
gsutil ls gs://redmine-workproof-images/
```

### **Check Logs**

**If upload fails, check logs:**

```bash
# Development
tail -f log/development.log | grep -i gcs

# Production
ssh root@209.38.123.1
sudo tail -f /var/www/redmine/log/production.log | grep -i gcs
```

---

## 🐛 **Troubleshooting**

### **Images not uploading to GCS**

1. **Check key exists:**
   ```bash
   ls -lh config/gcp/gcp-key.json
   ```

2. **Check permissions:**
   ```bash
   # Should be: -rw------- (600)
   ls -l config/gcp/gcp-key.json
   ```

3. **Check logs:**
   ```bash
   tail -f log/production.log | grep -i gcs
   ```

4. **Test manually:**
   ```bash
   bundle exec rails console
   require 'google/cloud/storage'
   storage = Google::Cloud::Storage.new(
     project_id: 'redmine-workproof',
     credentials: 'config/gcp/gcp-key.json'
   )
   storage.bucket('redmine-workproof-images').name
   ```

### **Images saving locally instead**

This is normal fallback behavior if:
- GCS key not found
- GCS key invalid
- Network issue
- Bucket doesn't exist

**Solution:** Fix GCS setup, restart Redmine

### **Permission denied**

```bash
# Fix permissions
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json
sudo systemctl restart redmine
```

---

## 📋 **Quick Reference**

### **One-Time Setup**

```bash
# 1. Setup GCS
./setup-gcs.sh

# 2. Copy to production
scp ~/gcp-key-redmine-workproof.json root@209.38.123.1:/tmp/

# 3. Install on production
ssh root@209.38.123.1
sudo mkdir -p /var/www/redmine/config/gcp
sudo mv /tmp/gcp-key-redmine-workproof.json /var/www/redmine/config/gcp/gcp-key.json
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
sudo chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json
sudo systemctl restart redmine

# Done! ✅
```

---

## ✅ **Your Configuration**

**Project:** `redmine-workproof`
**Bucket:** `redmine-workproof-images`
**Region:** `asia-south1` (Mumbai) or your choice
**Key location (both environments):** `config/gcp/gcp-key.json`

**URLs:**
- Development: `http://localhost:3000`
- Production: `https://track.gocomart.com`
- Images: `https://storage.googleapis.com/redmine-workproof-images/`

**Same key works on both!** ✅

---

## 🎯 **Summary**

**What you have:**
- ✅ One GCS project
- ✅ One bucket
- ✅ One service account
- ✅ One key (works everywhere)
- ✅ Free storage (under 5GB)
- ✅ Automatic fallback to local

**Next:**
1. Run `./setup-gcs.sh` (5 minutes)
2. Copy key to production (1 minute)
3. Restart Redmine (10 seconds)
4. Test from mobile app
5. Done! 🚀

---

**Related Docs:**
- [GCS_QUICK_SETUP.md](docs/GCS_QUICK_SETUP.md) - Automated setup guide
- [GCS_KEY_MANAGEMENT.md](docs/GCS_KEY_MANAGEMENT.md) - Key management details
- [WORKPROOF_IMAGE_STORAGE.md](docs/WORKPROOF_IMAGE_STORAGE.md) - How storage works

