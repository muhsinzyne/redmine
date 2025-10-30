# Postman Setup Guide for WorkProof API

Quick guide to import and use the WorkProof API in Postman.

---

## 📦 **Files Included**

- **WorkProof_API.postman_collection.json** - Complete API collection
- **WorkProof_API.postman_environment.json** - Environment variables

---

## 🚀 **Quick Setup (5 minutes)**

### **Step 1: Import Collection**

1. Open **Postman**
2. Click **Import** (top left)
3. Drag and drop `WorkProof_API.postman_collection.json`
4. Or click **Upload Files** → Select the file
5. Click **Import**

✅ You'll see "WorkProof API - Redmine" collection in the sidebar

### **Step 2: Import Environment**

1. Click **Environments** (left sidebar)
2. Click **Import**
3. Select `WorkProof_API.postman_environment.json`
4. Click **Import**

✅ You'll see "WorkProof Production" environment

### **Step 3: Configure Environment**

1. Select **WorkProof Production** environment (top right dropdown)
2. Click the **eye icon** → **Edit**
3. Update variables:

| Variable | Current Value | Description |
|----------|---------------|-------------|
| `BASE_URL` | `https://track.gocomart.com` | ✅ Already set |
| `API_KEY` | **(empty)** | **ADD YOUR API KEY HERE** ⚠️ |
| `PROJECT_ID` | `1` | Update with your project ID |
| `USER_ID` | `1` | Update as needed |
| `WORK_PROOF_ID` | `1` | Update for testing |
| `TODAY` | `2025-10-29` | Update to current date |

4. Click **Save**

### **Step 4: Get Your API Key**

1. Login to Redmine: https://track.gocomart.com
2. Click **My account** (top right)
3. Find **API access key** section
4. Click **Show** or **Reset**
5. Copy the API key
6. Paste it in Postman environment (`API_KEY` variable)

### **Step 5: Test the API**

1. Expand **WorkProof API** collection
2. Click **List All Work Proofs**
3. Click **Send**
4. You should see work proofs data! ✅

---

## 📋 **Available Requests**

### **Work Proofs Folder**

1. **List All Work Proofs** - Get all work proofs
2. **List Work Proofs (Today)** - Filter by today's date
3. **List Work Proofs (By User)** - Filter by specific user
4. **List Work Proofs (Date Range)** - Filter by date range
5. **List Work Proofs (Paginated)** - With pagination
6. **Get Single Work Proof** - Get specific work proof
7. **Create Work Proof** - Create new work proof
8. **Update Work Proof** - Update existing work proof
9. **Delete Work Proof** - Delete work proof

### **Redmine Standard APIs Folder**

Bonus endpoints you might need:
1. **Get Projects** - List all projects
2. **Get Project Details** - Get project info
3. **Get Issues** - List project issues
4. **Get Current User** - Get authenticated user info
5. **Get Users** - List all users

---

## 🔧 **Customizing Requests**

### **Change Project ID**

Edit environment variable `PROJECT_ID` or directly in request URL:
```
/projects/2/work_proofs.json  (change 1 to 2)
```

### **Change Date Filter**

In request URL, modify query parameter:
```
?date=2025-10-30
```

### **Add Multiple Filters**

```
?date=2025-10-29&user_id=5&limit=10
```

---

## 🧪 **Testing Workflow**

### **1. List Work Proofs**

Request: **List All Work Proofs**
- Click **Send**
- Should return 200 OK with work proofs array

### **2. Create Work Proof**

Request: **Create Work Proof**
- Update request body with your data:
  ```json
  {
    "work_proof": {
      "issue_id": YOUR_ISSUE_ID,
      "date": "2025-10-29",
      "image_url": "https://your-image-url.jpg",
      "description": "Test work proof",
      "work_hours": 3.0,
      "status": "completed"
    }
  }
  ```
- Click **Send**
- Should return 201 Created with new work proof

### **3. Get Created Work Proof**

Request: **Get Single Work Proof**
- Update `WORK_PROOF_ID` variable with ID from step 2
- Click **Send**
- Should return 200 OK with work proof details

### **4. Update Work Proof**

Request: **Update Work Proof**
- Update request body:
  ```json
  {
    "work_proof": {
      "description": "Updated description",
      "status": "reviewed"
    }
  }
  ```
- Click **Send**
- Should return 200 OK with updated work proof

### **5. Delete Work Proof**

Request: **Delete Work Proof**
- Click **Send**
- Should return 204 No Content

---

## 🔍 **Understanding Responses**

### **Successful Responses**

**List Response (200 OK):**
```json
{
  "work_proofs": [
    {
      "id": 1,
      "project_id": 1,
      "project_name": "My Project",
      "issue_id": 123,
      "issue_subject": "Task title",
      "user_id": 5,
      "user_name": "John Doe",
      "user_login": "john.doe",
      "date": "2025-10-29",
      "image_url": "https://...",
      "description": "...",
      "work_hours": 4.5,
      "status": "completed"
    }
  ],
  "total_count": 1,
  "limit": 25,
  "offset": 0
}
```

**Create Response (201 Created):**
```json
{
  "work_proof": {
    "id": 2,
    // ... all fields ...
  }
}
```

### **Error Responses**

**401 Unauthorized:**
```json
{
  "error": "Invalid credentials"
}
```
**Fix:** Check API_KEY in environment

**403 Forbidden:**
```json
{
  "error": "Forbidden"
}
```
**Fix:** User needs proper permissions

**422 Validation Error:**
```json
{
  "errors": [
    "Issue can't be blank",
    "Date can't be blank"
  ]
}
```
**Fix:** Provide required fields

---

## 💡 **Tips & Tricks**

### **1. Use Variables**

In request body, use `{{variable}}`:
```json
{
  "work_proof": {
    "issue_id": {{ISSUE_ID}},
    "date": "{{TODAY}}"
  }
}
```

### **2. Save Responses**

After successful request:
- Click **Save Response**
- Use as example for documentation

### **3. Use Tests Tab**

Add automatic tests:
```javascript
// In Tests tab of request
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

pm.test("Has work_proofs array", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('work_proofs');
});

// Save work_proof_id for next request
var jsonData = pm.response.json();
if (jsonData.work_proof) {
    pm.environment.set("WORK_PROOF_ID", jsonData.work_proof.id);
}
```

### **4. Create Test Workflow**

Use Postman **Runner** to test all endpoints in sequence:
1. Create Work Proof → saves ID
2. Get Work Proof → uses saved ID
3. Update Work Proof → uses saved ID
4. Delete Work Proof → uses saved ID

---

## 🔐 **Authentication Setup**

The collection already has authentication configured at collection level.

**To verify:**
1. Click on collection name
2. Go to **Authorization** tab
3. Type should be: **API Key**
4. Key: `X-Redmine-API-Key`
5. Value: `{{API_KEY}}`
6. Add to: **Header**

This applies to ALL requests in the collection! ✅

---

## 📱 **Generate Code**

Postman can generate code for your mobile app:

1. Select any request
2. Click **Code** (right side, under Send button)
3. Choose language:
   - Swift
   - Kotlin
   - JavaScript (Fetch)
   - JavaScript (Axios)
   - Dart (http)
   - And many more!
4. Copy code to your app

---

## 🎯 **Quick Start Checklist**

- [ ] Import collection file
- [ ] Import environment file
- [ ] Select "WorkProof Production" environment
- [ ] Get API key from Redmine
- [ ] Add API key to environment
- [ ] Update PROJECT_ID if needed
- [ ] Test "List All Work Proofs" request
- [ ] Try "Create Work Proof" request
- [ ] Success! ✅

---

## 📞 **Troubleshooting**

### **Request fails with 401**

- Check API_KEY is set in environment
- Verify API key is correct (copy from Redmine)
- Make sure environment is selected (top right)

### **Request fails with 404**

- Check BASE_URL is correct
- Check PROJECT_ID exists
- Check WORK_PROOF_ID exists (for show/update/delete)

### **Request fails with 403**

- User doesn't have required permission
- Check role permissions in Redmine admin panel

### **Connection timeout**

- Check BASE_URL (https://track.gocomart.com)
- Check server is running
- Check firewall allows HTTPS (port 443)

---

## 📚 **Additional Resources**

- **Complete API Documentation**: `WORKPROOF_API.md`
- **Development Workflow**: `DEVELOPMENT_WORKFLOW.md`
- **SSL Setup Guide**: `SSL_DOMAIN_SETUP.md`

---

## 🎉 **You're Ready!**

**Import the files and start testing your WorkProof API!**

Files to import:
1. `WorkProof_API.postman_collection.json`
2. `WorkProof_API.postman_environment.json`

**Happy testing!** 🚀

