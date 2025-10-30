# Redmine API Documentation

Complete API documentation and Postman collections for Redmine and custom plugins.

## 📚 Available Documentation

### Core Redmine APIs

| Document | Description |
|----------|-------------|
| [**REDMINE_COMPLETE_API_GUIDE.md**](REDMINE_COMPLETE_API_GUIDE.md) | Complete guide to all 79+ standard Redmine REST API endpoints |
| [**GCS_SETUP_GUIDE.md**](GCS_SETUP_GUIDE.md) | Google Cloud Storage setup for file storage |
| [**GCS_KEY_MANAGEMENT.md**](GCS_KEY_MANAGEMENT.md) | GCS service account key management |
| [**GCS_QUICK_SETUP.md**](GCS_QUICK_SETUP.md) | Quick automated GCS setup |

### Custom Plugin APIs

| Document | Description |
|----------|-------------|
| [**TIME_TRACKING_API.md**](TIME_TRACKING_API.md) | Complete guide for WorkProof and Time Clocking APIs |

---

## 🚀 Postman Collections

### 1. Redmine Complete REST API (79+ Endpoints)

Complete standard Redmine API coverage based on official documentation.

**Files:**
- `Redmine_Complete_API.postman_collection.json`
- `Redmine_Complete_API_Local.postman_environment.json`
- `Redmine_Complete_API_Production.postman_environment.json`

**Coverage:**
- ✅ Issues (8 endpoints)
- ✅ Projects (5)
- ✅ Users (6)
- ✅ Time Entries (6)
- ✅ Attachments (4)
- ✅ Wiki Pages (5)
- ✅ Issue Relations (4)
- ✅ Versions (5)
- ✅ Issue Categories (5)
- ✅ Trackers (1)
- ✅ Issue Statuses (1)
- ✅ Enumerations (3)
- ✅ Groups (7)
- ✅ Roles (2)
- ✅ Memberships (5)
- ✅ Custom Fields (1)
- ✅ Queries (1)
- ✅ News (2)
- ✅ Files (1)
- ✅ Search (2)
- ✅ My Account (2)
- ✅ Journals (3)

**Total: 79+ endpoints**

**Guide:** [REDMINE_COMPLETE_API_GUIDE.md](REDMINE_COMPLETE_API_GUIDE.md)

---

### 2. WorkProof API (22 Endpoints)

Custom time tracking system with screenshot proof and premium time clocking.

**Files:**
- `WorkProof_API.postman_collection.json`
- `WorkProof_API_Local.postman_environment.json`
- `WorkProof_API.postman_environment.json` (production)

**Coverage:**

**Work Proofs (11 endpoints)** - With screenshot upload:
- List all work proofs (with filters)
- Get single work proof
- Create work proof (with image upload)
- Update work proof
- Delete work proof
- Consolidate work proofs by issue

**Redmine Standard APIs (5 endpoints)** - Helper endpoints:
- List projects
- List issues
- List users
- List time entry activities
- List time entries

**Time Clockings (6 endpoints)** - Premium users (no screenshots):
- List time clockings
- Create time clocking (JSON only)
- Get time clocking
- Update time clocking
- Delete time clocking
- Consolidate time clockings by issue

**Total: 22 endpoints**

**Guide:** [TIME_TRACKING_API.md](TIME_TRACKING_API.md)

---

## 🔧 Quick Setup

### Step 1: Import to Postman

**Import all collections:**

1. Open Postman
2. Click **Import**
3. Drag these files:
   - `Redmine_Complete_API.postman_collection.json`
   - `Redmine_Complete_API_Local.postman_environment.json`
   - `Redmine_Complete_API_Production.postman_environment.json`
   - `WorkProof_API.postman_collection.json`
   - `WorkProof_API_Local.postman_environment.json`
   - `WorkProof_API.postman_environment.json`
4. Click **Import**

---

### Step 2: Configure Environment

**For Local Development:**

1. Select environment: **"Redmine Complete API - Local Development"** or **"WorkProof Local Development"**
2. Set `API_KEY`:
   - Login to Redmine (http://localhost:4001)
   - Go to **My Account**
   - Scroll to **API access key**
   - Click **Show**
   - Copy and paste to Postman environment

**For Production:**

1. Select environment: **"Redmine Complete API - Production"** or **"WorkProof API - Production"**
2. Set `API_KEY`:
   - Login to https://track.gocomart.com
   - Go to **My Account**
   - Copy API key
   - Paste to Postman environment

---

### Step 3: Test

**Test Redmine Complete API:**

1. Request: `My Account → Get My Account`
2. Should return your user details ✅

**Test WorkProof API:**

1. Request: `Redmine Standard APIs → List Projects`
2. Should return projects ✅

---

## 📖 Documentation Structure

```
docs/
├── README.md                                          ← You are here
├── REDMINE_COMPLETE_API_GUIDE.md                     ← Complete Redmine API guide
├── TIME_TRACKING_API.md                              ← WorkProof & Time Clocking guide
├── GCS_SETUP_GUIDE.md                                ← Google Cloud Storage setup
├── GCS_KEY_MANAGEMENT.md                             ← GCS key management
├── GCS_QUICK_SETUP.md                                ← Automated GCS setup
├── Redmine_Complete_API.postman_collection.json      ← 79+ Redmine endpoints
├── Redmine_Complete_API_Local.postman_environment.json
├── Redmine_Complete_API_Production.postman_environment.json
├── WorkProof_API.postman_collection.json             ← 22 WorkProof endpoints
├── WorkProof_API_Local.postman_environment.json
└── WorkProof_API.postman_environment.json
```

---

## 🎯 Use Cases

### Standard Redmine Operations

**Use: Redmine Complete API Collection**

- Managing issues, projects, users
- Time tracking with standard time entries
- Wiki pages, attachments, files
- Project administration
- User and group management
- Issue relations and versions
- Search and queries

**Guide:** [REDMINE_COMPLETE_API_GUIDE.md](REDMINE_COMPLETE_API_GUIDE.md)

---

### Time Tracking with Screenshot Proof

**Use: WorkProof API Collection → Work Proofs**

- Mobile apps that track time with screenshots
- Proof of work for remote teams
- Screenshot-based time tracking
- Automatic consolidation to time entries
- Image storage in Google Cloud Storage

**Features:**
- Upload screenshot with each work proof
- Track incremental hours
- Consolidate multiple proofs to single time entry
- GCS storage for images

**Guide:** [TIME_TRACKING_API.md](TIME_TRACKING_API.md) → Work Proofs section

---

### Time Tracking WITHOUT Screenshots (Premium)

**Use: WorkProof API Collection → Time Clockings**

- Premium/trusted users
- No screenshot required
- JSON-only requests (faster, less bandwidth)
- Same consolidation logic as work proofs
- For users who don't need screenshot proof

**Features:**
- Simple JSON API
- Track incremental hours
- Consolidate to time entries
- No image upload/storage overhead

**Guide:** [TIME_TRACKING_API.md](TIME_TRACKING_API.md) → Time Clockings section

---

## 🔐 Authentication

All APIs use **Redmine API Key** authentication.

**Header:**
```
X-Redmine-API-Key: your-api-key-here
```

**Get your API key:**

1. Login to Redmine
2. Top right: **My Account**
3. Scroll to **API access key**
4. Click **Show**
5. Copy the key

**Enable API in Redmine:**

- Administration → Settings → API
- Check **Enable REST API**
- Save

---

## 🌐 Environments

### Local Development

- **URL:** http://localhost:4001
- **Use for:** Development and testing
- **Environment files:**
  - `Redmine_Complete_API_Local.postman_environment.json`
  - `WorkProof_API_Local.postman_environment.json`

### Production

- **URL:** https://track.gocomart.com
- **Use for:** Production API testing
- **Environment files:**
  - `Redmine_Complete_API_Production.postman_environment.json`
  - `WorkProof_API.postman_environment.json`

---

## 📊 API Comparison

| Feature | Redmine Complete API | WorkProof API | Time Clocking API |
|---------|---------------------|---------------|-------------------|
| **Endpoints** | 79+ | 11 | 6 |
| **Type** | Core Redmine | Custom Plugin | Custom Plugin |
| **Screenshot** | ❌ | ✅ Required | ❌ |
| **Image Storage** | Redmine DB | GCS | N/A |
| **Use Case** | General Redmine | Screenshot proof | Premium users |
| **Mobile Friendly** | ✅ | ✅ | ✅ Very |
| **Bandwidth** | Low | High (images) | Very Low |
| **Time Tracking** | Standard | With proof | Without proof |
| **Auto Consolidate** | ❌ | ✅ | ✅ |

---

## 🛠️ Additional Tools

### Kill Port Script

Kill processes on specific ports (useful when Rails server is stuck).

**File:** `../kill-port.sh`

**Usage:**
```bash
./kill-port.sh 4001    # Kill port 4001
./kill-port.sh 3000    # Kill port 3000
./kill-port.sh         # Default: 4001
```

---

## 📝 Notes

### WorkProof vs Time Clocking

**WorkProof (with screenshots):**
- For mobile field workers
- Requires screenshot upload
- Proof of work
- Images stored in GCS
- Consolidates to time_entries

**Time Clocking (no screenshots):**
- For premium/office users
- JSON-only (fast)
- No image storage needed
- Same consolidation logic
- Separate table (time_clockings)

**Both:**
- Track incremental hours (not cumulative)
- Auto-consolidate to time_entries
- Use same activity_id system
- Same permissions model

---

## 🎉 Summary

**You now have:**

- ✅ **79+ Standard Redmine API endpoints** (complete core functionality)
- ✅ **22 Custom WorkProof/Time Clocking endpoints** (time tracking)
- ✅ **Comprehensive documentation** (500+ lines per guide)
- ✅ **Local & Production environments** (ready to use)
- ✅ **Authentication configured** (API key based)
- ✅ **Examples for all endpoints** (JSON request/response)

**Total: 101+ API endpoints available in Postman!** 🚀

---

## 📚 External Resources

**Official Redmine API:**
- Main: https://www.redmine.org/projects/redmine/wiki/rest_api
- Issues: https://www.redmine.org/projects/redmine/wiki/Rest_Issues
- Projects: https://www.redmine.org/projects/redmine/wiki/Rest_Projects
- Users: https://www.redmine.org/projects/redmine/wiki/Rest_Users
- Time Entries: https://www.redmine.org/projects/redmine/wiki/Rest_TimeEntries

**Google Cloud Storage:**
- Documentation: https://cloud.google.com/storage/docs
- Ruby Client: https://github.com/googleapis/google-cloud-ruby

---

## 🤝 Support

For issues or questions:

1. Check the relevant guide in this folder
2. Review Postman collection documentation
3. Test in local environment first
4. Check API response errors (422, 403, 404)
5. Verify API key is correct
6. Ensure API is enabled in Redmine settings

---

**Happy API Testing!** 🎊
