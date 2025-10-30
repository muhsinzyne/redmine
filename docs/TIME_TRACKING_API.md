# WorkProof Time Tracking API (Simplified)

Screenshot-based time tracking with automatic consolidation to Redmine time_entries.

---

## 🎯 **How It Works**

**Simple Concept:**
- Mobile app takes screenshot every 5-10-15 minutes (configurable)
- Each screenshot = 1 work_proof record in database
- Total time = count of screenshots × interval
- Consolidate to time_entry when user stops or after 4 hours

**Example:**
```
User works on Issue #5, app configured for 10-minute intervals

10:00 AM → Screenshot #1 (work_proof created)
10:10 AM → Screenshot #2 (work_proof created)
10:20 AM → Screenshot #3 (work_proof created)
10:30 AM → Screenshot #4 (work_proof created)
10:40 AM → Screenshot #5 (work_proof created)
10:50 AM → Screenshot #6 (work_proof created)

User stops → Consolidate API called
→ Counts: 6 work_proofs
→ Calculates: 6 × 10 minutes = 60 minutes = 1.0 hour
→ Creates TimeEntry with 1.0 hour
→ Marks all 6 work_proofs as "consolidated"
```

---

## 📊 **Database Schema (Simplified)**

```sql
work_proofs:
  - id (primary key)
  - project_id (required)
  - issue_id (required)
  - user_id (required)
  - date (required)
  - image_url (required) ← Screenshot URL
  - activity_id ← For time_entry categorization
  - description ← Optional note
  - status ← 'pending' or 'consolidated'
  - consolidated ← Boolean flag
  - consolidated_at ← When consolidated
  - time_entry_id ← Links to created time_entry
  - created_at
  - updated_at
```

**That's it! Simple and clean.** ✅

---

## 🔌 **API Endpoints**

### **1. Create Work Proof (Send Screenshot)**

Called every 5-10-15 minutes by mobile app:

```http
POST /projects/1/work_proofs.json
Content-Type: multipart/form-data
X-Redmine-API-Key: YOUR_KEY

Form Data:
- image: [screenshot file]
- issue_id: 5
- activity_id: 9              ← Required for time_entry
- description: Working on feature X (optional)
```

**Response:**
```json
{
  "work_proof": {
    "id": 123,
    "issue_id": 5,
    "activity_id": 9,
    "status": "pending",
    "image_url": "https://storage.googleapis.com/...",
    "created_at": "2025-10-30T10:00:00Z"
  }
}
```

---

### **2. Consolidate to Time Entry (Stop Work)**

When user stops working on an issue:

```http
POST /projects/1/work_proofs/consolidate_by_issue.json
Content-Type: application/json
X-Redmine-API-Key: YOUR_KEY

{
  "issue_id": 5,
  "interval_minutes": 10        ← Optional (default: 10)
}
```

**Response:**
```json
{
  "time_entry": {
    "id": 42,
    "issue_id": 5,
    "user_id": 1,
    "hours": 1.0,
    "spent_on": "2025-10-30",
    "activity_id": 9,
    "comments": "Consolidated from 6 work proof(s) - 1.0h"
  },
  "work_proofs_consolidated": 6,
  "calculation": {
    "screenshots": 6,
    "interval_minutes": 10,
    "total_hours": 1.0
  }
}
```

**What it does:**
1. Finds all pending work_proofs for issue/user/date
2. Counts them (e.g., 6 screenshots)
3. Calculates hours: 6 × 10min = 60min = 1.0 hour
4. Creates TimeEntry with calculated hours
5. Links all work_proofs to time_entry
6. Marks them as consolidated

---

## 📱 **Mobile App Integration**

### **Complete Workflow**

```dart
class WorkProofTracker {
  Timer? _timer;
  int intervalMinutes = 10; // Configurable: 5, 10, or 15 minutes
  int currentIssueId;
  int currentActivityId;
  
  // Start tracking
  void startTracking(int issueId, int activityId) {
    this.currentIssueId = issueId;
    this.currentActivityId = activityId;
    
    // Send screenshot immediately
    sendScreenshot();
    
    // Send screenshot every N minutes
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (timer) => sendScreenshot()
    );
  }
  
  // Send screenshot
  Future<void> sendScreenshot() async {
    // Capture screenshot
    final screenshot = await captureScreen();
    
    // Upload to Redmine
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        screenshot.path,
        filename: screenshot.path.split('/').last,
      ),
      'issue_id': currentIssueId,
      'activity_id': currentActivityId,
      'description': 'Working on task',
    });
    
    await api.post(
      '/projects/1/work_proofs.json?key=$apiKey',
      data: formData,
    );
  }
  
  // Stop tracking and consolidate
  Future<void> stopTracking() async {
    // Stop timer
    _timer?.cancel();
    
    // Consolidate to time_entry
    final response = await api.post(
      '/projects/1/work_proofs/consolidate_by_issue.json?key=$apiKey',
      data: {
        'issue_id': currentIssueId,
        'interval_minutes': intervalMinutes,
      },
    );
    
    // Show summary
    final timeEntry = response.data['time_entry'];
    final hours = timeEntry['hours'];
    final screenshots = response.data['work_proofs_consolidated'];
    
    print('Tracked $hours hours ($screenshots screenshots)');
  }
}
```

---

## ⏱️ **Interval Configuration**

The mobile app can configure the screenshot interval:

```dart
// Options
const INTERVAL_5_MIN = 5;   // More accurate, more screenshots
const INTERVAL_10_MIN = 10; // Balanced (recommended)
const INTERVAL_15_MIN = 15; // Less frequent, fewer screenshots

// User preference
int intervalMinutes = await preferences.getInt('screenshot_interval') ?? 10;
```

**Time Calculation:**
```
5 min interval:  12 screenshots/hour
10 min interval: 6 screenshots/hour
15 min interval: 4 screenshots/hour
```

---

## 🤖 **Auto-Consolidation**

Automatically processes forgotten consolidations:

### **How It Works**

1. Cron runs every hour
2. Finds work_proofs created >4 hours ago
3. Groups by issue/user/date
4. Consolidates each group to time_entry
5. Marks as consolidated

### **Setup Cron Job**

```bash
# Edit crontab
crontab -e

# Add (runs every hour at :00)
0 * * * * cd /var/www/redmine && bundle exec rake work_proof:auto_consolidate RAILS_ENV=production >> log/auto_consolidate.log 2>&1
```

### **Manual Run (Testing)**

```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
bundle exec rake work_proof:auto_consolidate

# Output:
# Auto-consolidating 6 work proofs for issue #5, user #1, date 2025-10-30
# Auto-consolidated 6 work proofs into 1 time entries
```

### **Check What Needs Consolidation**

```bash
bundle exec rake work_proof:check_pending

# Output:
# Found 6 work proofs needing consolidation:
#   - Issue #5: John Doe (6 screenshots, ~1.0h)
```

---

## 📊 **Example Scenarios**

### **Scenario 1: Normal Workflow**

```
User starts work on Issue #10 at 9:00 AM
App configured: 10-minute intervals

9:00 → Screenshot (work_proof #1)
9:10 → Screenshot (work_proof #2)
9:20 → Screenshot (work_proof #3)
9:30 → Screenshot (work_proof #4)
9:40 → Screenshot (work_proof #5)
9:50 → Screenshot (work_proof #6)
10:00 → User clicks "Stop Work"

App calls: POST /work_proofs/consolidate_by_issue
  - issue_id: 10
  - interval_minutes: 10

Result:
  - 6 work_proofs found
  - 6 × 10min = 60min = 1.0 hour
  - TimeEntry created: 1.0 hour on Issue #10
  - All work_proofs marked consolidated
```

---

### **Scenario 2: User Forgets to Stop**

```
User starts work at 9:00 AM
App sends screenshots every 10 minutes
User gets distracted, forgets to stop...

9:00 → Screenshot
9:10 → Screenshot
...
1:00 PM → 24 screenshots sent (4 hours)
1:00 PM → Cron job runs auto-consolidation

Auto-consolidation:
  - Finds 24 work_proofs older than 4 hours
  - Groups by issue/user/date
  - Calculates: 24 × 10min = 240min = 4.0 hours
  - Creates TimeEntry automatically
  - Marks all as consolidated

User benefit: Time tracked even if they forgot to stop!
```

---

### **Scenario 3: Multiple Issues in One Day**

```
9:00-10:00 → Work on Issue #5 (6 screenshots)
10:00 → Stop, consolidate → 1.0 hour time_entry

11:00-12:30 → Work on Issue #8 (9 screenshots)
12:30 → Stop, consolidate → 1.5 hours time_entry

2:00-3:00 → Work on Issue #5 again (6 screenshots)
3:00 → Stop, consolidate → 1.0 hour time_entry

Result:
- 3 separate time_entries
- Total tracked: 3.5 hours
- All properly categorized by issue
```

---

## 🔌 **API Reference**

### **Create Work Proof**

```
POST /projects/:project_id/work_proofs.json
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| image | File | ✅ | Screenshot image |
| issue_id | Integer | ✅ | Issue being worked on |
| activity_id | Integer | ✅ | Time entry activity (Development, Design, etc.) |
| description | String | ❌ | Optional note |

**Example:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  -F "image=@screenshot.png" \
  -F "issue_id=5" \
  -F "activity_id=9" \
  "http://localhost:3000/projects/1/work_proofs.json"
```

---

### **Consolidate by Issue**

```
POST /projects/:project_id/work_proofs/consolidate_by_issue.json
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| issue_id | Integer | ✅ | Issue to consolidate |
| user_id | Integer | ❌ | Defaults to current user |
| date | Date | ❌ | Defaults to today (YYYY-MM-DD) |
| interval_minutes | Integer | ❌ | Screenshot interval (default: 10) |

**Example:**
```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "issue_id": 5,
    "interval_minutes": 10
  }' \
  "http://localhost:3000/projects/1/work_proofs/consolidate_by_issue.json"
```

**Response:**
```json
{
  "time_entry": {
    "id": 42,
    "hours": 1.5,
    "issue_id": 5,
    "activity_id": 9,
    "comments": "Consolidated from 9 work proof(s) - 1.5h"
  },
  "work_proofs_consolidated": 9,
  "calculation": {
    "screenshots": 9,
    "interval_minutes": 10,
    "total_hours": 1.5
  }
}
```

---

## 🧮 **Time Calculation**

**Formula:**
```
total_hours = (screenshot_count × interval_minutes) / 60
```

**Examples:**

| Screenshots | Interval | Calculation | Total Hours |
|-------------|----------|-------------|-------------|
| 6 | 10 min | 6 × 10 / 60 | 1.0 h |
| 12 | 10 min | 12 × 10 / 60 | 2.0 h |
| 9 | 10 min | 9 × 10 / 60 | 1.5 h |
| 12 | 5 min | 12 × 5 / 60 | 1.0 h |
| 16 | 15 min | 16 × 15 / 60 | 4.0 h |

---

## 🤖 **Auto-Consolidation**

### **Setup**

```bash
# Add to crontab (runs every hour)
crontab -e

# Add this line:
0 * * * * cd /var/www/redmine && bundle exec rake work_proof:auto_consolidate RAILS_ENV=production >> log/auto_consolidate.log 2>&1
```

### **What It Does**

Every hour:
1. Find work_proofs created >4 hours ago
2. Filter: status = 'pending', not consolidated
3. Group by issue/user/date
4. For each group:
   - Count screenshots
   - Calculate hours
   - Create time_entry
   - Mark all as consolidated

**Example Log:**
```
Auto-consolidating 18 work proofs for issue #5, user #1, date 2025-10-30
Auto-consolidating 12 work proofs for issue #8, user #2, date 2025-10-30
Auto-consolidated 30 work proofs into 2 time entries
```

---

## 📱 **Mobile App Complete Example**

```dart
class WorkProofService {
  Timer? _trackingTimer;
  int _currentIssueId;
  int _currentActivityId;
  int _intervalMinutes = 10; // Configurable
  
  // Start tracking
  Future<void> startTracking({
    required int issueId,
    required int activityId,
    int intervalMinutes = 10,
  }) async {
    _currentIssueId = issueId;
    _currentActivityId = activityId;
    _intervalMinutes = intervalMinutes;
    
    // Send first screenshot immediately
    await _sendScreenshot();
    
    // Send screenshot every N minutes
    _trackingTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (timer) => _sendScreenshot(),
    );
  }
  
  // Send screenshot to Redmine
  Future<void> _sendScreenshot() async {
    try {
      // Capture screenshot
      final screenshot = await ScreenshotService.capture();
      
      // Prepare form data
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          screenshot.path,
          filename: 'screenshot_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
        'issue_id': _currentIssueId,
        'activity_id': _currentActivityId,
        'description': 'Work in progress',
      });
      
      // Send to API
      final response = await api.post(
        '/projects/1/work_proofs.json?key=$apiKey',
        data: formData,
      );
      
      print('Screenshot sent: ${response.data['work_proof']['id']}');
      
    } catch (e) {
      print('Failed to send screenshot: $e');
      // Queue for retry
    }
  }
  
  // Stop tracking and consolidate
  Future<Map<String, dynamic>> stopTracking() async {
    // Stop timer
    _trackingTimer?.cancel();
    _trackingTimer = null;
    
    // Consolidate to time_entry
    final response = await api.post(
      '/projects/1/work_proofs/consolidate_by_issue.json?key=$apiKey',
      data: {
        'issue_id': _currentIssueId,
        'interval_minutes': _intervalMinutes,
      },
    );
    
    final timeEntry = response.data['time_entry'];
    final screenshots = response.data['work_proofs_consolidated'];
    final hours = timeEntry['hours'];
    
    return {
      'hours': hours,
      'screenshots': screenshots,
      'time_entry_id': timeEntry['id'],
    };
  }
}

// Usage:
final tracker = WorkProofService();

// Start
await tracker.startTracking(
  issueId: 5,
  activityId: 9,
  intervalMinutes: 10,
);

// ... user works ...

// Stop
final result = await tracker.stopTracking();
print('Tracked ${result['hours']} hours (${result['screenshots']} screenshots)');
```

---

## 🎛️ **Configuration Options**

### **Interval Settings**

| Interval | Screenshots/Hour | Use Case |
|----------|------------------|----------|
| **5 min** | 12 | Detailed tracking, frequent proof |
| **10 min** | 6 | Balanced (recommended) |
| **15 min** | 4 | Less storage, still accurate |

### **Configurable in App**

```dart
// Let user choose
enum Interval { five, ten, fifteen }

final intervals = {
  Interval.five: 5,
  Interval.ten: 10,
  Interval.fifteen: 15,
};

// Save preference
await prefs.setInt('interval', intervals[selectedInterval]!);
```

---

## 🧪 **Testing**

### **Test Complete Flow**

```bash
# 1. Create some work proofs (simulating 30 minutes of work)
curl -X POST -H "X-Redmine-API-Key: KEY" \
  -F "image=@test1.jpg" -F "issue_id=1" -F "activity_id=9" \
  "http://localhost:3000/projects/1/work_proofs.json"

curl -X POST -H "X-Redmine-API-Key: KEY" \
  -F "image=@test2.jpg" -F "issue_id=1" -F "activity_id=9" \
  "http://localhost:3000/projects/1/work_proofs.json"

curl -X POST -H "X-Redmine-API-Key: KEY" \
  -F "image=@test3.jpg" -F "issue_id=1" -F "activity_id=9" \
  "http://localhost:3000/projects/1/work_proofs.json"

# 3 screenshots = 30 minutes (with 10-min interval)

# 2. Consolidate
curl -X POST \
  -H "X-Redmine-API-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{"issue_id": 1, "interval_minutes": 10}' \
  "http://localhost:3000/projects/1/work_proofs/consolidate_by_issue.json"

# Response: 
# {
#   "time_entry": {"hours": 0.5},  ← 3 × 10min = 30min = 0.5h
#   "work_proofs_consolidated": 3
# }

# 3. Verify time_entry created
curl -H "X-Redmine-API-Key: KEY" \
  "http://localhost:3000/time_entries.json?issue_id=1"
```

---

## 📈 **Benefits**

✅ **Simple** - Just count screenshots
✅ **Accurate** - Each screenshot = proof of work
✅ **Automatic** - Auto-consolidates after 4 hours
✅ **Flexible** - Configurable intervals (5/10/15 min)
✅ **Safe** - Can't lose time if user forgets
✅ **Visual proof** - Every interval has screenshot
✅ **Integrates** - Creates Redmine time_entries

---

## 🎯 **Summary**

**Data Model:**
- WorkProof = Screenshot proof (one per interval)
- Status: pending → consolidated
- No complex clock in/out

**Time Calculation:**
- Count screenshots for issue/user/date
- Multiply by interval
- Divide by 60 for hours

**Consolidation:**
- Manual: POST /consolidate_by_issue
- Automatic: Cron every hour (>4h old entries)

**Mobile App:**
- Send screenshot every N minutes
- Call consolidate when stopping
- Configurable interval

**Result:**
- Simple, clean, works perfectly! ✅
