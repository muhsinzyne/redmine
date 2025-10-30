# Postman Local Testing Guide

Quick guide for testing WorkProof API on your local development environment.

---

## 🚀 **Quick Setup**

### **Step 1: Import Collection**

1. Open Postman
2. Click **Import** (top left)
3. Drag and drop: `docs/WorkProof_API.postman_collection.json`
4. Click **Import**

✅ You should see: **WorkProof API - Redmine** collection

---

### **Step 2: Import Local Environment**

1. Click **Import** again
2. Drag and drop: `docs/WorkProof_API_Local.postman_environment.json`
3. Click **Import**

✅ You should see: **WorkProof Local Development** environment

---

### **Step 3: Select Environment**

1. Top right corner → Select **WorkProof Local Development**
2. Click the eye icon 👁️ to view variables

---

### **Step 4: Get Your API Key**

1. Start your local Redmine:
   ```bash
   cd /Users/muhsinzyne/work/redmine-dev/redmine
   bundle exec rails server
   ```

2. Open browser: http://localhost:3000

3. Login:
   - Username: `admin`
   - Password: `admin` (or your password)

4. Go to: **My account** (top right)

5. Click **Show** next to "API access key"

6. Copy the key (example: `a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6`)

---

### **Step 5: Configure Environment Variables**

In Postman, click the eye icon 👁️ next to **WorkProof Local Development**:

1. **API_KEY** → Paste your copied API key
2. **PROJECT_ID** → `1` (or your test project ID)
3. **ISSUE_ID** → `1` (or your test issue ID)
4. **TODAY** → Update to today's date (YYYY-MM-DD format)

Click **Save** (or it auto-saves)

---

## 🧪 **Testing Requests**

### **Test 1: List All Work Proofs**

1. Expand **WorkProof API - Redmine** → **Work Proofs**
2. Click **List All Work Proofs**
3. Click **Send**

**Expected Response:**
```json
{
  "work_proofs": [],
  "total_count": 0,
  "limit": 25,
  "offset": 0
}
```

✅ **Success!** API is working (empty array is normal if no work proofs yet)

---

### **Test 2: Create Work Proof (JSON)**

1. Click **Create Work Proof**
2. Make sure environment has correct `ISSUE_ID`
3. Click **Send**

**Expected Response:**
```json
{
  "work_proof": {
    "id": 1,
    "project_id": 1,
    "issue_id": 1,
    "user_id": 1,
    "date": "2025-10-30",
    "image_url": "/uploads/work_proofs/20251030/1730211234_1_abc123.jpg",
    "description": "Completed task",
    "work_hours": 2.5,
    "created_at": "2025-10-30T10:30:00Z"
  }
}
```

✅ **Success!** Work proof created with local image storage

---

### **Test 3: Create Work Proof (with Image Upload)**

This tests the actual image upload like your mobile app does.

1. Click **Create Work Proof (with Image Upload)**

2. Go to **Body** tab → **form-data**

3. For the `image` field:
   - Click **Select Files**
   - Choose a test image (JPG, PNG)

4. Update other fields if needed:
   - `project_id`: {{PROJECT_ID}}
   - `issue_id`: {{ISSUE_ID}}
   - `date`: {{TODAY}}
   - `description`: Work completed with image
   - `work_hours`: 3.5

5. Click **Send**

**Expected Response:**
```json
{
  "work_proof": {
    "id": 2,
    "project_id": 1,
    "issue_id": 1,
    "user_id": 1,
    "date": "2025-10-30",
    "image_url": "https://storage.googleapis.com/redmine-workproof-images/1730211234_1_abc123.jpg",
    "description": "Work completed with image",
    "work_hours": 3.5,
    "created_at": "2025-10-30T10:35:00Z"
  }
}
```

**Image URL will be:**
- **GCS configured:** `https://storage.googleapis.com/redmine-workproof-images/...`
- **Local fallback:** `/uploads/work_proofs/20251030/...`

✅ **Success!** Image uploaded!

---

### **Test 4: View Uploaded Image**

Copy the `image_url` from the response:

**If GCS URL:**
```
https://storage.googleapis.com/redmine-workproof-images/1730211234_1_abc123.jpg
```
→ Open directly in browser

**If local URL:**
```
/uploads/work_proofs/20251030/1730211234_1_abc123.jpg
```
→ Open: http://localhost:3000/uploads/work_proofs/20251030/1730211234_1_abc123.jpg

✅ Image should display!

---

## 📋 **Available Requests**

| Request | Method | Description |
|---------|--------|-------------|
| List All Work Proofs | GET | Get all work proofs for project |
| List Work Proofs (Today) | GET | Filter by today's date |
| List Work Proofs (By User) | GET | Filter by specific user |
| List Work Proofs (Date Range) | GET | Filter by date range |
| List Work Proofs (Paginated) | GET | With pagination |
| Get Single Work Proof | GET | Get one work proof by ID |
| **Create Work Proof** | POST | Create with JSON (image_url) |
| **Create Work Proof (with Image Upload)** | POST | Create with file upload |
| Update Work Proof | PUT | Update existing work proof |
| Delete Work Proof | DELETE | Delete work proof |

---

## 🔧 **Environment Variables**

### **Local Development**

| Variable | Value | Description |
|----------|-------|-------------|
| BASE_URL | http://localhost:3000 | Local server |
| API_KEY | (your key) | From My Account |
| PROJECT_ID | 1 | Test project |
| ISSUE_ID | 1 | Test issue |
| USER_ID | 1 | Admin user |
| WORK_PROOF_ID | 1 | For show/update/delete |
| TODAY | 2025-10-30 | Current date |

### **Production**

Switch environment to **WorkProof Production**:
- BASE_URL: https://track.gocomart.com
- Same API_KEY works if user exists on production

---

## 🎯 **Common Use Cases**

### **Create a Test Project & Issue**

If you don't have a project/issue yet:

```bash
# Via Rails console
cd /Users/muhsinzyne/work/redmine-dev/redmine
bundle exec rails console

# Create project
project = Project.create(
  name: "Test Project",
  identifier: "test-project"
)
puts "Project ID: #{project.id}"

# Create issue
issue = Issue.create(
  project_id: project.id,
  subject: "Test Issue",
  tracker_id: 1,
  author_id: 1
)
puts "Issue ID: #{issue.id}"

# Exit
exit
```

Use these IDs in Postman environment variables.

---

### **Get User's API Key Programmatically**

```bash
# Rails console
bundle exec rails console

# Get admin's API key
user = User.find_by(login: 'admin')
puts user.api_key
# Or generate if doesn't exist
user.api_key || user.generate_api_key!
```

---

### **Test Image Upload from Command Line**

```bash
# Using cURL
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -F "image=@/path/to/test-image.jpg" \
  -F "project_id=1" \
  -F "issue_id=1" \
  -F "date=2025-10-30" \
  "http://localhost:3000/projects/1/work_proofs.json"
```

---

## 🐛 **Troubleshooting**

### **401 Unauthorized**

**Problem:** Invalid or missing API key

**Solution:**
1. Check API_KEY in environment (click eye icon 👁️)
2. Get new API key from Redmine
3. Make sure you're logged into Redmine

---

### **403 Forbidden**

**Problem:** User lacks permissions

**Solution:**
1. Login as admin for testing
2. Or grant permissions:
   - Administration → Roles and permissions
   - Select role (Manager/Developer)
   - Check "Manage work proof"

---

### **404 Not Found**

**Problem:** Project or issue doesn't exist

**Solution:**
1. Check PROJECT_ID exists: http://localhost:3000/projects/1
2. Check ISSUE_ID exists: http://localhost:3000/issues/1
3. Create test data (see above)

---

### **422 Unprocessable Entity**

**Problem:** Validation error

**Solution:**
Check response for error details:
```json
{
  "errors": ["Issue can't be blank"]
}
```

Fix the missing/invalid field.

---

### **500 Internal Server Error**

**Problem:** Server error

**Solution:**
1. Check Rails console for errors
2. Check log file:
   ```bash
   tail -f log/development.log
   ```

---

### **Image Upload Fails**

**Problem:** GCS not configured or permission issue

**Solution:**
1. Check if GCS is configured:
   ```bash
   ./check-gcs-status.sh
   ```

2. Test GCS:
   ```bash
   ./test-gcs.sh
   ```

3. **Not a problem!** System falls back to local storage automatically:
   ```
   /uploads/work_proofs/20251030/...
   ```

---

## 📱 **Simulating Mobile App**

The **Create Work Proof (with Image Upload)** request mimics exactly what your mobile app does:

**Mobile App (Flutter/Dart):**
```dart
FormData formData = FormData.fromMap({
  'image': await MultipartFile.fromFile(imagePath, ...),
  'project_id': request.projectId,
  'issue_id': request.issueId,
});
```

**Postman:**
- Body → form-data
- image → File
- project_id → Text
- issue_id → Text

**Same behavior!** ✅

---

## ✅ **Checklist**

Before testing:
- [ ] Redmine server running (http://localhost:3000)
- [ ] Collection imported
- [ ] Environment imported and selected
- [ ] API_KEY configured
- [ ] PROJECT_ID and ISSUE_ID valid
- [ ] GCS configured (optional, has fallback)

Ready to test! 🚀

---

## 📚 **Files**

- `WorkProof_API.postman_collection.json` - API collection (10 requests)
- `WorkProof_API_Local.postman_environment.json` - Local environment
- `WorkProof_API.postman_environment.json` - Production environment

---

## 🎯 **Quick Test Flow**

1. **List work proofs** → Verify API works
2. **Create with JSON** → Test basic creation
3. **Create with image** → Test file upload
4. **Get single** → Verify created work proof
5. **Update** → Test updates
6. **Delete** → Clean up

**Total time: 5 minutes** ✅

---

**Happy Testing!** 🚀

