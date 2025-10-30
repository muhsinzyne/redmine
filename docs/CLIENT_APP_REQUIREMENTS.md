# Client App Requirements - Redmine Time Tracking System

**Project:** Mobile/Web Client for Redmine WorkProof & Time Clocking System  
**Backend:** Redmine 5.0+ with custom WorkProof plugin  
**API Base URL (Production):** https://track.gocomart.com  
**API Base URL (Development):** http://localhost:4001  
**Last Updated:** October 30, 2025

---

## 📋 Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [User Roles & Permissions](#user-roles--permissions)
4. [Core Features](#core-features)
5. [API Integration](#api-integration)
6. [Authentication](#authentication)
7. [Time Tracking Workflows](#time-tracking-workflows)
8. [UI/UX Requirements](#uiux-requirements)
9. [Technical Requirements](#technical-requirements)
10. [Data Models](#data-models)
11. [API Endpoints Reference](#api-endpoints-reference)
12. [Error Handling](#error-handling)
13. [Performance Requirements](#performance-requirements)
14. [Security Requirements](#security-requirements)
15. [Testing Requirements](#testing-requirements)
16. [Deployment](#deployment)

---

## 1. Project Overview

### 1.1 Purpose

Build a mobile/web client application that integrates with Redmine to provide **two distinct time tracking systems**:

1. **WorkProof System** (Standard Users)
   - Screenshot-based time tracking
   - For field workers, remote teams, contractors
   - Proof of work via automated screenshots
   - Images stored in Google Cloud Storage (GCS)

2. **Time Clocking System** (Premium Users)
   - Simple time tracking without screenshots
   - For trusted staff, office workers, managers
   - Faster, lower bandwidth
   - No image storage required

Both systems consolidate to standard Redmine `time_entries` for reporting.

---

### 1.2 Target Users

**Primary Users:**
- Remote workers (field staff, contractors)
- Office staff (developers, managers)
- Project managers (viewing reports)
- Administrators (system configuration)

**Devices:**
- Mobile: iOS 13+, Android 8+
- Tablet: iPad, Android tablets
- Desktop: Web browsers (Chrome, Safari, Firefox, Edge)

**User Base:**
- Initial: 50-100 users
- Target: 500+ users
- Geographic: Multiple time zones

---

### 1.3 Key Business Requirements

1. **Accurate Time Tracking**
   - Track work hours incrementally (not cumulative)
   - Capture time spent on specific issues/tasks
   - Associate time with Redmine projects and issues

2. **Proof of Work** (for standard users)
   - Automatic screenshot capture at intervals
   - Store screenshots securely in cloud
   - Link screenshots to time entries

3. **Flexible User Types**
   - Standard users: Require screenshot proof
   - Premium users: No screenshot required
   - Single app supports both modes

4. **Integration with Redmine**
   - Use existing Redmine projects and issues
   - Consolidate to standard time entries
   - Support Redmine permissions model

5. **Reporting & Analytics**
   - View daily/weekly/monthly time logs
   - Filter by project, issue, user, date
   - Export to standard Redmine reports

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIENT APPS                              │
├─────────────────────────────────────────────────────────────┤
│  Mobile App (iOS/Android)    │    Web App (Browser)         │
│  - Native UI                  │    - Responsive design       │
│  - Background tracking        │    - Desktop optimized       │
│  - Camera access              │    - Screen capture          │
│  - Local storage              │    - Web storage             │
└─────────────────┬───────────────────────────┬───────────────┘
                  │                           │
                  │     HTTPS + API Key       │
                  │                           │
┌─────────────────▼───────────────────────────▼───────────────┐
│               REDMINE REST API                               │
├─────────────────────────────────────────────────────────────┤
│  Core APIs                    │  WorkProof Plugin APIs       │
│  - Projects                   │  - Work Proofs (with image)  │
│  - Issues                     │  - Time Clockings (no image) │
│  - Users                      │  - Consolidation             │
│  - Time Entries               │                              │
│  - Activities                 │                              │
└─────────────────┬───────────────────────────┬───────────────┘
                  │                           │
                  │                           │
┌─────────────────▼───────────────┐  ┌────────▼──────────────┐
│     MySQL Database              │  │  Google Cloud Storage  │
│  - Projects, Issues, Users      │  │  - Screenshot images   │
│  - work_proofs                  │  │  - Public URLs         │
│  - time_clockings               │  │  - Compressed PNGs     │
│  - time_entries                 │  │                        │
└─────────────────────────────────┘  └────────────────────────┘
```

### 2.2 Technology Stack

**Backend (Already Implemented):**
- Ruby on Rails 6.1.7
- Redmine 5.0+
- MySQL 8.0
- Google Cloud Storage (GCS)
- Nginx + SSL

**Client Apps (To Be Developed):**

**Mobile:**
- iOS: Swift/SwiftUI or React Native
- Android: Kotlin or React Native
- Cross-platform: Flutter (recommended) or React Native

**Web:**
- Frontend: React.js, Vue.js, or Angular
- State Management: Redux/Vuex/NgRx
- HTTP Client: Axios or Fetch API
- Build: Webpack/Vite

**Recommended:** Flutter for mobile (single codebase) + React.js for web

---

## 3. User Roles & Permissions

### 3.1 Redmine Roles

The app must respect Redmine's permission system:

| Role | Permissions | Time Tracking Access |
|------|------------|---------------------|
| **Administrator** | Full system access | View all, manage all, configure system |
| **Manager** | Project management | View all in project, approve consolidations |
| **Developer** | Issue management | View own + team, log time, consolidate own |
| **Reporter** | View & comment | View own, log own time |
| **Anonymous** | Read-only (if public) | None |

### 3.2 WorkProof Permissions

Defined in plugin (`plugins/work_proof/init.rb`):

- `view_work_proof`: View all work proofs in project
- `view_self_work_proof`: View own work proofs only
- `manage_work_proof`: Create, update, delete work proofs
- `consolidate_work_proof`: Consolidate to time entries

### 3.3 User Types in App

**Standard User:**
- Must submit screenshots with time entries
- Uses WorkProof API
- Camera/screen capture required
- Higher data usage

**Premium User:**
- No screenshot required
- Uses Time Clocking API
- Simple JSON submissions
- Lower data usage
- Determined by app settings or admin flag

**Implementation:** Add a user preference or admin setting to mark premium users.

---

## 4. Core Features

### 4.1 Essential Features (MVP)

**Must Have:**

1. **User Authentication**
   - Login with Redmine credentials OR API key
   - Secure storage of API key
   - Auto-login with saved credentials
   - Logout functionality

2. **Project & Issue Selection**
   - List user's accessible projects
   - List issues within selected project
   - Search/filter projects and issues
   - Display issue details (subject, description, status, assignee)

3. **Time Tracking - WorkProof (with screenshots)**
   - Start work session on an issue
   - Capture screenshot at intervals (configurable: 10-30 min)
   - Track time incrementally (difference since last screenshot)
   - Select time entry activity (Development, Testing, Design, etc)
   - Add optional comments/description
   - Submit work proof (image + time data)
   - View submission status

4. **Time Tracking - Time Clocking (no screenshots)**
   - Start work session on an issue
   - Track time incrementally (same as WorkProof)
   - Select time entry activity
   - Add optional comments/description
   - Submit time clocking (JSON only)
   - No camera/screen capture

5. **Session Management**
   - Pause/resume work session
   - Manual time adjustment
   - Offline support (queue submissions)
   - Background tracking (mobile)

6. **History & Reports**
   - View today's entries
   - View weekly/monthly entries
   - Filter by project, issue, date range
   - Display total hours worked
   - Show submission status (pending, consolidated)

7. **Consolidation**
   - Manual consolidation trigger
   - View consolidation results
   - See created time entry details

---

### 4.2 Important Features (Phase 2)

**Should Have:**

1. **Advanced Reporting**
   - Charts and graphs (daily, weekly, monthly)
   - Export to CSV/PDF
   - Compare planned vs actual hours
   - Activity breakdown pie charts

2. **Notifications**
   - Reminder to log time
   - Screenshot capture notifications
   - Consolidation success/failure
   - Daily summary notifications

3. **Offline Mode**
   - Queue work proofs when offline
   - Auto-sync when online
   - Offline data viewer
   - Conflict resolution

4. **Settings & Preferences**
   - Screenshot interval configuration
   - Default project/activity
   - Notification preferences
   - Theme (dark/light mode)
   - Language selection

5. **Multiple Projects**
   - Switch between projects easily
   - Track time on multiple issues simultaneously
   - Quick project switcher

6. **Geolocation** (optional)
   - Track location with work proofs
   - Geofencing alerts
   - Location-based reports

---

### 4.3 Nice to Have Features (Future)

**Could Have:**

1. **Advanced Analytics**
   - AI-powered time predictions
   - Productivity insights
   - Team comparisons
   - Custom reports builder

2. **Integrations**
   - Calendar sync (Google, Outlook)
   - Slack/Teams notifications
   - JIRA integration
   - Git commit linking

3. **Collaboration**
   - Team activity feed
   - Chat/comments on work proofs
   - Peer reviews
   - Manager approvals

4. **Gamification**
   - Achievement badges
   - Leaderboards
   - Productivity streaks
   - Time tracking goals

---

## 5. API Integration

### 5.1 Authentication

**API Key Authentication:**

All API requests must include the API key in the header:

```http
X-Redmine-API-Key: your-api-key-here
```

**Getting API Key:**
1. User logs in to Redmine web interface
2. Goes to "My Account" page
3. Finds "API access key" section
4. Clicks "Show" to reveal key
5. Copies key to mobile app

**Alternative:** Implement login endpoint if username/password auth is needed (requires custom backend endpoint).

**Storage:**
- Mobile: Secure keychain (iOS) / Keystore (Android)
- Web: Encrypted localStorage or secure cookie
- Never log or display API key in plain text

---

### 5.2 Base URLs

**Production:**
```
https://track.gocomart.com
```

**Development:**
```
http://localhost:4001
```

**Environment Configuration:**
- Allow switching between environments
- Store in app configuration
- Dev mode for testing

---

### 5.3 Response Formats

All APIs support JSON format (recommended):

```http
GET /projects.json
POST /projects/1/work_proofs.json
```

**Response Structure (Success):**
```json
{
  "work_proof": {
    "id": 1,
    "project_id": 1,
    "issue_id": 5,
    "user_id": 2,
    "work_hours": 0.25,
    "activity_id": 9,
    "status": "pending",
    "image_url": "https://storage.googleapis.com/...",
    "created_at": "2025-10-30T10:30:00Z"
  }
}
```

**Response Structure (Error - 422):**
```json
{
  "errors": [
    "Issue can't be blank",
    "Work hours must be greater than 0"
  ]
}
```

**Response Structure (Error - 403):**
```json
{
  "error": "You are not authorized to access this resource"
}
```

---

## 6. Time Tracking Workflows

### 6.1 WorkProof Workflow (with Screenshots)

**User Story:** *As a field worker, I want to track my time with screenshot proof so my manager can verify my work.*

**Flow:**

```
1. SELECT PROJECT & ISSUE
   │
   ├─> User selects project from list
   ├─> User selects issue from filtered list
   ├─> User selects activity (Development, Testing, etc)
   │
2. START WORK SESSION
   │
   ├─> App starts timer (00:00:00)
   ├─> App captures first screenshot immediately
   ├─> Creates work_proof with work_hours: 0.0
   │   POST /projects/{id}/work_proofs.json
   │   {
   │     "issue_id": 5,
   │     "activity_id": 9,
   │     "work_hours": 0.0,
   │     "image": [file]
   │   }
   │
3. WORK IN PROGRESS (Every 10-30 minutes)
   │
   ├─> Timer continues running
   ├─> App captures screenshot automatically
   ├─> Calculates incremental hours since last screenshot
   ├─> Creates new work_proof
   │   POST /projects/{id}/work_proofs.json
   │   {
   │     "issue_id": 5,
   │     "activity_id": 9,
   │     "work_hours": 0.25,  // 15 minutes
   │     "image": [file],
   │     "description": "Working on feature X"
   │   }
   │
4. PAUSE (Optional)
   │
   ├─> User pauses work
   ├─> Timer stops
   ├─> No screenshot captured
   ├─> Resume continues from paused time
   │
5. END OF DAY
   │
   ├─> User views all work_proofs for the day
   ├─> User triggers consolidation
   │   POST /projects/{id}/work_proofs/consolidate_by_issue.json
   │   {
   │     "issue_id": 5,
   │     "date": "2025-10-30"
   │   }
   │
   ├─> Backend sums all work_hours:
   │   0.0 + 0.25 + 0.20 + 0.30 + 0.25 = 1.0 hour
   │
   ├─> Backend creates TimeEntry with 1.0 hours
   ├─> Backend marks all work_proofs as "consolidated"
   │
6. VIEW REPORT
   │
   └─> User sees TimeEntry in Redmine
       └─> Manager can see screenshots for verification
```

**Key Points:**
- **work_hours is INCREMENTAL**, not cumulative
- First work_proof has work_hours: 0.0 (baseline)
- Subsequent work_proofs contain time since last entry
- Screenshot is REQUIRED with every work_proof
- Image is uploaded as multipart/form-data
- Image is automatically compressed and stored in GCS

---

### 6.2 Time Clocking Workflow (without Screenshots)

**User Story:** *As a premium user, I want to track my time without screenshots for faster submissions and lower data usage.*

**Flow:**

```
1. SELECT PROJECT & ISSUE
   │
   ├─> Same as WorkProof
   │
2. START WORK SESSION
   │
   ├─> App starts timer (00:00:00)
   ├─> Creates first time_clocking with time_hours: 0.0
   │   POST /projects/{id}/time_clockings.json
   │   {
   │     "issue_id": 5,
   │     "activity_id": 9,
   │     "time_hours": 0.0,
   │     "description": "Started working"
   │   }
   │
3. WORK IN PROGRESS (Every 10-30 minutes OR manually)
   │
   ├─> Timer continues running
   ├─> NO screenshot captured
   ├─> User can manually log time or app auto-logs
   ├─> Creates new time_clocking
   │   POST /projects/{id}/time_clockings.json
   │   {
   │     "issue_id": 5,
   │     "activity_id": 9,
   │     "time_hours": 0.25,  // 15 minutes
   │     "description": "Implemented feature X"
   │   }
   │
4. CONSOLIDATION & REPORT
   │
   ├─> Same as WorkProof
   │   POST /projects/{id}/time_clockings/consolidate_by_issue.json
   │   {
   │     "issue_id": 5,
   │     "date": "2025-10-30"
   │   }
   │
   └─> Backend sums time_hours and creates TimeEntry
```

**Key Differences from WorkProof:**
- ✅ NO screenshot required
- ✅ Faster submission (JSON only)
- ✅ Lower bandwidth usage
- ✅ Same consolidation logic
- ✅ Separate API endpoints (`/time_clockings` instead of `/work_proofs`)
- ✅ Separate database table (`time_clockings` instead of `work_proofs`)

---

### 6.3 Calculation Examples

**Example 1: Work Session with 5 entries**

| Entry | Time | work_hours | Calculation | Screenshot |
|-------|------|-----------|-------------|-----------|
| 1 | 09:00 | 0.0 | Baseline | ✅ screenshot1.png |
| 2 | 09:15 | 0.25 | 15 min = 0.25 hr | ✅ screenshot2.png |
| 3 | 09:30 | 0.25 | 15 min = 0.25 hr | ✅ screenshot3.png |
| 4 | 10:00 | 0.50 | 30 min = 0.50 hr | ✅ screenshot4.png |
| 5 | 10:20 | 0.33 | 20 min = 0.33 hr | ✅ screenshot5.png |

**Total:** 0.0 + 0.25 + 0.25 + 0.50 + 0.33 = **1.33 hours**

**Consolidation Result:**
- Creates `TimeEntry` with `hours: 1.33`
- Activity: Development (ID: 9)
- Issue: #5
- Date: 2025-10-30
- User: Current user
- All 5 work_proofs marked as "consolidated"

---

**Example 2: Multiple Issues Same Day**

**Issue #5:**
- Entry 1: 0.0 hr (baseline)
- Entry 2: 0.50 hr
- Entry 3: 0.25 hr
- **Total: 0.75 hr**

**Issue #8:**
- Entry 1: 0.0 hr (baseline)
- Entry 2: 0.33 hr
- Entry 3: 0.42 hr
- **Total: 0.75 hr**

**Consolidation:**
```
POST /consolidate_by_issue.json
{ "issue_id": 5, "date": "2025-10-30" }
→ Creates TimeEntry #1: 0.75 hr for Issue #5

POST /consolidate_by_issue.json
{ "issue_id": 8, "date": "2025-10-30" }
→ Creates TimeEntry #2: 0.75 hr for Issue #8
```

**Result:** User has 1.5 hours logged for the day across 2 issues.

---

## 7. UI/UX Requirements

### 7.1 Design Principles

1. **Simple & Intuitive**
   - Minimal clicks to start tracking
   - Clear visual feedback
   - Easy navigation

2. **Mobile-First**
   - Touch-friendly buttons (min 44x44 dp)
   - Thumb-reachable actions
   - Swipe gestures for common actions

3. **Performance**
   - Fast app startup (<2 seconds)
   - Smooth animations (60 fps)
   - Responsive UI (no blocking operations)

4. **Accessibility**
   - Screen reader support
   - High contrast mode
   - Font scaling support
   - Color-blind friendly palette

---

### 7.2 Key Screens

**1. Login Screen**
- Logo
- API key input (with show/hide toggle)
- Alternative: Username + Password fields
- "Remember me" checkbox
- Login button
- Link to Redmine web interface for API key

**2. Projects List**
- Search bar
- List of accessible projects
- Project name, identifier, description
- Recent projects at top
- Pull to refresh

**3. Issues List**
- Filter by status (open, in progress, closed)
- Search issues
- Issue card: ID, subject, status, assignee, priority
- Tap to select issue

**4. Time Tracking Screen (Active Session)**

**WorkProof Mode:**
```
┌─────────────────────────────────────┐
│  Issue #5: Implement login feature  │
│  Project: Mobile App Development    │
├─────────────────────────────────────┤
│                                     │
│         ⏱️ 01:23:45                 │
│         [Large timer display]       │
│                                     │
│  Activity: [Development ▼]         │
│                                     │
│  Last Screenshot: 15:30 PM         │
│  Next Screenshot: 15:45 PM         │
│  📸 [Thumbnail preview]             │
│                                     │
│  [⏸️ Pause]    [⏹️ Stop]          │
│                                     │
│  Description (optional):            │
│  [Text input...]                   │
│                                     │
└─────────────────────────────────────┘
```

**Time Clocking Mode:**
```
┌─────────────────────────────────────┐
│  Issue #5: Implement login feature  │
│  Project: Mobile App Development    │
├─────────────────────────────────────┤
│                                     │
│         ⏱️ 01:23:45                 │
│         [Large timer display]       │
│                                     │
│  Activity: [Development ▼]         │
│                                     │
│  [⏸️ Pause]    [⏹️ Stop]          │
│                                     │
│  [💾 Log Time Now]                 │
│                                     │
│  Description (optional):            │
│  [Text input...]                   │
│                                     │
└─────────────────────────────────────┘
```

**5. History/Reports Screen**
- Date picker (today, yesterday, this week, custom)
- List of entries (grouped by date)
- Entry card: Issue, hours, status, screenshot thumbnail
- Total hours for period
- Filter by project, issue, activity
- Export button

**6. Entry Details Screen**
- Issue details
- Time logged
- Activity
- Description
- Screenshot (if work_proof)
- Created timestamp
- Status (pending/consolidated)
- Edit/Delete buttons (if not consolidated)

**7. Consolidation Screen**
- Select date range
- List of pending entries grouped by issue
- Total hours per issue
- "Consolidate All" button
- "Consolidate Selected" option
- Progress indicator
- Success/error messages

**8. Settings Screen**
- User info (name, email)
- API key management
- Tracking mode: WorkProof vs Time Clocking
- Screenshot interval (10, 15, 20, 30 minutes)
- Default activity
- Notifications on/off
- Theme (light/dark)
- Language
- About/Version
- Logout

---

### 7.3 Color Scheme

**Redmine Default Colors:**
- Primary: #169 (Redmine blue)
- Success: #759D3F (green)
- Warning: #F89406 (orange)
- Danger: #C61A1A (red)
- Text: #333 (dark gray)
- Background: #FFF (white)

**App-Specific:**
- Timer Active: #4CAF50 (green)
- Timer Paused: #FF9800 (orange)
- Screenshot Required: #2196F3 (blue)
- Consolidated: #9E9E9E (gray)

---

### 7.4 Typography

- Headings: Bold, 20-24 sp
- Body: Regular, 16 sp
- Captions: Regular, 14 sp
- Timer: Bold, 48 sp
- Buttons: Medium, 16 sp

---

## 8. Technical Requirements

### 8.1 Mobile App (iOS/Android)

**Minimum Versions:**
- iOS: 13.0+
- Android: 8.0 (API 26)+

**Required Permissions:**

**iOS:**
- Camera (for screenshots in WorkProof mode)
- Photo Library (save screenshots)
- Background App Refresh (background tracking)
- Notifications

**Android:**
- Camera
- Write External Storage
- Foreground Service (background tracking)
- Notifications

**Dependencies:**
- HTTP client (Alamofire/Retrofit or built-in)
- Image compression library
- Secure storage (Keychain/Keystore)
- Background task scheduler
- Local database (SQLite/Realm/Core Data)

**Performance:**
- App size: <50 MB
- Memory usage: <100 MB
- Battery efficient background tracking
- Image compression before upload (max 500 KB per image)

---

### 8.2 Web App

**Browser Support:**
- Chrome 90+
- Safari 14+
- Firefox 88+
- Edge 90+

**Responsive Design:**
- Desktop: 1920x1080 to 1280x720
- Tablet: 1024x768 to 768x1024
- Mobile: 375x667 to 414x896

**Technologies:**
- Framework: React.js 18+ (recommended)
- State: Redux Toolkit or Zustand
- Routing: React Router
- HTTP: Axios
- UI: Material-UI or Tailwind CSS
- Build: Vite or Create React App

**PWA Features:**
- Service worker for offline support
- Web app manifest
- Add to home screen
- Push notifications (optional)

---

### 8.3 Data Storage

**Local Storage:**

**Mobile:**
- SQLite or Realm for offline data
- Secure storage for API key
- Image cache for screenshots

**Web:**
- IndexedDB for offline data
- sessionStorage/localStorage for preferences
- Encrypted storage for API key

**Data to Store Locally:**
- User profile (name, email, id)
- Projects list (cache)
- Issues list (cache)
- Activities list (cache)
- Pending work proofs/clockings (offline queue)
- App settings and preferences

**Sync Strategy:**
- Background sync when online
- Conflict resolution (server wins)
- Retry failed submissions
- Clear stale cache (older than 7 days)

---

### 8.4 Image Handling

**Screenshots/Screen Capture:**

**Mobile:**
- Capture screenshot of current screen OR
- Capture photo using camera OR
- Allow user to select from gallery

**Web:**
- Screen capture API (capture visible tab/window)
- File upload option

**Image Processing:**
1. Capture image (original size)
2. Compress to PNG or JPEG
3. Resize if larger than 1920x1080
4. Target file size: <500 KB
5. Maintain aspect ratio
6. Strip EXIF metadata (privacy)

**Upload:**
- Use multipart/form-data
- Content-Type: multipart/form-data
- Include image as 'image' field
- Include other params as flat fields

**Backend Processing:**
- Server further compresses (ImageMagick)
- Uploads to GCS
- Returns public URL
- URL stored in work_proof record

---

## 9. Data Models

### 9.1 Project

```json
{
  "id": 1,
  "name": "Mobile App Development",
  "identifier": "mobile-app",
  "description": "Development of mobile applications",
  "status": 1,
  "is_public": false,
  "created_on": "2025-01-15T10:00:00Z",
  "updated_on": "2025-10-30T15:30:00Z"
}
```

**Used For:** Project selection

---

### 9.2 Issue

```json
{
  "id": 5,
  "project": {
    "id": 1,
    "name": "Mobile App Development"
  },
  "tracker": {
    "id": 2,
    "name": "Feature"
  },
  "status": {
    "id": 2,
    "name": "In Progress"
  },
  "priority": {
    "id": 2,
    "name": "Normal"
  },
  "author": {
    "id": 1,
    "name": "John Doe"
  },
  "assigned_to": {
    "id": 2,
    "name": "Jane Smith"
  },
  "subject": "Implement login feature",
  "description": "Add user authentication with API key support",
  "start_date": "2025-10-25",
  "due_date": "2025-11-05",
  "estimated_hours": 10.0,
  "created_on": "2025-10-25T09:00:00Z",
  "updated_on": "2025-10-30T16:00:00Z"
}
```

**Used For:** Issue selection, display

---

### 9.3 TimeEntryActivity

```json
{
  "id": 9,
  "name": "Development",
  "is_default": false,
  "active": true
}
```

**Common Activities:**
- 8: Design
- 9: Development
- 10: Testing
- 11: Deployment
- 12: Documentation
- 13: Support

**Used For:** Activity selection dropdown

---

### 9.4 WorkProof (with screenshot)

```json
{
  "id": 123,
  "project_id": 1,
  "issue_id": 5,
  "user_id": 2,
  "activity_id": 9,
  "work_hours": 0.25,
  "description": "Implemented login UI",
  "status": "pending",
  "image_url": "https://storage.googleapis.com/redmine-workproof-images/work_proofs/20251030/screenshot_123.png",
  "time_entry_id": null,
  "created_at": "2025-10-30T15:45:00Z",
  "updated_at": "2025-10-30T15:45:00Z",
  "user_name": "Jane Smith",
  "issue_subject": "Implement login feature",
  "project_name": "Mobile App Development"
}
```

**Status Values:**
- `pending`: Not yet consolidated
- `consolidated`: Converted to TimeEntry

**Used For:** Work proof submission, history display

---

### 9.5 TimeClocking (no screenshot)

```json
{
  "id": 456,
  "project_id": 1,
  "issue_id": 5,
  "user_id": 2,
  "activity_id": 9,
  "time_hours": 0.33,
  "description": "Code review and testing",
  "status": "pending",
  "time_entry_id": null,
  "created_at": "2025-10-30T16:00:00Z",
  "updated_at": "2025-10-30T16:00:00Z",
  "user_name": "Jane Smith",
  "issue_subject": "Implement login feature",
  "project_name": "Mobile App Development"
}
```

**Differences from WorkProof:**
- ❌ No `image_url` field
- ✅ Same structure otherwise
- ✅ Uses `/time_clockings` endpoints

---

### 9.6 TimeEntry (Consolidated Result)

```json
{
  "id": 789,
  "project": {
    "id": 1,
    "name": "Mobile App Development"
  },
  "issue": {
    "id": 5
  },
  "user": {
    "id": 2,
    "name": "Jane Smith"
  },
  "activity": {
    "id": 9,
    "name": "Development"
  },
  "hours": 1.33,
  "comments": "Login feature implementation",
  "spent_on": "2025-10-30",
  "created_on": "2025-10-30T17:00:00Z",
  "updated_on": "2025-10-30T17:00:00Z"
}
```

**Used For:** Final time entry in Redmine reports

---

## 10. API Endpoints Reference

### 10.1 Authentication

**No login endpoint** - Users must provide API key from Redmine.

**API Key Location:**
- Redmine → My Account → API access key → Show

**Usage:**
```http
GET /projects.json
X-Redmine-API-Key: abc123def456...
```

---

### 10.2 Core Redmine APIs

**List Projects:**
```http
GET /projects.json
Response: { "projects": [...], "total_count": 10, "offset": 0, "limit": 25 }
```

**List Issues (by project):**
```http
GET /issues.json?project_id=1&status_id=open&assigned_to_id=me
Response: { "issues": [...], "total_count": 5 }
```

**Get Single Issue:**
```http
GET /issues/5.json
Response: { "issue": {...} }
```

**List Time Entry Activities:**
```http
GET /enumerations/time_entry_activities.json
Response: { "time_entry_activities": [...] }
```

**List Time Entries:**
```http
GET /time_entries.json?user_id=me&from=2025-10-01&to=2025-10-31
Response: { "time_entries": [...], "total_count": 20 }
```

**Get Current User:**
```http
GET /users/current.json
Response: { "user": { "id": 2, "login": "jsmith", "firstname": "Jane", ... } }
```

---

### 10.3 WorkProof APIs (with screenshots)

**Create Work Proof:**
```http
POST /projects/1/work_proofs.json
Content-Type: multipart/form-data

Form Data:
- image: [binary file]
- issue_id: 5
- activity_id: 9
- work_hours: 0.25
- description: "Working on feature"

Response 201:
{
  "work_proof": {
    "id": 123,
    "project_id": 1,
    "issue_id": 5,
    "work_hours": 0.25,
    "image_url": "https://storage.googleapis.com/...",
    "status": "pending",
    ...
  }
}
```

**List Work Proofs (today):**
```http
GET /projects/1/work_proofs.json?date=2025-10-30&user_id=me
Response: { "work_proofs": [...], "total_count": 5 }
```

**List Work Proofs (date range):**
```http
GET /projects/1/work_proofs.json?from=2025-10-01&to=2025-10-31&user_id=me
Response: { "work_proofs": [...] }
```

**Get Single Work Proof:**
```http
GET /projects/1/work_proofs/123.json
Response: { "work_proof": {...} }
```

**Update Work Proof:**
```http
PUT /projects/1/work_proofs/123.json
Content-Type: application/json

{
  "work_proof": {
    "description": "Updated description",
    "work_hours": 0.30
  }
}

Response 200: { "work_proof": {...} }
```

**Delete Work Proof:**
```http
DELETE /projects/1/work_proofs/123.json
Response 204: No Content
```

**Consolidate by Issue:**
```http
POST /projects/1/work_proofs/consolidate_by_issue.json
Content-Type: application/json

{
  "issue_id": 5,
  "date": "2025-10-30"
}

Response 200:
{
  "message": "Work proofs consolidated successfully",
  "time_entry": {
    "id": 789,
    "hours": 1.33,
    "issue_id": 5,
    "activity_id": 9,
    "spent_on": "2025-10-30"
  },
  "work_proofs_count": 5,
  "calculation": {
    "total_hours": 1.33,
    "work_proofs": [
      { "id": 120, "work_hours": 0.0 },
      { "id": 121, "work_hours": 0.25 },
      { "id": 122, "work_hours": 0.33 },
      { "id": 123, "work_hours": 0.50 },
      { "id": 124, "work_hours": 0.25 }
    ]
  }
}
```

---

### 10.4 Time Clocking APIs (no screenshots)

**Create Time Clocking:**
```http
POST /projects/1/time_clockings.json
Content-Type: application/json

{
  "issue_id": 5,
  "activity_id": 9,
  "time_hours": 0.25,
  "description": "Working on feature"
}

Response 201:
{
  "time_clocking": {
    "id": 456,
    "project_id": 1,
    "issue_id": 5,
    "work_hours": 0.25,
    "status": "pending",
    ...
  }
}
```

**List Time Clockings:**
```http
GET /projects/1/time_clockings.json?date=2025-10-30&user_id=me
Response: { "time_clockings": [...], "total_count": 5 }
```

**Get Single Time Clocking:**
```http
GET /projects/1/time_clockings/456.json
Response: { "time_clocking": {...} }
```

**Update Time Clocking:**
```http
PUT /projects/1/time_clockings/456.json
Content-Type: application/json

{
  "time_clocking": {
    "time_hours": 0.30,
    "description": "Updated description"
  }
}

Response 200: { "time_clocking": {...} }
```

**Delete Time Clocking:**
```http
DELETE /projects/1/time_clockings/456.json
Response 204: No Content
```

**Consolidate by Issue:**
```http
POST /projects/1/time_clockings/consolidate_by_issue.json
Content-Type: application/json

{
  "issue_id": 5,
  "date": "2025-10-30"
}

Response 200:
{
  "message": "Time clockings consolidated successfully",
  "time_entry": {
    "id": 790,
    "hours": 1.08,
    "issue_id": 5,
    "activity_id": 9,
    "spent_on": "2025-10-30"
  },
  "time_clockings_count": 4,
  "calculation": {
    "total_hours": 1.08,
    "time_clockings": [
      { "id": 450, "time_hours": 0.0 },
      { "id": 451, "time_hours": 0.33 },
      { "id": 452, "time_hours": 0.42 },
      { "id": 453, "time_hours": 0.33 }
    ]
  }
}
```

---

## 11. Error Handling

### 11.1 HTTP Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 | OK | Success |
| 201 | Created | Resource created successfully |
| 204 | No Content | Success (no response body) |
| 400 | Bad Request | Invalid request format |
| 401 | Unauthorized | Invalid or missing API key |
| 403 | Forbidden | User lacks permission |
| 404 | Not Found | Resource doesn't exist |
| 422 | Unprocessable Entity | Validation error |
| 500 | Internal Server Error | Server error (retry later) |

---

### 11.2 Error Response Format

**Validation Error (422):**
```json
{
  "errors": [
    "Issue can't be blank",
    "Work hours must be greater than 0",
    "Image file is required for work proofs"
  ]
}
```

**Authorization Error (403):**
```json
{
  "error": "You are not authorized to access this resource"
}
```

**Not Found Error (404):**
```json
{
  "error": "Not found"
}
```

---

### 11.3 Error Handling Strategy

**In App:**

1. **Network Errors**
   - Show "No internet connection" message
   - Queue action for retry when online
   - Provide manual retry button

2. **Authentication Errors (401)**
   - Clear stored API key
   - Redirect to login screen
   - Show "Session expired" message

3. **Permission Errors (403)**
   - Show "You don't have permission" message
   - Provide link to request access
   - Disable unavailable features

4. **Validation Errors (422)**
   - Display error messages inline on form
   - Highlight invalid fields
   - Provide clear instructions to fix

5. **Server Errors (500)**
   - Show "Server error, please try again" message
   - Auto-retry after delay (3 attempts)
   - Log error for debugging

6. **Image Upload Errors**
   - If image too large: Compress more aggressively
   - If format unsupported: Convert to PNG/JPEG
   - If upload fails: Queue for retry
   - Show upload progress

---

## 12. Performance Requirements

### 12.1 Response Time

- API calls: < 2 seconds (on 4G)
- Screen load: < 1 second
- Image upload: < 5 seconds (500 KB image on 4G)
- Offline mode: Instant (local data)

### 12.2 Data Usage

**Per Day (WorkProof Mode):**
- Screenshots: 20-30 images × 500 KB = 10-15 MB
- API requests: ~1 MB
- Total: ~15 MB per user per day

**Per Day (Time Clocking Mode):**
- API requests: ~0.5 MB
- Total: ~0.5 MB per user per day

**Optimization:**
- Use WiFi for bulk uploads when available
- Compress images aggressively
- Cache reference data (projects, issues, activities)
- Implement delta sync (only changed data)

### 12.3 Battery Usage

- Background tracking should use < 5% battery per hour
- Use efficient location tracking (if implemented)
- Batch network requests
- Use push notifications instead of polling

---

## 13. Security Requirements

### 13.1 Data Security

1. **API Key Protection**
   - Store in secure storage only (Keychain/Keystore)
   - Never log or display in plain text
   - Clear on logout
   - Warn if transmitted over HTTP

2. **Network Security**
   - Use HTTPS only (no HTTP)
   - Certificate pinning (optional, advanced)
   - Validate SSL certificates
   - Timeout requests after 30 seconds

3. **Local Data**
   - Encrypt sensitive data at rest
   - Use SQLCipher for database encryption (optional)
   - Clear cache on logout
   - Implement auto-logout after inactivity (optional)

4. **Image Privacy**
   - Strip EXIF metadata from screenshots
   - Don't store sensitive data in images
   - Allow users to review before upload
   - Implement blur/redaction tools (future)

---

### 13.2 Permission Handling

1. **Request only needed permissions**
   - Camera: Only for WorkProof mode
   - Location: Only if geofencing enabled
   - Notifications: Optional, ask user

2. **Graceful degradation**
   - If camera denied: Allow file picker
   - If storage denied: Use in-memory cache
   - If background denied: Foreground-only mode

3. **Explain permissions**
   - Show why permission is needed
   - Provide settings link if denied
   - Allow app to function without optional permissions

---

## 14. Testing Requirements

### 14.1 Unit Testing

**Coverage:** Minimum 70%

**Test Areas:**
- API client functions
- Data models and validation
- Time calculation logic
- Image compression
- Offline queue management
- Date/time formatting

---

### 14.2 Integration Testing

**Test Scenarios:**
- Login with valid/invalid API key
- Fetch projects, issues, activities
- Create work proof with image
- Create time clocking without image
- Update/delete entries
- Consolidate entries
- Handle network errors
- Offline mode and sync

---

### 14.3 UI Testing

**Test Cases:**
- All screens load correctly
- Navigation works
- Forms validate input
- Buttons trigger correct actions
- Timer displays correctly
- Screenshot capture works
- Images display in history
- Error messages display

---

### 14.4 Manual Testing

**Test Checklist:**
- Install on multiple devices (iOS/Android)
- Test on different screen sizes
- Test with slow network (3G)
- Test offline mode
- Test with large images
- Test battery usage over 8 hours
- Test push notifications
- Test dark mode

---

## 15. Deployment

### 15.1 Mobile App

**iOS:**
- Submit to App Store
- Follow Apple guidelines
- Prepare screenshots and description
- Handle app review process

**Android:**
- Submit to Google Play Store
- Follow Google guidelines
- Prepare store listing
- Handle review process

**Beta Testing:**
- TestFlight (iOS)
- Google Play Beta (Android)
- Invite 10-20 beta testers

---

### 15.2 Web App

**Hosting:**
- Deploy to CDN (Cloudflare, Netlify, Vercel)
- Configure HTTPS
- Set up custom domain (optional)
- Enable gzip compression

**CI/CD:**
- GitHub Actions or GitLab CI
- Automated build and deploy
- Run tests before deploy
- Deploy to staging first

---

### 15.3 Environment Configuration

**Development:**
- API Base URL: http://localhost:4001
- Debug logging enabled
- Mock data for testing

**Staging:**
- API Base URL: https://staging.track.gocomart.com
- Limited logging
- Real data

**Production:**
- API Base URL: https://track.gocomart.com
- No debug logging
- Real data
- Error tracking (Sentry, Bugsnag)

---

## 16. Additional Considerations

### 16.1 Future Enhancements

1. **Smart Time Tracking**
   - Auto-detect work patterns
   - Suggest consolidation times
   - Predict work hours

2. **Team Features**
   - See team members' activity
   - Share screenshots (with permission)
   - Team leaderboards

3. **Integrations**
   - Calendar sync
   - Slack notifications
   - Email reports
   - Webhook support

4. **Advanced Reporting**
   - Custom charts
   - CSV/PDF export
   - Burndown charts
   - Velocity tracking

---

### 16.2 Known Limitations

1. **Backend:**
   - No custom login endpoint (must use API key from web)
   - No real-time updates (must pull to refresh)
   - No WebSocket support
   - Image size limit: 10 MB (configurable in Redmine)

2. **API:**
   - Pagination limited to 100 items per page
   - No bulk operations (must loop)
   - No batch uploads
   - Rate limiting may apply (check with admin)

3. **Permissions:**
   - Based on Redmine roles (cannot customize in app)
   - Must request access from project manager
   - Some operations require admin role

---

## 17. Documentation Deliverables

### 17.1 For Developers

1. **Technical Documentation**
   - Architecture overview
   - Code structure
   - API integration guide
   - Database schema (local)
   - Build and deployment guide

2. **API Documentation**
   - All available endpoints
   - Request/response examples
   - Error codes
   - Authentication flow

3. **Testing Documentation**
   - Test plan
   - Test cases
   - CI/CD setup
   - Coverage reports

---

### 17.2 For Users

1. **User Guide**
   - Getting started
   - How to get API key
   - How to track time
   - How to view reports
   - FAQ

2. **Quick Start Guide**
   - 5-minute setup
   - First work proof
   - First consolidation

3. **Video Tutorials** (optional)
   - App walkthrough
   - Common workflows
   - Troubleshooting

---

## 18. Support & Maintenance

### 18.1 Support Channels

- Email: support@example.com
- Documentation: https://track.gocomart.com/help
- Issue tracker: GitHub Issues

### 18.2 Maintenance Plan

- Bug fixes: Within 48 hours (critical), 1 week (minor)
- Feature updates: Monthly releases
- Security patches: Immediate
- OS updates: Within 1 month of new iOS/Android version

---

## 19. Success Metrics

### 19.1 Key Performance Indicators (KPIs)

1. **Adoption:**
   - 80% of users install app within 1 month
   - 60% daily active users
   - Average 5 work proofs per user per day

2. **Performance:**
   - 95% of API calls complete in < 2 seconds
   - 99.5% uptime
   - < 1% failed submissions

3. **User Satisfaction:**
   - App store rating: > 4.5 stars
   - Support tickets: < 5 per week
   - Net Promoter Score: > 50

4. **Business Impact:**
   - 50% reduction in time tracking errors
   - 30% increase in billable hours captured
   - 90% of time entries have proof screenshots

---

## 20. Contact & Resources

### 20.1 API Documentation

- **Complete API Guide:** `docs/REDMINE_COMPLETE_API_GUIDE.md`
- **Time Tracking API:** `docs/TIME_TRACKING_API.md`
- **GCS Setup:** `docs/GCS_SETUP_GUIDE.md`

### 20.2 Postman Collections

- **Redmine Complete API:** `docs/Redmine_Complete_API.postman_collection.json`
- **WorkProof API:** `docs/WorkProof_API.postman_collection.json`

### 20.3 Backend Source

- **Repository:** https://github.com/muhsinzyne/redmine
- **Production URL:** https://track.gocomart.com
- **Admin Contact:** [Your contact info]

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **WorkProof** | Time tracking entry with screenshot proof |
| **Time Clocking** | Time tracking entry without screenshot (premium users) |
| **Consolidation** | Process of summing work_proofs/time_clockings into a single TimeEntry |
| **work_hours** | Incremental hours since last entry (not cumulative) |
| **TimeEntry** | Standard Redmine time tracking record |
| **Activity** | Type of work (Development, Testing, Design, etc) |
| **API Key** | Authentication token for Redmine API |
| **GCS** | Google Cloud Storage (for screenshot storage) |
| **Redmine** | Open-source project management system |

---

## Appendix B: Sample Code Snippets

### B.1 API Call Example (JavaScript)

```javascript
// Create Work Proof with Image
const createWorkProof = async (projectId, issueId, activityId, hours, imageFile, description) => {
  const formData = new FormData();
  formData.append('image', imageFile);
  formData.append('issue_id', issueId);
  formData.append('activity_id', activityId);
  formData.append('work_hours', hours);
  formData.append('description', description);

  const response = await fetch(`${BASE_URL}/projects/${projectId}/work_proofs.json`, {
    method: 'POST',
    headers: {
      'X-Redmine-API-Key': apiKey,
    },
    body: formData,
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.errors?.join(', ') || 'Failed to create work proof');
  }

  return await response.json();
};
```

### B.2 Time Calculation Example (Dart/Flutter)

```dart
// Calculate incremental hours
double calculateIncrementalHours(DateTime lastEntryTime, DateTime currentTime) {
  final difference = currentTime.difference(lastEntryTime);
  final minutes = difference.inMinutes;
  final hours = minutes / 60.0;
  return double.parse(hours.toStringAsFixed(2)); // Round to 2 decimals
}

// Example usage:
// Last entry: 09:00
// Current: 09:15
// Result: 0.25 hours
```

### B.3 Offline Queue Example (Swift/iOS)

```swift
// Queue work proof for later submission
func queueWorkProof(_ workProof: WorkProofDTO) {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(workProof) {
        // Save to UserDefaults or local database
        var queue = getOfflineQueue()
        queue.append(data)
        UserDefaults.standard.set(queue, forKey: "workProofQueue")
    }
}

// Sync when online
func syncOfflineQueue() {
    guard isOnline() else { return }
    
    let queue = getOfflineQueue()
    for data in queue {
        let decoder = JSONDecoder()
        if let workProof = try? decoder.decode(WorkProofDTO.self, from: data) {
            submitWorkProof(workProof) { success in
                if success {
                    removeFromQueue(data)
                }
            }
        }
    }
}
```

---

## Appendix C: Sample Screens (Wireframes)

*(Include actual wireframes or mockups if available)*

---

**End of Requirements Document**

---

## Document Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-30 | AI Assistant | Initial requirements document based on project analysis |

---

**For questions or clarifications, please contact the project administrator.**

