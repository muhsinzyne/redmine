# Postman Setup Guide for WorkProof API

Quick guide to test the WorkProof API using Postman.

---

## 📥 **Import Postman Collection**

### **Step 1: Import Collection**

1. Open **Postman**
2. Click **Import** button (top left)
3. Choose **File** tab
4. Select `WorkProof_API.postman_collection.json`
5. Click **Import**

✅ You now have all API endpoints ready to test!

### **Step 2: Import Environment**

1. Click **Environments** (left sidebar)
2. Click **Import**
3. Select `WorkProof_API.postman_environment.json`
4. Click **Import**

✅ Environment variables are configured!

### **Step 3: Set Your API Key**

1. Select **WorkProof Production** environment (top right dropdown)
2. Click the **eye icon** next to environment name
3. Click **Edit**
4. Update these values:

| Variable | Value | Description |
|----------|-------|-------------|
| `API_KEY` | Your actual API key | Get from Redmine → My Account → API access key |
| `BASE_URL` | `https://track.gocomart.com` | Already set ✅ |
| `PROJECT_ID` | Your project ID | Find in Redmine URL |
| `USERNAME` | `admin` | Or your username |
| `PASSWORD` | Your password | If using Basic Auth |

5. Click **Save**

---

## 🔑 **Get Your API Key**

### **From Redmine Web Interface:**

1. Login to https://track.gocomart.com
2. Click **My account** (top right)
3. Look for **API access key** section
4. Click **Show** or **Reset**
5. Copy the API key
6. Paste in Postman environment variable `API_KEY`

**Your API key looks like:**
```
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

---

## 🧪 **Testing the API**

### **Test 1: Authentication**

1. Open **Authentication** folder
2. Click **Test API Key Authentication**
3. Click **Send**

**Expected Response (200 OK):**
```json
{
  "user": {
    "id": 1,
    "login": "admin",
    "firstname": "Redmine",
    "lastname": "Admin",
    ...
  }
}
```

✅ Authentication works!

### **Test 2: List Work Proofs**

1. Open **Work Proofs** folder
2. Click **List All Work Proofs**
3. Update `PROJECT_ID` in environment if needed
4. Click **Send**

**Expected Response (200 OK):**
```json
{
  "work_proofs": [...],
  "total_count": 0,
  "limit": 25,
  "offset": 0
}
```

### **Test 3: Create Work Proof**

1. Open **Create Work Proof** request
2. Update the request body:
   - Change `issue_id` to a valid issue ID
   - Update `date` if needed
   - Change `image_url` to your image URL
3. Click **Send**

**Expected Response (201 Created):**
```json
{
  "work_proof": {
    "id": 1,
    "project_id": 1,
    "issue_id": 1,
    ...
  }
}
```

---

## 📋 **Available Requests**

### **Work Proofs Folder**

1. ✅ **List All Work Proofs** - Get all work proofs
2. ✅ **List Work Proofs - Today** - Filter by today's date
3. ✅ **List Work Proofs - By User** - Filter by user ID
4. ✅ **List Work Proofs - Date Range** - Filter by date range
5. ✅ **List Work Proofs - With Pagination** - Paginated results
6. ✅ **Get Single Work Proof** - Get specific work proof
7. ✅ **Create Work Proof** - Create new work proof
8. ✅ **Update Work Proof** - Update existing work proof
9. ✅ **Delete Work Proof** - Delete work proof

### **Authentication Folder**

1. ✅ **Test API Key Authentication** - Verify API key
2. ✅ **Test Basic Auth** - Test username/password

### **Helper Endpoints Folder**

1. ✅ **List Projects** - Get all projects
2. ✅ **List Project Issues** - Get issues in project
3. ✅ **List Project Members** - Get project members
4. ✅ **Get Current User** - Get authenticated user info

---

## 🎯 **Quick Start**

### **1. Setup (One Time)**

```
✅ Import collection
✅ Import environment
✅ Get API key from Redmine
✅ Update API_KEY in environment
```

### **2. Test Authentication**

```
✅ Run: Test API Key Authentication
✅ Should return your user info
```

### **3. Find Your Project ID**

```
✅ Run: List Projects
✅ Find your project ID in response
✅ Update PROJECT_ID in environment
```

### **4. Test Work Proofs**

```
✅ Run: List All Work Proofs
✅ Run: Create Work Proof (with valid issue_id)
✅ Run: Get Single Work Proof
✅ Run: Update Work Proof
✅ Run: Delete Work Proof
```

---

## 🔧 **Environment Variables**

| Variable | Example | Where to Find |
|----------|---------|---------------|
| `BASE_URL` | `https://track.gocomart.com` | Your Redmine URL |
| `API_KEY` | `a1b2c3d4...` | My Account → API access key |
| `PROJECT_ID` | `1` | Projects list or URL |
| `WORK_PROOF_ID` | `1` | From create response |
| `USER_ID` | `5` | Project members list |
| `USERNAME` | `admin` | Your username |
| `PASSWORD` | `yourpass` | Your password |
| `TODAY` | `2025-10-29` | Auto-generated |

---

## 📝 **Example Workflow**

### **Scenario: Mobile App Developer Testing**

```
1. Import collection ✅
2. Set API_KEY ✅
3. Test authentication ✅
4. List projects → Get PROJECT_ID
5. List issues → Get ISSUE_ID
6. Create work proof with:
   {
     "issue_id": ISSUE_ID,
     "date": "2025-10-29",
     "image_url": "https://...",
     "work_hours": 3.5
   }
7. Verify work proof created ✅
8. Implement in mobile app ✅
```

---

## 🐛 **Troubleshooting**

### **401 Unauthorized**

**Problem:** Invalid API key

**Solution:**
1. Get fresh API key from Redmine
2. Update `API_KEY` in environment
3. Click **Save**
4. Try again

### **403 Forbidden**

**Problem:** No permission for operation

**Solution:**
1. Check user has required permission
2. Admin → Roles → Enable permissions:
   - view_work_proof
   - manage_work_proof

### **404 Not Found**

**Problem:** Invalid project ID or work proof ID

**Solution:**
1. Run "List Projects" to get correct PROJECT_ID
2. Update environment variable
3. Try again

### **422 Validation Error**

**Problem:** Missing required fields

**Solution:**
1. Check request body includes:
   - issue_id ✅
   - date ✅
   - image_url ✅
2. Update request body
3. Send again

---

## 📊 **Sample Responses**

### **List Work Proofs Response**

```json
{
  "work_proofs": [
    {
      "id": 1,
      "project_id": 1,
      "project_name": "My Project",
      "issue_id": 123,
      "issue_subject": "Implement login feature",
      "user_id": 5,
      "user_name": "John Doe",
      "user_login": "john.doe",
      "date": "2025-10-29",
      "image_url": "https://example.com/proof.jpg",
      "description": "Completed login implementation",
      "work_hours": 4.5,
      "status": "completed"
    }
  ],
  "total_count": 1,
  "limit": 25,
  "offset": 0
}
```

### **Create Work Proof Response**

```json
{
  "work_proof": {
    "id": 2,
    "project_id": 1,
    "project_name": "My Project",
    "issue_id": 124,
    "issue_subject": "New feature",
    "user_id": 5,
    "user_name": "John Doe",
    "user_login": "john.doe",
    "date": "2025-10-29",
    "image_url": "https://example.com/proof2.jpg",
    "description": "Feature completed",
    "work_hours": 3.0,
    "status": "completed"
  }
}
```

### **Error Response**

```json
{
  "errors": [
    "Issue can't be blank",
    "Date can't be blank",
    "Image url can't be blank"
  ]
}
```

---

## 🚀 **Quick Tips**

### **Save Responses**

After successful API calls:
- Click **Save Response** → **Save as Example**
- Helps document API behavior

### **Use Variables**

Use `{{variable}}` syntax in:
- URLs
- Headers  
- Request body
- Tests

Example:
```json
{
  "work_proof": {
    "issue_id": {{ISSUE_ID}},
    "date": "{{TODAY}}",
    ...
  }
}
```

### **Tests Tab**

Add automatic tests:

```javascript
// Test status code
pm.test("Status code is 200", function () {
    pm.response.to.have.status(200);
});

// Test response structure
pm.test("Response has work_proofs array", function () {
    var jsonData = pm.response.json();
    pm.expect(jsonData).to.have.property('work_proofs');
});

// Save work proof ID for next request
pm.test("Save work proof ID", function () {
    var jsonData = pm.response.json();
    pm.environment.set("WORK_PROOF_ID", jsonData.work_proof.id);
});
```

---

## 📱 **Export for Mobile Team**

### **Share Collection**

1. Right-click collection
2. Click **Export**
3. Choose **Collection v2.1**
4. Save and send to your mobile developers

### **Share Environment**

1. Click **Environments**
2. Click **⋯** next to environment
3. Click **Export**
4. Send to team

---

## 🔗 **API Documentation Link**

Full API documentation: `WORKPROOF_API.md`

Includes:
- Complete endpoint reference
- Mobile app code examples (Flutter, React Native, iOS, Android)
- Error handling
- Best practices

---

## ✅ **Postman Collection Includes**

**13 Ready-to-Use Requests:**
- ✅ 9 Work Proof operations
- ✅ 2 Authentication tests
- ✅ 4 Helper endpoints

**Pre-configured:**
- ✅ Authentication header
- ✅ Environment variables
- ✅ Request examples
- ✅ Auto-generated dates

**Ready for:**
- ✅ API testing
- ✅ Mobile app development
- ✅ Integration testing
- ✅ Documentation

---

## 🎉 **You're Ready!**

1. **Import** both files into Postman
2. **Set your API key**
3. **Start testing!**

**Files:**
- `WorkProof_API.postman_collection.json` - Collection
- `WorkProof_API.postman_environment.json` - Environment

**Happy testing!** 🚀

