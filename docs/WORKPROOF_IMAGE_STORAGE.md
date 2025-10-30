# WorkProof Image Storage Documentation

Complete guide for handling WorkProof images and screenshots.

---

## 📸 **Current Implementation**

### **How It Works Now**

**WorkProof currently stores:**
- ✅ `image_url` field (STRING) in database
- ❌ NOT storing actual image files in Redmine

**The workflow is:**
1. Mobile app/frontend captures screenshot
2. App uploads image to **external storage** (Google Cloud Storage, AWS S3, Cloudinary, etc.)
3. App gets public URL from storage service
4. App sends URL to Redmine API
5. Redmine stores only the URL in `work_proofs.image_url` field

**Database Schema:**
```sql
work_proofs table:
├── id (integer)
├── project_id (integer)
├── issue_id (integer)
├── user_id (integer)
├── date (date)
├── image_url (string) ← STORES URL, NOT FILE
├── description (text)
├── work_hours (decimal)
├── status (string)
├── created_at (datetime)
└── updated_at (datetime)
```

---

## ☁️ **Recommended: Google Cloud Storage**

### **Why Google Cloud Storage?**

✅ **Benefits:**
- Free tier: 5GB storage
- Fast CDN delivery
- 99.99% uptime SLA
- Scalable
- Signed URLs for security
- Direct upload from mobile apps

### **Setup Google Cloud Storage**

#### **1. Create GCP Project and Bucket**

```bash
# Install gcloud CLI
# Visit: https://cloud.google.com/sdk/docs/install

# Login
gcloud auth login

# Create project
gcloud projects create redmine-workproof --name="Redmine WorkProof"

# Set project
gcloud config set project redmine-workproof

# Enable Cloud Storage API
gcloud services enable storage-api.googleapis.com

# Create bucket
gsutil mb -l us-central1 gs://redmine-workproof-images

# Make bucket public (for image access)
gsutil iam ch allUsers:objectViewer gs://redmine-workproof-images

# Set CORS (for direct upload from web/mobile)
cat > cors.json << 'EOF'
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD", "PUT", "POST", "DELETE"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
EOF

gsutil cors set cors.json gs://redmine-workproof-images
```

#### **2. Create Service Account**

```bash
# Create service account
gcloud iam service-accounts create redmine-storage \
    --display-name="Redmine Storage Service Account"

# Get service account email
SA_EMAIL=$(gcloud iam service-accounts list --filter="displayName:Redmine Storage" --format="value(email)")

# Grant storage permissions
gsutil iam ch serviceAccount:$SA_EMAIL:objectAdmin gs://redmine-workproof-images

# Create and download key
gcloud iam service-accounts keys create ~/gcp-key.json \
    --iam-account=$SA_EMAIL

# Copy to your Redmine config
# cp ~/gcp-key.json /Users/muhsinzyne/work/redmine-dev/redmine/config/gcp/gcp-key.json
```

---

## 📱 **Mobile App Integration**

### **Option 1: Direct Upload to GCS (Recommended)**

Mobile app uploads directly to Google Cloud Storage, then sends URL to Redmine.

#### **Flutter Example:**

```dart
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/storage/v1.dart' as storage;
import 'package:http/http.dart' as http;

class ImageUploader {
  Future<String> uploadToGCS(File imageFile) async {
    // 1. Get service account credentials
    final credentials = ServiceAccountCredentials.fromJson(
      await rootBundle.loadString('assets/gcp-key.json')
    );
    
    // 2. Get authenticated client
    final client = await clientViaServiceAccount(
      credentials,
      [storage.StorageApi.devstorageReadWriteScope]
    );
    
    // 3. Upload to GCS
    final api = storage.StorageApi(client);
    final bucket = 'redmine-workproof-images';
    final filename = '${DateTime.now().millisecondsSinceEpoch}_${user.id}.jpg';
    
    final media = storage.Media(
      imageFile.openRead(),
      imageFile.lengthSync(),
    );
    
    final object = storage.Object()..name = filename;
    
    await api.objects.insert(
      object,
      bucket,
      uploadMedia: media,
    );
    
    // 4. Return public URL
    return 'https://storage.googleapis.com/$bucket/$filename';
  }
  
  Future<void> submitWorkProof(int issueId, File image) async {
    // Upload image
    final imageUrl = await uploadToGCS(image);
    
    // Create work proof via Redmine API
    final workProof = await workProofAPI.create({
      'issue_id': issueId,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'image_url': imageUrl,
      'description': 'Work completed',
    });
  }
}
```

#### **React Native Example:**

```javascript
import { GoogleCloudStorage } from '@google-cloud/storage';
import RNFS from 'react-native-fs';

const uploadImageToGCS = async (imageUri) => {
  const bucket = 'redmine-workproof-images';
  const filename = `${Date.now()}_${userId}.jpg`;
  
  // Read image as base64
  const base64 = await RNFS.readFile(imageUri, 'base64');
  
  // Upload to GCS using signed URL (get from your backend)
  const signedUrl = await getSignedUploadUrl(filename);
  
  await fetch(signedUrl, {
    method: 'PUT',
    headers: {
      'Content-Type': 'image/jpeg',
    },
    body: base64,
  });
  
  return `https://storage.googleapis.com/${bucket}/${filename}`;
};

const submitWorkProof = async (issueId, imageUri) => {
  // Upload image
  const imageUrl = await uploadImageToGCS(imageUri);
  
  // Create work proof
  await workProofAPI.create({
    issue_id: issueId,
    date: new Date().toISOString().split('T')[0],
    image_url: imageUrl,
  });
};
```

---

### **Option 2: Upload Through Redmine**

Add file upload endpoint to Redmine, which then uploads to GCS.

#### **Add Upload Endpoint:**

Create `plugins/work_proof/app/controllers/work_proof_images_controller.rb`:

```ruby
class WorkProofImagesController < ApplicationController
  accept_api_auth :create
  
  require 'google/cloud/storage'
  
  def create
    unless params[:image].present?
      render json: { error: 'No image provided' }, status: :bad_request
      return
    end
    
    begin
      # Initialize GCS client
      storage = Google::Cloud::Storage.new(
        project_id: 'redmine-workproof',
        credentials: Rails.root.join('config/gcp/gcp-key.json')
      )
      
      bucket = storage.bucket('redmine-workproof-images')
      
      # Generate unique filename
      filename = "#{Time.now.to_i}_#{User.current.id}_#{SecureRandom.hex(4)}.jpg"
      
      # Upload file
      file = bucket.create_file(
        params[:image].tempfile,
        filename,
        content_type: params[:image].content_type
      )
      
      # Make file public
      file.acl.public!
      
      # Return public URL
      image_url = file.public_url
      
      render json: {
        success: true,
        image_url: image_url,
        filename: filename
      }, status: :created
      
    rescue => e
      render json: { 
        error: 'Upload failed', 
        message: e.message 
      }, status: :internal_server_error
    end
  end
end
```

Add route:
```ruby
# In plugins/work_proof/config/routes.rb
post 'projects/:project_id/work_proof_images', to: 'work_proof_images#create'
```

Add gem to Gemfile:
```ruby
gem 'google-cloud-storage', '~> 1.44'
```

---

## 🔐 **Secure Image URLs (Signed URLs)**

For private/secure images:

### **Generate Signed URLs (Backend)**

```ruby
# In WorkProof model
def signed_image_url(expires_in: 1.hour)
  storage = Google::Cloud::Storage.new(
    project_id: 'redmine-workproof',
    credentials: Rails.root.join('config/gcp/gcp-key.json')
  )
  
  bucket = storage.bucket('redmine-workproof-images')
  filename = image_url.split('/').last  # Extract filename from URL
  file = bucket.file(filename)
  
  file.signed_url(expires: expires_in) if file
end
```

### **API Response with Signed URL:**

```ruby
def work_proof_hash(work_proof)
  {
    id: work_proof.id,
    # ... other fields ...
    image_url: work_proof.signed_image_url || work_proof.image_url,
    # ... other fields ...
  }
end
```

---

## 🎯 **Current Recommendation**

### **For Your Mobile App:**

**Approach: Direct Upload from Mobile App**

**Why:**
- ✅ Faster (no middle server)
- ✅ Reduces Redmine server load
- ✅ Better for mobile bandwidth
- ✅ Scalable

**Workflow:**

```
Mobile App Captures Screenshot
         ↓
Upload to Google Cloud Storage
         ↓
Get Public URL
         ↓
Send to Redmine API with URL
         ↓
Redmine saves URL in database
         ↓
Display images using stored URLs
```

---

## 🔧 **Setup Instructions**

### **Current Status:**

```
✅ WorkProof stores image_url
✅ API accepts image_url
✅ Views display images from URL
❌ No upload endpoint in Redmine (by design)
❌ GCP key file is empty
```

### **What You Need:**

**Option A: Mobile App Handles Upload (Recommended)**
- Configure GCP in mobile app
- Upload images from app
- Send URLs to Redmine

**Option B: Redmine Handles Upload**
- Add GCP service account key
- Create upload endpoint
- Mobile app sends image to Redmine
- Redmine uploads to GCS

---

## 📝 **Current API Behavior**

### **Creating Work Proof:**

```bash
# Mobile app must provide image_url
curl -X POST \
  -H "X-Redmine-API-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "work_proof": {
      "issue_id": 123,
      "date": "2025-10-29",
      "image_url": "https://storage.googleapis.com/bucket/image.jpg",
      "description": "Work completed"
    }
  }' \
  "https://track.gocomart.com/projects/1/work_proofs.json"
```

**Expected image_url format:**
- Full URL: `https://storage.googleapis.com/bucket-name/filename.jpg`
- Or any accessible image URL
- Will be displayed in web interface and returned in API

---

## 🎨 **Alternative Storage Options**

### **1. AWS S3**
```
Bucket: redmine-workproof
Region: us-east-1
Cost: $0.023/GB/month
```

### **2. Cloudinary**
```
Free tier: 25GB storage, 25GB bandwidth
Easy image transformations
Good for mobile apps
```

### **3. Firebase Storage**
```
Free tier: 5GB storage
Good for mobile apps
Easy authentication
```

### **4. DigitalOcean Spaces**
```
Cost: $5/month (250GB)
S3-compatible API
Easy to setup
```

---

## ✅ **Confirmed: Current WorkProof Setup**

**Image Storage:**
- 📦 **Storage Method**: External (Google Cloud Storage, S3, Cloudinary, etc.)
- 💾 **Redmine Stores**: Only the image URL (string field)
- 🔗 **Image URL Format**: Full public URL to image
- 📱 **Upload Responsibility**: Mobile app or frontend
- 🖼️ **Display**: Images loaded from stored URLs

**This is actually a GOOD design because:**
- ✅ Redmine server doesn't handle large files
- ✅ Better performance
- ✅ Scalable (use CDN)
- ✅ Flexible (use any storage service)
- ✅ Mobile apps can upload directly

---

## 🚀 **To Configure GCP Storage**

If you want to use Google Cloud Storage:

1. **Create GCP project and bucket** (see instructions above)
2. **Get service account key**
3. **Save to**: `config/gcp/gcp-key.json`
4. **Configure in mobile app** OR **add upload endpoint to Redmine**

---

## 📋 **Summary**

**Current Status:**
- ✅ WorkProof API ready
- ✅ Accepts `image_url` parameter
- ✅ Stores URLs in database
- ✅ Displays images from URLs
- ⚠️ Image upload NOT handled by Redmine (by design)
- ⚠️ Mobile app must upload images separately

**You need to:**
1. Choose cloud storage (GCS, S3, Cloudinary, etc.)
2. Configure storage in your mobile app
3. Mobile app uploads image → gets URL → sends to Redmine API

**This is the standard approach for modern mobile apps!** ✅

---

**Would you like me to:**
1. Add image upload endpoint to Redmine? (upload through Redmine to GCS)
2. Document mobile app direct upload to GCS? (recommended)
3. Both options?

Let me know and I'll create the implementation! 🚀

