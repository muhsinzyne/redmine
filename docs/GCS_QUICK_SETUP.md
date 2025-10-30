# Google Cloud Storage Quick Setup

Automated setup script for Google Cloud Storage with Redmine WorkProof.

---

## 🚀 **One-Command Setup**

```bash
./setup-gcs.sh
```

That's it! The script will guide you through the entire setup process.

---

## 📋 **What the Script Does**

The script automates all the steps from [GCS_SETUP_GUIDE.md](GCS_SETUP_GUIDE.md):

1. ✅ Checks for gcloud CLI
2. ✅ Logs in to Google Cloud
3. ✅ Creates/selects GCP project
4. ✅ Creates storage bucket
5. ✅ Enables Cloud Storage API
6. ✅ Configures bucket permissions
7. ✅ Sets CORS policy
8. ✅ Creates service account
9. ✅ Grants storage permissions
10. ✅ Downloads service account key
11. ✅ Installs key to Redmine
12. ✅ Tests upload
13. ✅ Creates environment config

---

## ⚡ **Quick Start**

### **Prerequisites**

Install gcloud CLI first:

**macOS:**
```bash
brew install --cask google-cloud-sdk
```

**Linux:**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows:**
Download from: https://cloud.google.com/sdk/docs/install

---

### **Run Setup**

```bash
# 1. Make executable (if not already)
chmod +x setup-gcs.sh

# 2. Run script
./setup-gcs.sh
```

---

## 📝 **Interactive Prompts**

The script will ask you for:

### **1. Google Account Login**
```
▸ Logging in to Google Cloud...
```
Opens browser for Google login.

### **2. Project Configuration**
```
Enter project ID (e.g., redmine-workproof): 
```
- Use existing project or create new
- Project ID must be unique globally

### **3. Bucket Name**
```
Enter bucket name (e.g., redmine-workproof-images):
```
- Must be globally unique
- Use lowercase, numbers, hyphens

### **4. Region Selection**
```
Available regions:
  1) us-central1      (Iowa, USA)
  2) us-east1         (South Carolina, USA)
  3) asia-south1      (Mumbai, India)
  ...
Choose region (1-8):
```
Choose region closest to your users.

### **5. Public Access**
```
Make bucket publicly readable? (recommended for image URLs) (y/n):
```
Choose **yes** for public image URLs.

### **6. Auto-delete (Optional)**
```
Auto-delete images older than 1 year? (optional) (y/n):
```
Optional lifecycle policy.

---

## ✅ **Example Session**

```bash
$ ./setup-gcs.sh

========================================
Google Cloud Storage Setup for Redmine WorkProof
========================================

▸ Checking prerequisites...
✓ gcloud CLI is installed
✓ gsutil is installed

▸ Logging in to Google Cloud...
✓ Already logged in as: you@example.com

▸ Project Configuration
Enter project ID (e.g., redmine-workproof): redmine-workproof
✓ Project created
✓ Project set to: redmine-workproof

▸ Bucket Configuration
Enter bucket name (e.g., redmine-workproof-images): redmine-workproof-images

Available regions:
  1) us-central1      (Iowa, USA)
  2) us-east1         (South Carolina, USA)
  3) us-west1         (Oregon, USA)
  4) europe-west1     (Belgium)
  5) europe-west2     (London, UK)
  6) asia-south1      (Mumbai, India)
  7) asia-southeast1  (Singapore)
  8) Custom region

Choose region (1-8): 6

▸ Creating bucket gs://redmine-workproof-images in asia-south1...
✓ Bucket created

▸ Enabling Cloud Storage API...
✓ Cloud Storage API enabled

▸ Configuring bucket permissions...
Make bucket publicly readable? (recommended for image URLs) (y/n): y
✓ Bucket is now publicly readable

▸ Configuring CORS...
✓ CORS configured

Auto-delete images older than 1 year? (optional) (y/n): n

▸ Service Account Setup
▸ Creating service account...
✓ Service account created: redmine-storage@redmine-workproof.iam.gserviceaccount.com

▸ Granting storage permissions...
✓ Permissions granted

▸ Creating service account key...
✓ Key created: /home/user/gcp-key-redmine-workproof.json

▸ Installing key to Redmine...
✓ Key installed to: /var/www/redmine/config/gcp/gcp-key.json

▸ Testing upload...
✓ Test upload successful!
✓ Public URL: https://storage.googleapis.com/redmine-workproof-images/test-1730211234.txt

▸ Creating environment configuration...
✓ Environment config saved to: /var/www/redmine/.env.gcs

========================================
Setup Complete! 🎉
========================================

Configuration Summary:

  Project ID:       redmine-workproof
  Bucket Name:      redmine-workproof-images
  Region:           asia-south1
  Service Account:  redmine-storage@redmine-workproof.iam.gserviceaccount.com
  Key Location:     /var/www/redmine/config/gcp/gcp-key.json
  Public Access:    y

ℹ Next Steps:

1. Verify key exists:
   ls -lh /var/www/redmine/config/gcp/gcp-key.json

2. Test from Redmine console:
   cd /var/www/redmine
   bundle exec rails console
   > require 'google/cloud/storage'
   > storage = Google::Cloud::Storage.new(
       project_id: 'redmine-workproof',
       credentials: '/var/www/redmine/config/gcp/gcp-key.json'
     )
   > bucket = storage.bucket('redmine-workproof-images')
   > puts bucket.name

3. Restart Redmine:
   sudo systemctl restart redmine

4. Test image upload from mobile app

✓ All done! 🚀

View your bucket: https://console.cloud.google.com/storage/browser/redmine-workproof-images
```

---

## 🔧 **What Gets Created**

### **Google Cloud Resources**

1. **GCP Project** (if new)
   - Project ID: `redmine-workproof`
   - Project Name: Your choice

2. **Storage Bucket**
   - Name: `redmine-workproof-images`
   - Region: Your choice
   - Public read access
   - CORS enabled

3. **Service Account**
   - Name: `redmine-storage`
   - Email: `redmine-storage@PROJECT_ID.iam.gserviceaccount.com`
   - Role: `objectAdmin` on bucket

4. **Service Account Key**
   - JSON key file
   - Downloaded and installed

---

### **Local Files Created**

1. **`~/gcp-key-PROJECT_ID.json`**
   - Backup of service account key

2. **`$REDMINE_DIR/config/gcp/gcp-key.json`**
   - Active key used by Redmine
   - Permissions: 600 (read/write for owner only)

3. **`$REDMINE_DIR/.env.gcs`**
   - Environment variables:
     ```bash
     GCP_PROJECT_ID=redmine-workproof
     GCS_BUCKET=redmine-workproof-images
     GCS_KEY_PATH=config/gcp/gcp-key.json
     ```

---

## 🧪 **Testing**

### **Test from Command Line**

```bash
# Upload test file
echo "test" > test.txt
gsutil cp test.txt gs://YOUR_BUCKET_NAME/
gsutil rm gs://YOUR_BUCKET_NAME/test.txt
rm test.txt
```

### **Test from Redmine Console**

```bash
cd /var/www/redmine
bundle exec rails console

# In Rails console:
require 'google/cloud/storage'

storage = Google::Cloud::Storage.new(
  project_id: 'redmine-workproof',
  credentials: 'config/gcp/gcp-key.json'
)

bucket = storage.bucket('redmine-workproof-images')
puts bucket.name  # Should print your bucket name

# Test upload
file = bucket.create_file(
  StringIO.new('test content'),
  'test.txt'
)
puts file.public_url

# Clean up
file.delete
```

### **Test from Mobile App**

Upload a work proof with image from your mobile app. Check if:
- ✅ Image uploads successfully
- ✅ `image_url` returned in API response
- ✅ URL starts with `https://storage.googleapis.com/`
- ✅ Image visible in web interface

---

## 🔍 **Verification**

### **Check Key File**

```bash
# Verify key exists
ls -lh /var/www/redmine/config/gcp/gcp-key.json

# Should show:
# -rw------- 1 www-data www-data 2.3K Oct 30 12:34 gcp-key.json
```

### **Check Bucket**

```bash
# List buckets
gsutil ls

# Should show:
# gs://redmine-workproof-images/
```

### **Check Service Account**

```bash
# List service accounts
gcloud iam service-accounts list --project=redmine-workproof

# Should show:
# redmine-storage@redmine-workproof.iam.gserviceaccount.com
```

---

## 🐛 **Troubleshooting**

### **Error: gcloud not found**

Install gcloud CLI:
```bash
# macOS
brew install --cask google-cloud-sdk

# Linux
curl https://sdk.cloud.google.com | bash
```

---

### **Error: Project ID already exists**

Choose a different project ID. Must be globally unique.

---

### **Error: Bucket name already taken**

Choose a different bucket name. Must be globally unique.

---

### **Error: Permission denied**

On production server, run with sudo:
```bash
sudo ./setup-gcs.sh
```

Or run as normal user, then fix permissions:
```bash
sudo chown -R www-data:www-data /var/www/redmine/config/gcp/
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
```

---

### **Error: Test upload failed**

Check permissions:
```bash
gcloud iam service-accounts list --project=YOUR_PROJECT_ID
gsutil iam get gs://YOUR_BUCKET_NAME
```

Re-grant permissions:
```bash
gsutil iam ch serviceAccount:SERVICE_ACCOUNT_EMAIL:objectAdmin gs://YOUR_BUCKET_NAME
```

---

## 🔄 **Running Again**

The script is idempotent - you can run it multiple times:

- ✅ Won't create duplicate projects
- ✅ Won't create duplicate buckets
- ✅ Won't create duplicate service accounts
- ✅ Will ask before overwriting keys

---

## 💰 **Costs**

**Free Tier (Always):**
- 5 GB storage
- 1 GB network egress

**After free tier:**
- $0.020/GB/month storage
- $0.12/GB egress

**Most installations stay in free tier!**

---

## 🔐 **Security**

### **Key File Security**

The script automatically:
- ✅ Sets permissions to 600 (owner read/write only)
- ✅ Creates backup in home directory
- ✅ Sets www-data ownership (if run as root)

**Never:**
- ❌ Commit key file to git (already in .gitignore)
- ❌ Share key file publicly
- ❌ Email or post key contents

### **Bucket Security**

The script:
- ✅ Makes bucket public for image URLs (optional)
- ✅ Sets CORS for web access
- ✅ Grants service account admin access

---

## 📚 **Related Documentation**

- [GCS_SETUP_GUIDE.md](GCS_SETUP_GUIDE.md) - Detailed manual setup
- [WORKPROOF_IMAGE_STORAGE.md](WORKPROOF_IMAGE_STORAGE.md) - Storage architecture
- [WORKPROOF_API.md](WORKPROOF_API.md) - API documentation

---

## ✅ **Summary**

**One command to setup everything:**
```bash
./setup-gcs.sh
```

**Takes about 5 minutes** (including prompts)

**Creates:**
- ✅ GCP project (optional)
- ✅ Storage bucket
- ✅ Service account
- ✅ Service account key
- ✅ Installs to Redmine
- ✅ Tests upload

**No manual steps needed!** 🎉

---

**Next:** Test image upload from your mobile app!

