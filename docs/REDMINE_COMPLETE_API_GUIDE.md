# Redmine Complete REST API - Postman Collection Guide

Complete collection of all standard Redmine REST API endpoints based on official documentation.

**Source:** https://www.redmine.org/projects/redmine/wiki/rest_api

## 📦 Collection Overview

### Total Coverage: 100+ API Endpoints

| Category | Endpoints | Description |
|----------|-----------|-------------|
| **Issues** | 8 | Complete CRUD + watchers |
| **Projects** | 5 | CRUD operations |
| **Users** | 6 | User management + current user |
| **Time Entries** | 6 | Time tracking CRUD |
| **Attachments** | 4 | File upload/download |
| **Wiki Pages** | 5 | Wiki content management |
| **Issue Relations** | 4 | Relationship management |
| **Versions** | 5 | Project milestones |
| **Issue Categories** | 5 | Category management |
| **Trackers** | 1 | List trackers (Bug, Feature, etc) |
| **Issue Statuses** | 1 | List all statuses |
| **Enumerations** | 3 | Priorities, activities, categories |
| **Groups** | 7 | User group management |
| **Roles** | 2 | Role and permissions |
| **Memberships** | 5 | Project membership management |
| **Custom Fields** | 1 | List custom field definitions |
| **Queries** | 1 | List saved queries |
| **News** | 2 | Project news/announcements |
| **Files** | 1 | Project files |
| **Search** | 2 | Global search |
| **My Account** | 2 | Current user account |
| **Journals** | 3 | Issue change history |

**Total: 79 Standard Redmine API Endpoints** ✅

---

## 🚀 Quick Start

### Step 1: Import Collection

1. **Download files:**
   - `docs/Redmine_Complete_API.postman_collection.json`
   - `docs/Redmine_Complete_API_Local.postman_environment.json`
   - `docs/Redmine_Complete_API_Production.postman_environment.json`

2. **In Postman:**
   - Click **Import**
   - Drag all 3 files
   - Click **Import**

### Step 2: Configure Environment

1. **Select environment:** "Redmine Complete API - Local Development"

2. **Set your API key:**
   - Login to Redmine
   - Go to: **My Account** (top right)
   - Scroll to **API access key**
   - Click **Show**
   - Copy the key
   - In Postman environment, set `API_KEY` value

3. **Adjust other variables as needed:**
   - `PROJECT_ID`: Your project ID (default: 1)
   - `ISSUE_ID`: Test issue ID (default: 1)
   - `USER_ID`: Your user ID (default: 1)

### Step 3: Test Authentication

Try these requests first:

1. **Get Current User**
   - Path: `My Account → Get My Account`
   - Should return your user details ✅

2. **List Projects**
   - Path: `Projects → List Projects`
   - Should return visible projects ✅

3. **List Issues**
   - Path: `Issues → List Issues`
   - Should return issues ✅

---

## 📚 Collection Structure

### 1. Issues (8 endpoints)

Complete issue management with advanced filtering.

**List Issues:**
- `GET /issues.json` - All issues with pagination
- `GET /issues.json?project_id=1&status_id=open&assigned_to_id=me` - Filtered

**Single Issue:**
- `GET /issues/{id}.json?include=journals,attachments,relations` - Get with details
- `POST /issues.json` - Create new issue
- `PUT /issues/{id}.json` - Update issue
- `DELETE /issues/{id}.json` - Delete issue

**Watchers:**
- `POST /issues/{id}/watchers.json?user_id={user_id}` - Add watcher
- `DELETE /issues/{id}/watchers/{user_id}.json` - Remove watcher

**Example: Create Issue with Custom Fields**
```json
POST /issues.json
{
  "issue": {
    "project_id": 1,
    "tracker_id": 1,
    "subject": "New issue from API",
    "description": "Issue description",
    "priority_id": 2,
    "assigned_to_id": 1,
    "custom_fields": [
      {"id": 1, "value": "Custom value"}
    ],
    "watcher_user_ids": [1, 2]
  }
}
```

**Filtering Options:**
- `project_id`: Filter by project
- `tracker_id`: Filter by tracker (Bug, Feature, etc)
- `status_id`: `open`, `closed`, or specific ID
- `assigned_to_id`: `me` or user ID
- `priority_id`: Filter by priority
- `created_on`: `>=2025-01-01` or `<=2025-12-31`
- `updated_on`: Date filters
- `cf_X`: Custom field filters

---

### 2. Projects (5 endpoints)

Project creation and management.

- `GET /projects.json?include=trackers,issue_categories` - List all
- `GET /projects/{id}.json` - Get single project
- `POST /projects.json` - Create project
- `PUT /projects/{id}.json` - Update project
- `DELETE /projects/{id}.json` - Delete project

**Example: Create Project**
```json
POST /projects.json
{
  "project": {
    "name": "New Project",
    "identifier": "new-project",
    "description": "Project description",
    "is_public": true,
    "enabled_module_names": [
      "issue_tracking",
      "time_tracking",
      "wiki",
      "repository"
    ],
    "tracker_ids": [1, 2, 3]
  }
}
```

---

### 3. Users (6 endpoints)

User account management.

- `GET /users.json?status=1` - List active users
- `GET /users/{id}.json?include=memberships,groups` - Get user
- `GET /users/current.json` - Get current authenticated user
- `POST /users.json` - Create user
- `PUT /users/{id}.json` - Update user
- `DELETE /users/{id}.json` - Delete user

**Status values:**
- `1`: Active
- `2`: Registered (not activated)
- `3`: Locked

**Example: Create User**
```json
POST /users.json
{
  "user": {
    "login": "newuser",
    "firstname": "John",
    "lastname": "Doe",
    "mail": "john.doe@example.com",
    "password": "SecurePass123!",
    "mail_notification": "all"
  }
}
```

---

### 4. Time Entries (6 endpoints)

Time tracking and reporting.

- `GET /time_entries.json` - List all time entries
- `GET /time_entries.json?project_id=1&user_id=me&from=2025-10-01&to=2025-10-31` - Filtered
- `GET /time_entries/{id}.json` - Get single entry
- `POST /time_entries.json` - Create time entry
- `PUT /time_entries/{id}.json` - Update time entry
- `DELETE /time_entries/{id}.json` - Delete time entry

**Example: Log Time**
```json
POST /time_entries.json
{
  "time_entry": {
    "issue_id": 1,
    "spent_on": "2025-10-30",
    "hours": 2.5,
    "activity_id": 9,
    "comments": "Work description"
  }
}
```

---

### 5. Attachments (4 endpoints)

File upload and download (2-step process).

**Step 1: Upload File**
```bash
POST /uploads.json?filename=document.pdf
Content-Type: application/octet-stream
Body: [binary file content]

Response:
{
  "upload": {
    "token": "7167.ed1ccdb093229ca1bd0b043618d88743"
  }
}
```

**Step 2: Attach to Issue**
```json
POST /issues.json
{
  "issue": {
    "project_id": 1,
    "subject": "Issue with attachment",
    "uploads": [
      {
        "token": "7167.ed1ccdb093229ca1bd0b043618d88743",
        "filename": "document.pdf",
        "content_type": "application/pdf"
      }
    ]
  }
}
```

**Download:**
- `GET /attachments/{id}.json` - Get metadata
- `GET /attachments/download/{id}/{filename}` - Download file

---

### 6. Wiki Pages (5 endpoints)

Wiki content management.

- `GET /projects/{id}/wiki/index.json` - List all pages
- `GET /projects/{id}/wiki/{page}.json` - Get page content
- `GET /projects/{id}/wiki/{page}/{version}.json` - Get specific version
- `PUT /projects/{id}/wiki/{page}.json` - Create/update page
- `DELETE /projects/{id}/wiki/{page}.json` - Delete page

**Example: Create Wiki Page**
```json
PUT /projects/1/wiki/Documentation.json
{
  "wiki_page": {
    "text": "# Documentation\n\nContent in Textile or Markdown.",
    "comments": "Created via API"
  }
}
```

---

### 7. Issue Relations (4 endpoints)

Manage relationships between issues.

- `GET /issues/{id}/relations.json` - List relations
- `POST /issues/{id}/relations.json` - Create relation
- `GET /relations/{id}.json` - Get relation
- `DELETE /relations/{id}.json` - Delete relation

**Relation types:**
- `relates`: Related to
- `duplicates`: Duplicates
- `duplicated`: Duplicated by
- `blocks`: Blocks
- `blocked`: Blocked by
- `precedes`: Precedes
- `follows`: Follows

**Example:**
```json
POST /issues/1/relations.json
{
  "relation": {
    "issue_to_id": 2,
    "relation_type": "relates"
  }
}
```

---

### 8. Versions (5 endpoints)

Project milestones/versions.

- `GET /projects/{id}/versions.json` - List versions
- `GET /versions/{id}.json` - Get version
- `POST /projects/{id}/versions.json` - Create version
- `PUT /versions/{id}.json` - Update version
- `DELETE /versions/{id}.json` - Delete version

**Example:**
```json
POST /projects/1/versions.json
{
  "version": {
    "name": "v1.0.0",
    "status": "open",
    "due_date": "2025-12-31",
    "description": "First major release"
  }
}
```

---

### 9. Groups (7 endpoints)

User group management.

- `GET /groups.json` - List all groups
- `GET /groups/{id}.json?include=users,memberships` - Get group
- `POST /groups.json` - Create group
- `PUT /groups/{id}.json` - Update group
- `DELETE /groups/{id}.json` - Delete group
- `POST /groups/{id}/users.json` - Add user to group
- `DELETE /groups/{id}/users/{user_id}.json` - Remove user from group

---

### 10. Memberships (5 endpoints)

Project membership management.

- `GET /projects/{id}/memberships.json` - List memberships
- `GET /memberships/{id}.json` - Get membership
- `POST /projects/{id}/memberships.json` - Add member
- `PUT /memberships/{id}.json` - Update roles
- `DELETE /memberships/{id}.json` - Remove member

**Example: Add User to Project**
```json
POST /projects/1/memberships.json
{
  "membership": {
    "user_id": 2,
    "role_ids": [3, 4]
  }
}
```

---

### 11. Enumerations (3 endpoints)

System enumerations (priorities, activities, categories).

- `GET /enumerations/issue_priorities.json` - Priorities (Low, Normal, High, etc)
- `GET /enumerations/time_entry_activities.json` - Activities (Development, Testing, etc)
- `GET /enumerations/document_categories.json` - Document categories

---

### 12. Search (2 endpoints)

Global search across Redmine.

- `GET /search.json?q=query` - Search all
- `GET /search.json?q=query&scope=project_1&issues=1&wiki_pages=1` - Search in project

**Filters:**
- `scope`: `project_{id}` (search within project)
- `issues`: `1` (include issues)
- `news`: `1` (include news)
- `documents`: `1` (include documents)
- `wiki_pages`: `1` (include wiki)
- `messages`: `1` (include forum messages)
- `projects`: `1` (include projects)

---

### 13. Read-Only Endpoints

**Trackers:**
- `GET /trackers.json` - List all trackers (Bug, Feature, Task, etc)

**Issue Statuses:**
- `GET /issue_statuses.json` - List all statuses (New, In Progress, Resolved, etc)

**Roles:**
- `GET /roles.json` - List all roles
- `GET /roles/{id}.json` - Get role with permissions

**Custom Fields:**
- `GET /custom_fields.json` - List all custom fields

**Queries:**
- `GET /queries.json` - List saved queries

**News:**
- `GET /news.json` - List all news
- `GET /projects/{id}/news.json` - List project news

**Files:**
- `GET /projects/{id}/files.json` - List project files

---

## 🔐 Authentication

Redmine supports 3 authentication methods:

### 1. API Key (Recommended)

**In Header:**
```
X-Redmine-API-Key: your-api-key-here
```

**In URL:**
```
GET /issues.json?key=your-api-key-here
```

**In Postman:**
- Collection uses `X-Redmine-API-Key` header automatically
- Just set `API_KEY` in environment

### 2. HTTP Basic Authentication

```
Username: your-username
Password: your-password
```

### 3. User Impersonation (Admin only)

```
X-Redmine-Switch-User: jsmith
```

Allows admins to make API calls as another user.

---

## 📊 Pagination

All collection endpoints support pagination:

**Parameters:**
- `limit`: Results per page (default: 25, max: 100)
- `offset`: Skip first N results

**Example:**
```
GET /issues.json?limit=50&offset=100
```

**Response includes pagination metadata:**
```json
{
  "issues": [...],
  "total_count": 250,
  "limit": 50,
  "offset": 100
}
```

**To remove metadata:**
```
GET /issues.json?nometa=1
```

---

## 🎯 Include Associated Data

Use `include` parameter to load related data:

**Issues:**
```
?include=children,attachments,relations,changesets,journals,watchers
```

**Projects:**
```
?include=trackers,issue_categories,enabled_modules,time_entry_activities
```

**Users:**
```
?include=memberships,groups
```

**Groups:**
```
?include=users,memberships
```

---

## 📝 Custom Fields

### Reading Custom Fields

```json
{
  "issue": {
    "custom_fields": [
      {"id": 1, "name": "Affected version", "value": "1.0.1"},
      {"id": 2, "name": "Resolution", "value": "Fixed"}
    ]
  }
}
```

### Multiselect Custom Fields

```json
{
  "custom_fields": [
    {
      "id": 1,
      "name": "Affected version",
      "value": ["1.0.1", "1.0.2"],
      "multiple": true
    }
  ]
}
```

### Writing Custom Fields

```json
{
  "issue": {
    "subject": "Issue with custom fields",
    "custom_fields": [
      {"id": 1, "value": "1.0.2"},
      {"id": 2, "value": "Invalid"}
    ]
  }
}
```

---

## ⚠️ Error Handling

### Validation Errors (422)

```json
{
  "errors": [
    "Subject can't be blank",
    "Priority can't be blank"
  ]
}
```

### Not Found (404)

Resource doesn't exist or user lacks permission.

### Unauthorized (401)

Invalid or missing API key.

### Forbidden (403)

User lacks permission for this operation.

---

## 🔄 Content Types

Always specify `Content-Type` on POST/PUT:

**JSON:**
```
Content-Type: application/json
```

**XML:**
```
Content-Type: application/xml
```

**File Upload:**
```
Content-Type: application/octet-stream
```

---

## 📖 Response Formats

### JSON (Recommended)
```
GET /issues.json
```

### XML
```
GET /issues.xml
```

---

## 🎁 Advanced Features

### 1. Watchers

Add/remove issue watchers:

```bash
# Add watcher
POST /issues/1/watchers.json?user_id=2

# Remove watcher
DELETE /issues/1/watchers/2.json
```

### 2. Issue Relations

Create complex issue relationships:

```json
POST /issues/1/relations.json
{
  "relation": {
    "issue_to_id": 2,
    "relation_type": "blocks"
  }
}
```

### 3. Version Management

Track project milestones:

```json
POST /projects/1/versions.json
{
  "version": {
    "name": "v2.0.0",
    "status": "open",
    "due_date": "2026-01-31"
  }
}
```

### 4. Wiki History

Access wiki page versions:

```bash
# Get version 3 of a page
GET /projects/1/wiki/Documentation/3.json
```

### 5. Journals

View and edit issue change history:

```bash
# Get journal entry
GET /journals/123.json

# Update comment
PUT /journals/123.json
{
  "journal": {
    "notes": "Updated comment"
  }
}
```

---

## 🚀 Production Deployment

### Switch to Production Environment

1. **In Postman:** Select "Redmine Complete API - Production"

2. **Environment uses:**
   - `BASE_URL`: `https://track.gocomart.com`
   - `API_KEY`: Your production API key

3. **Get Production API Key:**
   - Login to https://track.gocomart.com
   - Go to **My Account**
   - Copy API key
   - Set in Postman environment

---

## 📚 Additional Resources

**Official Documentation:**
- Main API: https://www.redmine.org/projects/redmine/wiki/rest_api
- Issues: https://www.redmine.org/projects/redmine/wiki/Rest_Issues
- Projects: https://www.redmine.org/projects/redmine/wiki/Rest_Projects
- Users: https://www.redmine.org/projects/redmine/wiki/Rest_Users
- Time Entries: https://www.redmine.org/projects/redmine/wiki/Rest_TimeEntries

**API Status Legend:**
- ✅ **Stable**: Feature complete, no major changes
- 🔵 **Beta**: Usable with some minor issues
- ⚠️ **Alpha**: Major functionality, may have bugs
- 🚧 **Prototype**: Very rough, breaking changes possible

---

## 💡 Tips & Best Practices

1. **Always use HTTPS in production**
2. **Keep API keys secret** (use environment variables)
3. **Use pagination** for large datasets (max 100 per page)
4. **Include only needed associations** to improve performance
5. **Check permissions** before making requests
6. **Handle 422 validation errors** gracefully
7. **Use `nometa=1`** if your client doesn't support top-level attributes
8. **Test in local first** before hitting production

---

## 🎉 Summary

**You now have access to:**
- ✅ **79+ Standard Redmine API endpoints**
- ✅ **Complete CRUD operations** for all major resources
- ✅ **Advanced filtering and searching**
- ✅ **File upload/download**
- ✅ **Wiki management**
- ✅ **User and group management**
- ✅ **Project administration**
- ✅ **Time tracking**
- ✅ **And much more!**

**Happy API testing!** 🚀

