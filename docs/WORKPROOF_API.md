# WorkProof API Documentation

Complete REST API documentation for the WorkProof plugin - for mobile apps and integrations.

---

## 📚 **Table of Contents**

1. [Overview](#overview)
2. [Authentication](#authentication)
3. [API Endpoints](#api-endpoints)
4. [Request/Response Examples](#requestresponse-examples)
5. [Error Handling](#error-handling)
6. [Mobile App Integration](#mobile-app-integration)
7. [Testing the API](#testing-the-api)

---

## 🔍 **Overview**

**Base URL:** `https://track.gocomart.com` (or `http://209.38.123.1`)

**API Version:** 1.0

**Supported Formats:**
- JSON (recommended)
- XML

**Authentication:**
- HTTP Basic Auth
- API Key (Redmine standard)

---

## 🔐 **Authentication**

### **Method 1: HTTP Basic Authentication**

```bash
# Using username and password
curl -u username:password \
  https://track.gocomart.com/projects/1/work_proofs.json
```

### **Method 2: API Key** (Recommended for Apps)

**Get API Key:**
1. Login to Redmine
2. Go to **My Account** → **API access key**
3. Click **Show** or **Reset**
4. Copy the API key

**Use in requests:**

```bash
# Header method (recommended)
curl -H "X-Redmine-API-Key: YOUR_API_KEY" \
  https://track.gocomart.com/projects/1/work_proofs.json

# Query parameter method
curl https://track.gocomart.com/projects/1/work_proofs.json?key=YOUR_API_KEY
```

---

## 📡 **API Endpoints**

### **Base Endpoint**

```
/projects/:project_id/work_proofs
```

### **Available Endpoints**

| Method | Endpoint | Description | Permission Required |
|--------|----------|-------------|---------------------|
| GET | `/projects/:project_id/work_proofs.json` | List work proofs | view_work_proof or view_self_work_proof |
| GET | `/projects/:project_id/work_proofs/:id.json` | Get single work proof | view_work_proof or view_self_work_proof |
| POST | `/projects/:project_id/work_proofs.json` | Create work proof | manage_work_proof |
| PUT | `/projects/:project_id/work_proofs/:id.json` | Update work proof | manage_work_proof |
| DELETE | `/projects/:project_id/work_proofs/:id.json` | Delete work proof | manage_work_proof |

---

## 📖 **Request/Response Examples**

### **1. List Work Proofs**

**GET** `/projects/:project_id/work_proofs.json`

#### **Request:**

```bash
curl -H "X-Redmine-API-Key: YOUR_API_KEY" \
  "https://track.gocomart.com/projects/1/work_proofs.json"
```

#### **Query Parameters:**

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `user_id` | integer | Filter by user | `?user_id=5` |
| `issue_id` | integer | Filter by issue | `?issue_id=123` |
| `date` | string (YYYY-MM-DD) | Filter by specific date | `?date=2025-10-29` |
| `start_date` | string (YYYY-MM-DD) | Filter from date | `?start_date=2025-10-01` |
| `end_date` | string (YYYY-MM-DD) | Filter to date | `?end_date=2025-10-31` |
| `limit` | integer | Number of results (default: 25) | `?limit=50` |
| `offset` | integer | Pagination offset | `?offset=0` |

#### **Response (200 OK):**

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
    },
    {
      "id": 2,
      "project_id": 1,
      "project_name": "My Project",
      "issue_id": 124,
      "issue_subject": "Fix bug in dashboard",
      "user_id": 5,
      "user_name": "John Doe",
      "user_login": "john.doe",
      "date": "2025-10-29",
      "image_url": "https://example.com/proof2.jpg",
      "description": "Fixed dashboard rendering issue",
      "work_hours": 2.0,
      "status": "completed"
    }
  ],
  "total_count": 2,
  "limit": 25,
  "offset": 0
}
```

#### **Example Queries:**

```bash
# Get today's work proofs
curl -H "X-Redmine-API-Key: YOUR_API_KEY" \
  "https://track.gocomart.com/projects/1/work_proofs.json?date=2025-10-29"

# Get work proofs for specific user
curl -H "X-Redmine-API-Key: YOUR_API_KEY" \
  "https://track.gocomart.com/projects/1/work_proofs.json?user_id=5"

# Get work proofs for date range
curl -H "X-Redmine-API-Key: YOUR_API_KEY" \
  "https://track.gocomart.com/projects/1/work_proofs.json?start_date=2025-10-01&end_date=2025-10-31"

# Pagination
curl -H "X-Redmine-API-Key: YOUR_API_KEY" \
  "https://track.gocomart.com/projects/1/work_proofs.json?limit=10&offset=0"
```

---

### **2. Get Single Work Proof**

**GET** `/projects/:project_id/work_proofs/:id.json`

#### **Request:**

```bash
curl -H "X-Redmine-API-Key: YOUR_API_KEY" \
  "https://track.gocomart.com/projects/1/work_proofs/1.json"
```

#### **Response (200 OK):**

```json
{
  "work_proof": {
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
    "status": "completed",
    "created_at": "2025-10-29T10:30:00Z",
    "updated_at": "2025-10-29T10:30:00Z"
  }
}
```

---

### **3. Create Work Proof**

**POST** `/projects/:project_id/work_proofs.json`

#### **Request:**

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "work_proof": {
      "issue_id": 123,
      "date": "2025-10-29",
      "image_url": "https://example.com/proof.jpg",
      "description": "Completed task X",
      "work_hours": 3.5,
      "status": "completed"
    }
  }' \
  "https://track.gocomart.com/projects/1/work_proofs.json"
```

#### **Request Body:**

```json
{
  "work_proof": {
    "issue_id": 123,          // Required: Issue ID
    "date": "2025-10-29",     // Required: Date (YYYY-MM-DD)
    "image_url": "...",       // Required: Image/proof URL
    "description": "...",     // Optional: Description
    "work_hours": 3.5,        // Optional: Hours worked
    "status": "completed"     // Optional: Status
  }
}
```

#### **Response (201 Created):**

```json
{
  "work_proof": {
    "id": 3,
    "project_id": 1,
    "project_name": "My Project",
    "issue_id": 123,
    "issue_subject": "Implement login feature",
    "user_id": 5,
    "user_name": "John Doe",
    "user_login": "john.doe",
    "date": "2025-10-29",
    "image_url": "https://example.com/proof.jpg",
    "description": "Completed task X",
    "work_hours": 3.5,
    "status": "completed"
  }
}
```

---

### **4. Update Work Proof**

**PUT** `/projects/:project_id/work_proofs/:id.json`

#### **Request:**

```bash
curl -X PUT \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "work_proof": {
      "description": "Updated description",
      "work_hours": 5.0,
      "status": "reviewed"
    }
  }' \
  "https://track.gocomart.com/projects/1/work_proofs/3.json"
```

#### **Response (200 OK):**

```json
{
  "work_proof": {
    "id": 3,
    "description": "Updated description",
    "work_hours": 5.0,
    "status": "reviewed",
    ...
  }
}
```

---

### **5. Delete Work Proof**

**DELETE** `/projects/:project_id/work_proofs/:id.json`

#### **Request:**

```bash
curl -X DELETE \
  -H "X-Redmine-API-Key: YOUR_API_KEY" \
  "https://track.gocomart.com/projects/1/work_proofs/3.json"
```

#### **Response (204 No Content):**

Empty response body

---

## ❌ **Error Handling**

### **Error Response Format**

```json
{
  "errors": [
    "Issue can't be blank",
    "Date can't be blank"
  ]
}
```

### **HTTP Status Codes**

| Code | Meaning | When |
|------|---------|------|
| 200 | OK | Successful GET, PUT |
| 201 | Created | Successful POST |
| 204 | No Content | Successful DELETE |
| 400 | Bad Request | Invalid parameters |
| 401 | Unauthorized | Missing or invalid API key |
| 403 | Forbidden | No permission for resource |
| 404 | Not Found | Resource doesn't exist |
| 422 | Unprocessable Entity | Validation failed |
| 500 | Internal Server Error | Server error |

### **Common Errors**

#### **401 Unauthorized**

```json
{
  "error": "Invalid credentials"
}
```

**Solution:** Check API key or username/password

#### **403 Forbidden**

```json
{
  "error": "Forbidden"
}
```

**Solution:** User doesn't have required permission

#### **404 Not Found**

```json
{
  "error": "Not Found"
}
```

**Solution:** Check project ID or work proof ID

#### **422 Validation Error**

```json
{
  "errors": [
    "Issue can't be blank",
    "Date can't be blank",
    "Image url can't be blank"
  ]
}
```

**Solution:** Provide all required fields

---

## 📱 **Mobile App Integration**

### **Flutter/Dart Example**

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class WorkProofAPI {
  final String baseUrl = 'https://track.gocomart.com';
  final String apiKey;
  
  WorkProofAPI(this.apiKey);
  
  // Get work proofs
  Future<List<WorkProof>> getWorkProofs(int projectId, {String? date}) async {
    var url = '$baseUrl/projects/$projectId/work_proofs.json';
    if (date != null) {
      url += '?date=$date';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'X-Redmine-API-Key': apiKey},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['work_proofs'] as List)
          .map((wp) => WorkProof.fromJson(wp))
          .toList();
    } else {
      throw Exception('Failed to load work proofs');
    }
  }
  
  // Create work proof
  Future<WorkProof> createWorkProof(int projectId, WorkProof workProof) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/work_proofs.json'),
      headers: {
        'X-Redmine-API-Key': apiKey,
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'work_proof': workProof.toJson(),
      }),
    );
    
    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return WorkProof.fromJson(data['work_proof']);
    } else {
      throw Exception('Failed to create work proof');
    }
  }
}

class WorkProof {
  int? id;
  int issueId;
  String date;
  String imageUrl;
  String? description;
  double? workHours;
  String? status;
  
  WorkProof({
    this.id,
    required this.issueId,
    required this.date,
    required this.imageUrl,
    this.description,
    this.workHours,
    this.status,
  });
  
  factory WorkProof.fromJson(Map<String, dynamic> json) {
    return WorkProof(
      id: json['id'],
      issueId: json['issue_id'],
      date: json['date'],
      imageUrl: json['image_url'],
      description: json['description'],
      workHours: json['work_hours']?.toDouble(),
      status: json['status'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'issue_id': issueId,
      'date': date,
      'image_url': imageUrl,
      'description': description,
      'work_hours': workHours,
      'status': status,
    };
  }
}
```

### **React Native Example**

```javascript
// WorkProofAPI.js
const API_BASE_URL = 'https://track.gocomart.com';

class WorkProofAPI {
  constructor(apiKey) {
    this.apiKey = apiKey;
  }
  
  // Get work proofs
  async getWorkProofs(projectId, filters = {}) {
    const params = new URLSearchParams(filters);
    const url = `${API_BASE_URL}/projects/${projectId}/work_proofs.json?${params}`;
    
    const response = await fetch(url, {
      headers: {
        'X-Redmine-API-Key': this.apiKey,
      },
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const data = await response.json();
    return data.work_proofs;
  }
  
  // Create work proof
  async createWorkProof(projectId, workProof) {
    const response = await fetch(
      `${API_BASE_URL}/projects/${projectId}/work_proofs.json`,
      {
        method: 'POST',
        headers: {
          'X-Redmine-API-Key': this.apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ work_proof: workProof }),
      }
    );
    
    if (!response.ok) {
      const error = await response.json();
      throw new Error(error.errors.join(', '));
    }
    
    const data = await response.json();
    return data.work_proof;
  }
  
  // Update work proof
  async updateWorkProof(projectId, id, updates) {
    const response = await fetch(
      `${API_BASE_URL}/projects/${projectId}/work_proofs/${id}.json`,
      {
        method: 'PUT',
        headers: {
          'X-Redmine-API-Key': this.apiKey,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ work_proof: updates }),
      }
    );
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    return await response.json();
  }
  
  // Delete work proof
  async deleteWorkProof(projectId, id) {
    const response = await fetch(
      `${API_BASE_URL}/projects/${projectId}/work_proofs/${id}.json`,
      {
        method: 'DELETE',
        headers: {
          'X-Redmine-API-Key': this.apiKey,
        },
      }
    );
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
  }
}

export default WorkProofAPI;

// Usage example
const api = new WorkProofAPI('your-api-key-here');

// Get work proofs for today
const workProofs = await api.getWorkProofs(1, { date: '2025-10-29' });

// Create new work proof
const newProof = await api.createWorkProof(1, {
  issue_id: 123,
  date: '2025-10-29',
  image_url: 'https://example.com/image.jpg',
  description: 'Completed feature X',
  work_hours: 3.5,
  status: 'completed'
});
```

### **Swift (iOS) Example**

```swift
import Foundation

class WorkProofAPI {
    let baseURL = "https://track.gocomart.com"
    let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // Get work proofs
    func getWorkProofs(projectId: Int, date: String? = nil, completion: @escaping (Result<[WorkProof], Error>) -> Void) {
        var urlString = "\(baseURL)/projects/\(projectId)/work_proofs.json"
        if let date = date {
            urlString += "?date=\(date)"
        }
        
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(WorkProofResponse.self, from: data)
                completion(.success(response.workProofs))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Create work proof
    func createWorkProof(projectId: Int, workProof: WorkProofCreate, completion: @escaping (Result<WorkProof, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/projects/\(projectId)/work_proofs.json") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-Redmine-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["work_proof": workProof]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else { return }
            
            do {
                let response = try JSONDecoder().decode(WorkProofSingleResponse.self, from: data)
                completion(.success(response.workProof))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}

struct WorkProofResponse: Codable {
    let workProofs: [WorkProof]
    let totalCount: Int
    let limit: Int
    let offset: Int
    
    enum CodingKeys: String, CodingKey {
        case workProofs = "work_proofs"
        case totalCount = "total_count"
        case limit, offset
    }
}

struct WorkProof: Codable {
    let id: Int
    let projectId: Int
    let projectName: String
    let issueId: Int
    let issueSubject: String
    let userId: Int
    let userName: String
    let date: String
    let imageUrl: String
    let description: String?
    let workHours: Double?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case projectName = "project_name"
        case issueId = "issue_id"
        case issueSubject = "issue_subject"
        case userId = "user_id"
        case userName = "user_name"
        case date, imageUrl = "image_url"
        case description, workHours = "work_hours", status
    }
}
```

### **Kotlin (Android) Example**

```kotlin
import retrofit2.http.*
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

// API Interface
interface WorkProofAPI {
    @GET("projects/{projectId}/work_proofs.json")
    suspend fun getWorkProofs(
        @Path("projectId") projectId: Int,
        @Query("date") date: String? = null,
        @Query("user_id") userId: Int? = null,
        @Query("limit") limit: Int? = null,
        @Query("offset") offset: Int? = null,
        @Header("X-Redmine-API-Key") apiKey: String
    ): WorkProofResponse
    
    @POST("projects/{projectId}/work_proofs.json")
    suspend fun createWorkProof(
        @Path("projectId") projectId: Int,
        @Body body: WorkProofCreateRequest,
        @Header("X-Redmine-API-Key") apiKey: String
    ): WorkProofSingleResponse
    
    @PUT("projects/{projectId}/work_proofs/{id}.json")
    suspend fun updateWorkProof(
        @Path("projectId") projectId: Int,
        @Path("id") id: Int,
        @Body body: WorkProofUpdateRequest,
        @Header("X-Redmine-API-Key") apiKey: String
    ): WorkProofSingleResponse
    
    @DELETE("projects/{projectId}/work_proofs/{id}.json")
    suspend fun deleteWorkProof(
        @Path("projectId") projectId: Int,
        @Path("id") id: Int,
        @Header("X-Redmine-API-Key") apiKey: String
    )
}

// Data classes
data class WorkProofResponse(
    @SerializedName("work_proofs") val workProofs: List<WorkProof>,
    @SerializedName("total_count") val totalCount: Int,
    val limit: Int,
    val offset: Int
)

data class WorkProof(
    val id: Int,
    @SerializedName("project_id") val projectId: Int,
    @SerializedName("project_name") val projectName: String,
    @SerializedName("issue_id") val issueId: Int,
    @SerializedName("issue_subject") val issueSubject: String,
    @SerializedName("user_id") val userId: Int,
    @SerializedName("user_name") val userName: String,
    val date: String,
    @SerializedName("image_url") val imageUrl: String,
    val description: String?,
    @SerializedName("work_hours") val workHours: Double?,
    val status: String?
)

data class WorkProofCreateRequest(
    @SerializedName("work_proof") val workProof: WorkProofCreate
)

data class WorkProofCreate(
    @SerializedName("issue_id") val issueId: Int,
    val date: String,
    @SerializedName("image_url") val imageUrl: String,
    val description: String? = null,
    @SerializedName("work_hours") val workHours: Double? = null,
    val status: String? = null
)

// Retrofit setup
val retrofit = Retrofit.Builder()
    .baseUrl("https://track.gocomart.com")
    .addConverterFactory(GsonConverterFactory.create())
    .build()

val api = retrofit.create(WorkProofAPI::class.java)

// Usage
val workProofs = api.getWorkProofs(
    projectId = 1,
    date = "2025-10-29",
    apiKey = "your-api-key"
)
```

---

## 🧪 **Testing the API**

### **Using cURL**

```bash
# Set your API key
API_KEY="your-api-key-here"
BASE_URL="https://track.gocomart.com"

# List work proofs
curl -H "X-Redmine-API-Key: $API_KEY" \
  "$BASE_URL/projects/1/work_proofs.json"

# Get work proofs for today
TODAY=$(date +%Y-%m-%d)
curl -H "X-Redmine-API-Key: $API_KEY" \
  "$BASE_URL/projects/1/work_proofs.json?date=$TODAY"

# Create work proof
curl -X POST \
  -H "X-Redmine-API-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "work_proof": {
      "issue_id": 1,
      "date": "'$TODAY'",
      "image_url": "https://example.com/proof.jpg",
      "description": "Test proof",
      "work_hours": 2.5
    }
  }' \
  "$BASE_URL/projects/1/work_proofs.json"
```

### **Using Postman**

**Collection Setup:**

```json
{
  "info": {
    "name": "WorkProof API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "auth": {
    "type": "apikey",
    "apikey": [
      {
        "key": "value",
        "value": "{{API_KEY}}",
        "type": "string"
      },
      {
        "key": "key",
        "value": "X-Redmine-API-Key",
        "type": "string"
      },
      {
        "key": "in",
        "value": "header",
        "type": "string"
      }
    ]
  },
  "variable": [
    {
      "key": "BASE_URL",
      "value": "https://track.gocomart.com"
    },
    {
      "key": "PROJECT_ID",
      "value": "1"
    },
    {
      "key": "API_KEY",
      "value": "your-api-key-here"
    }
  ]
}
```

**Example Requests:**

1. **List Work Proofs**
   - Method: GET
   - URL: `{{BASE_URL}}/projects/{{PROJECT_ID}}/work_proofs.json`

2. **Create Work Proof**
   - Method: POST
   - URL: `{{BASE_URL}}/projects/{{PROJECT_ID}}/work_proofs.json`
   - Body (raw JSON):
   ```json
   {
     "work_proof": {
       "issue_id": 1,
       "date": "2025-10-29",
       "image_url": "https://example.com/proof.jpg",
       "description": "Test work proof",
       "work_hours": 3.0
     }
   }
   ```

---

## 📊 **Data Models**

### **WorkProof Object**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | integer | Auto | Unique identifier |
| `project_id` | integer | Yes | Project ID |
| `project_name` | string | Read-only | Project name |
| `issue_id` | integer | Yes | Related issue ID |
| `issue_subject` | string | Read-only | Issue title |
| `user_id` | integer | Auto | User who created it |
| `user_name` | string | Read-only | User's full name |
| `user_login` | string | Read-only | Username |
| `date` | string (YYYY-MM-DD) | Yes | Work proof date |
| `image_url` | string (URL) | Yes | Proof image URL |
| `description` | string | No | Work description |
| `work_hours` | float | No | Hours worked |
| `status` | string | No | Status (e.g., "completed", "pending") |
| `created_at` | datetime | Auto | Creation timestamp |
| `updated_at` | datetime | Auto | Last update timestamp |

---

## 🔒 **Permissions**

### **Permission Levels**

| Permission | Can Do |
|------------|--------|
| `view_work_proof` | View all work proofs in project |
| `view_self_work_proof` | View only own work proofs |
| `manage_work_proof` | Create, update, delete work proofs |
| Admin | Full access to everything |

### **Setting Permissions**

1. Login as admin
2. Go to **Administration** → **Roles and permissions**
3. Select role (Manager, Developer, Reporter, etc.)
4. Under **Work Proof** module:
   - ✅ View work proof (for managers)
   - ✅ View self work proof (for team members)
   - ✅ Manage work proof (for managers/admins)
5. Save

---

## 🎯 **Common Use Cases**

### **Use Case 1: Mobile App - Submit Daily Work Proof**

```javascript
// User submits work proof via mobile app
const submitWorkProof = async (issueId, imageFile) => {
  // 1. Upload image to cloud storage (S3, Cloudinary, etc.)
  const imageUrl = await uploadImage(imageFile);
  
  // 2. Create work proof
  const workProof = await api.createWorkProof(projectId, {
    issue_id: issueId,
    date: new Date().toISOString().split('T')[0],
    image_url: imageUrl,
    description: "Work completed today",
    work_hours: 8.0,
    status: "completed"
  });
  
  return workProof;
};
```

### **Use Case 2: Manager Dashboard - View Team Activity**

```javascript
// Get all work proofs for current month
const getMonthlyActivity = async (projectId) => {
  const startDate = new Date();
  startDate.setDate(1); // First day of month
  
  const endDate = new Date();
  
  const workProofs = await api.getWorkProofs(projectId, {
    start_date: startDate.toISOString().split('T')[0],
    end_date: endDate.toISOString().split('T')[0],
    limit: 100
  });
  
  return workProofs;
};
```

### **Use Case 3: Time Tracking Integration**

```javascript
// Calculate total hours worked
const calculateHours = async (projectId, userId, startDate, endDate) => {
  const workProofs = await api.getWorkProofs(projectId, {
    user_id: userId,
    start_date: startDate,
    end_date: endDate,
    limit: 1000
  });
  
  const totalHours = workProofs.reduce((sum, wp) => 
    sum + (wp.work_hours || 0), 0
  );
  
  return totalHours;
};
```

---

## 📝 **API Best Practices**

### **Rate Limiting**

- Default: 100 requests per minute per API key
- Respect HTTP 429 (Too Many Requests) responses
- Implement exponential backoff

### **Caching**

```javascript
// Cache work proofs locally
const cachedProofs = {};

const getWorkProofsWithCache = async (projectId, date) => {
  const cacheKey = `${projectId}-${date}`;
  
  if (cachedProofs[cacheKey]) {
    return cachedProofs[cacheKey];
  }
  
  const proofs = await api.getWorkProofs(projectId, { date });
  cachedProofs[cacheKey] = proofs;
  
  return proofs;
};
```

### **Error Handling**

```javascript
const safeAPICall = async (apiFunction) => {
  try {
    return await apiFunction();
  } catch (error) {
    if (error.response) {
      // Server responded with error
      switch (error.response.status) {
        case 401:
          // Redirect to login
          console.error('Unauthorized - invalid API key');
          break;
        case 403:
          console.error('Forbidden - no permission');
          break;
        case 404:
          console.error('Not found');
          break;
        case 422:
          console.error('Validation error:', error.response.data.errors);
          break;
        default:
          console.error('API error:', error.response.status);
      }
    } else {
      // Network error
      console.error('Network error:', error.message);
    }
    throw error;
  }
};
```

---

## 🔗 **API Endpoints Quick Reference**

```
Base URL: https://track.gocomart.com

GET    /projects/:project_id/work_proofs.json                    # List
GET    /projects/:project_id/work_proofs/:id.json                # Show
POST   /projects/:project_id/work_proofs.json                    # Create
PUT    /projects/:project_id/work_proofs/:id.json                # Update
DELETE /projects/:project_id/work_proofs/:id.json                # Delete

Query Parameters (GET):
  ?user_id=5                    # Filter by user
  ?issue_id=123                 # Filter by issue
  ?date=2025-10-29             # Specific date
  ?start_date=2025-10-01       # Date range start
  ?end_date=2025-10-31         # Date range end
  ?limit=25                    # Results per page
  ?offset=0                    # Pagination offset

Authentication:
  Header: X-Redmine-API-Key: YOUR_API_KEY
  Or: Basic Auth (username:password)
```

---

## 📦 **Postman Collection**

Import this JSON into Postman:

```json
{
  "info": {
    "name": "WorkProof API",
    "description": "Redmine WorkProof Plugin API",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "List Work Proofs",
      "request": {
        "method": "GET",
        "header": [{"key": "X-Redmine-API-Key", "value": "{{API_KEY}}"}],
        "url": {
          "raw": "{{BASE_URL}}/projects/{{PROJECT_ID}}/work_proofs.json?date={{TODAY}}",
          "host": ["{{BASE_URL}}"],
          "path": ["projects", "{{PROJECT_ID}}", "work_proofs.json"],
          "query": [{"key": "date", "value": "{{TODAY}}"}]
        }
      }
    },
    {
      "name": "Create Work Proof",
      "request": {
        "method": "POST",
        "header": [
          {"key": "X-Redmine-API-Key", "value": "{{API_KEY}}"},
          {"key": "Content-Type", "value": "application/json"}
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"work_proof\": {\n    \"issue_id\": 1,\n    \"date\": \"2025-10-29\",\n    \"image_url\": \"https://example.com/proof.jpg\",\n    \"description\": \"Work completed\",\n    \"work_hours\": 3.5\n  }\n}"
        },
        "url": {
          "raw": "{{BASE_URL}}/projects/{{PROJECT_ID}}/work_proofs.json",
          "host": ["{{BASE_URL}}"],
          "path": ["projects", "{{PROJECT_ID}}", "work_proofs.json"]
        }
      }
    }
  ],
  "variable": [
    {"key": "BASE_URL", "value": "https://track.gocomart.com"},
    {"key": "API_KEY", "value": "your-api-key-here"},
    {"key": "PROJECT_ID", "value": "1"},
    {"key": "TODAY", "value": "2025-10-29"}
  ]
}
```

---

## 🚀 **Summary**

**Your WorkProof API provides:**

✅ **Full CRUD operations** (Create, Read, Update, Delete)
✅ **RESTful design** (standard HTTP methods)
✅ **JSON and XML support**
✅ **Filtering and pagination**
✅ **Permission-based access control**
✅ **Mobile app ready**
✅ **Redmine API authentication compatible**

**Perfect for:**
- 📱 Mobile apps (iOS, Android, Flutter)
- 🌐 Web applications
- 🔗 Third-party integrations
- 📊 Reporting tools
- 🤖 Automation scripts

---

**Deploy this API to production using:**

```bash
git add plugins/work_proof
git commit -m "Add WorkProof REST API for mobile apps"
git push origin master

# On production
ssh root@209.38.123.1
cd /var/www/redmine
git pull
bundle install
RAILS_ENV=production bundle exec rake redmine:plugins:migrate
systemctl restart redmine
```

**Then access:** `https://track.gocomart.com/projects/1/work_proofs.json`

