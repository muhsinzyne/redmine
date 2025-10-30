# Google Cloud Storage Setup Guide

Complete guide for setting up Google Cloud Storage for WorkProof image uploads.

---

## 📋 **Current Implementation**

### ✅ **What Works Now**

Your mobile app sends images via `multipart/form-data`:

```dart
Future<Response> postWorkProof(WorkProofRequest request, imagePath) async {
  FormData formData = FormData.fromMap({
    'image': await MultipartFile.fromFile(
      imagePath,
      filename: imagePath.split('/').last,
    ),
    'project_id': request.projectId,
    'issue_id': request.issueId,
  });

  return network.post(
    '${NetworkURL.workProofSubmit}?key=${request.apiKey}',
    data: formData,
    options: Options(
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    ),
  );
}
```

### ✅ **Redmine API Now Handles**

1. **Receives image file** from mobile app
2. **Uploads to Google Cloud Storage** (if configured)
3. **Falls back to local storage** (if GCS not configured)
4. **Creates WorkProof** with image URL
5. **Returns created WorkProof** with image URL

---

## 🚀 **Quick Start Options**

### **Option 1: Use Local Storage (No Setup Required)**

**Status:** ✅ Already working!

- Images saved to: `public/uploads/work_proofs/YYYYMMDD/`
- Images served by: Nginx
- Good for: Testing, development, small deployments

**No configuration needed!** Just deploy and it works.

---

### **Option 2: Use Google Cloud Storage (Recommended for Production)**

**Benefits:**
- ☁️ Scalable cloud storage
- 🌐 Global CDN delivery
- 💰 Free tier: 5GB storage
- 🔒 Secure and reliable
- 📈 No server disk usage

**Setup time:** ~15 minutes

---

## ☁️ **Google Cloud Storage Setup**

### **Step 1: Create GCP Project**

```bash
# Install gcloud CLI
# Mac:
brew install --cask google-cloud-sdk

# Ubuntu:
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Login to Google Cloud
gcloud auth login

# Create new project
gcloud projects create redmine-workproof --name="Redmine WorkProof"

# Set as active project
gcloud config set project redmine-workproof
```

### **Step 2: Create Storage Bucket**

```bash
# Enable Cloud Storage API
gcloud services enable storage-api.googleapis.com

# Create bucket (choose your region)
# us-central1, europe-west1, asia-south1, etc.
gsutil mb -l us-central1 gs://redmine-workproof-images

# Make bucket public (for image access)
gsutil iam ch allUsers:objectViewer gs://redmine-workproof-images

# Set lifecycle (optional - auto-delete old images)
cat > lifecycle.json << 'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {"age": 365}
      }
    ]
  }
}
EOF
gsutil lifecycle set lifecycle.json gs://redmine-workproof-images

# Set CORS (for web access)
cat > cors.json << 'EOF'
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
EOF
gsutil cors set cors.json gs://redmine-workproof-images
```

### **Step 3: Create Service Account**

```bash
# Create service account
gcloud iam service-accounts create redmine-storage \
    --display-name="Redmine Storage Service Account" \
    --description="Service account for Redmine WorkProof image uploads"

# Get service account email
SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:Redmine Storage" \
    --format="value(email)")

echo "Service Account: $SA_EMAIL"

# Grant storage admin permissions
gsutil iam ch serviceAccount:$SA_EMAIL:objectAdmin gs://redmine-workproof-images

# Create and download key
gcloud iam service-accounts keys create ~/gcp-key.json \
    --iam-account=$SA_EMAIL

echo "✅ Key created at ~/gcp-key.json"
```

### **Step 4: Copy Key to Redmine Server**

```bash
# For local development:
cp ~/gcp-key.json /Users/muhsinzyne/work/redmine-dev/redmine/config/gcp/gcp-key.json

# For production server:
scp ~/gcp-key.json root@YOUR_SERVER_IP:/var/www/redmine/config/gcp/gcp-key.json

# Set permissions
chmod 600 /var/www/redmine/config/gcp/gcp-key.json
chown www-data:www-data /var/www/redmine/config/gcp/gcp-key.json
```

### **Step 5: Configure Environment Variables (Optional)**

```bash
# On production server, edit systemd service
sudo nano /etc/systemd/system/redmine.service

# Add environment variables:
[Service]
Environment="GCP_PROJECT_ID=redmine-workproof"
Environment="GCS_BUCKET=redmine-workproof-images"

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart redmine
```

Or add to `.env`:
```bash
GCP_PROJECT_ID=redmine-workproof
GCS_BUCKET=redmine-workproof-images
```

---

## 🔧 **Configuration**

### **Verify Setup**

```bash
# Check if key file exists
ls -lh /Users/muhsinzyne/work/redmine-dev/redmine/config/gcp/gcp-key.json

# Check if bucket exists
gsutil ls gs://redmine-workproof-images

# Test upload (optional)
echo "test" > test.txt
gsutil cp test.txt gs://redmine-workproof-images/
gsutil rm gs://redmine-workproof-images/test.txt
rm test.txt
```

### **Install Google Cloud Storage Gem**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine

# Already in Gemfile!
bundle install
```

---

## 🧪 **Testing**

### **Test with cURL**

```bash
# Create test image
echo "test image" > test.jpg

# Upload work proof with image
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -F "image=@test.jpg" \
  -F "project_id=1" \
  -F "issue_id=1" \
  "http://localhost:3000/projects/1/work_proofs.json"

# Check response for image_url
```

### **Test from Mobile App**

Your mobile app code should work as-is! Just send the form data.

---

## 📊 **How It Works**

### **Upload Flow**

```
Mobile App
    ↓ multipart/form-data with image file
Redmine API (work_proofs_api_controller.rb)
    ↓ receive file
Check if GCS configured?
    ↓ YES → upload_to_gcs()
Google Cloud Storage
    ↓ returns public URL
    ↓ NO → upload_to_local()
Local Storage (public/uploads/)
    ↓ returns relative URL
Save WorkProof with image_url
    ↓
Return JSON response
    ↓
Mobile App receives work_proof with image_url
```

### **Controller Logic**

```ruby
def create
  # Step 1: Handle image upload
  if params[:image].present?
    image_url = upload_to_gcs(params[:image])
    # Falls back to local if GCS fails
  end
  
  # Step 2: Create WorkProof
  @work_proof = WorkProof.new
  @work_proof.image_url = image_url
  # ... set other fields
  
  # Step 3: Save and return
  if @work_proof.save
    render json: work_proof_to_json(@work_proof)
  end
end
```

---

## 🔐 **Security**

### **Service Account Permissions**

**Minimum required permissions:**
- `storage.objects.create` - Upload files
- `storage.objects.get` - Read files
- `storage.objects.delete` - Delete files (for future cleanup)

**Current setup:** `objectAdmin` role (full control of objects)

### **Key File Security**

```bash
# Always set correct permissions
chmod 600 config/gcp/gcp-key.json

# Never commit to git (already in .gitignore)
# Never share publicly
# Rotate keys periodically

# To rotate:
gcloud iam service-accounts keys create ~/new-gcp-key.json \
    --iam-account=$SA_EMAIL

# Delete old key:
gcloud iam service-accounts keys list \
    --iam-account=$SA_EMAIL

gcloud iam service-accounts keys delete KEY_ID \
    --iam-account=$SA_EMAIL
```

---

## 💰 **Costs**

### **Google Cloud Storage Pricing**

**Free Tier (Always):**
- 5 GB storage
- 1 GB network egress (downloads)

**Paid (after free tier):**
- Storage: $0.020/GB/month (Standard)
- Network egress: $0.12/GB
- Operations: $0.05/10,000 operations

**Example calculations:**

| Users | Images/day | Storage/month | Cost/month |
|-------|-----------|---------------|------------|
| 10    | 100       | ~3 GB         | **FREE**   |
| 50    | 500       | ~15 GB        | **$0.30**  |
| 100   | 1,000     | ~30 GB        | **$0.60**  |
| 500   | 5,000     | ~150 GB       | **$3.00**  |

**Very affordable!** 🎉

---

## 🔄 **Fallback Behavior**

### **When GCS is Not Configured**

The system **automatically falls back** to local storage:

1. No `gcp-key.json` file → local storage
2. Empty `gcp-key.json` → local storage
3. GCS upload fails → local storage
4. Network error → local storage

**Local storage location:**
```
/public/uploads/work_proofs/YYYYMMDD/
```

**URL format:**
```
/uploads/work_proofs/20251029/1730211234_15_a1b2c3d4e5f6g7h8.jpg
```

**Nginx must serve `/public/uploads/`** ✅ (already configured)

---

## 📱 **Mobile App Updates**

### **No Changes Required!**

Your existing mobile app code works perfectly:

```dart
// This still works!
FormData formData = FormData.fromMap({
  'image': await MultipartFile.fromFile(imagePath, filename: imagePath.split('/').last),
  'project_id': request.projectId,
  'issue_id': request.issueId,
});
```

### **Response Format**

```json
{
  "id": 123,
  "project_id": 1,
  "issue_id": 45,
  "user_id": 15,
  "user_name": "John Doe",
  "date": "2025-10-29",
  "image_url": "https://storage.googleapis.com/redmine-workproof-images/1730211234_15_a1b2c3d4.jpg",
  "description": "Work completed",
  "work_hours": 3.5,
  "created_at": "2025-10-29T12:34:56Z",
  "updated_at": "2025-10-29T12:34:56Z"
}
```

---

## 🎯 **Production Deployment**

### **Update Deployment Script**

The scripts already handle this! Just add the GCS key during deployment:

```bash
# On production server
cd /var/www/redmine

# Copy GCS key
sudo cp ~/gcp-key.json config/gcp/gcp-key.json
sudo chmod 600 config/gcp/gcp-key.json
sudo chown www-data:www-data config/gcp/gcp-key.json

# Restart Redmine
sudo systemctl restart redmine
```

### **Environment Variables (Optional)**

```bash
# Add to /etc/systemd/system/redmine.service
Environment="GCP_PROJECT_ID=redmine-workproof"
Environment="GCS_BUCKET=redmine-workproof-images"
```

---

## 🐛 **Troubleshooting**

### **Images not uploading to GCS**

```bash
# Check if key exists
ls -lh config/gcp/gcp-key.json

# Check logs
tail -f log/production.log | grep -i gcs

# Test GCS manually
bundle exec rails console
require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(
  project_id: 'redmine-workproof',
  credentials: 'config/gcp/gcp-key.json'
)
bucket = storage.bucket('redmine-workproof-images')
bucket.create_file(StringIO.new('test'), 'test.txt')
```

### **Permission denied errors**

```bash
# Fix file permissions
sudo chown -R www-data:www-data /var/www/redmine/config/gcp/
sudo chmod 600 /var/www/redmine/config/gcp/gcp-key.json
```

### **Bucket not found**

```bash
# List buckets
gsutil ls

# Create if missing
gsutil mb -l us-central1 gs://redmine-workproof-images
```

---

## ✅ **Summary**

### **What's Implemented**

✅ Image upload via multipart/form-data
✅ Google Cloud Storage integration
✅ Automatic fallback to local storage
✅ Unique filename generation
✅ Public URL generation
✅ Error handling and logging
✅ Works with existing mobile app

### **Current Status**

- 🔧 **Setup required:** Add `gcp-key.json` to use GCS
- ✅ **Fallback:** Local storage works out-of-the-box
- 📱 **Mobile app:** No changes needed
- 🚀 **Production:** Ready to deploy

### **Recommendation**

**For Production:**
- ✅ Use Google Cloud Storage
- ✅ Follow setup steps above
- ✅ Monitor costs (very low)

**For Development/Testing:**
- ✅ Use local storage (no setup)
- ✅ Works immediately

---

## 🔗 **Useful Links**

- [Google Cloud Console](https://console.cloud.google.com/)
- [GCS Pricing](https://cloud.google.com/storage/pricing)
- [Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts)
- [Storage Buckets](https://console.cloud.google.com/storage/browser)

---

**Next Steps:**
1. ✅ Code is ready (already updated)
2. 🔧 Setup GCS following steps above
3. 📱 Test from mobile app
4. 🚀 Deploy to production

**All set!** 🎉

