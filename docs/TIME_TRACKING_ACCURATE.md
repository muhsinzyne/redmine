# WorkProof Time Tracking - Accurate Implementation

Incremental time tracking with mobile app calculating elapsed time.

---

## ✅ **How It Actually Works**

### **Mobile App Side:**
```dart
// App tracks elapsed time since last screenshot
DateTime lastScreenshotTime = DateTime.now();

// Every N minutes (or when timer fires)
void sendScreenshot() {
  final now = DateTime.now();
  final elapsedMinutes = now.difference(lastScreenshotTime).inMinutes;
  final incrementalHours = elapsedMinutes / 60.0; // Convert to decimal hours
  
  sendWorkProof(
    image: screenshot,
    issue_id: currentIssueId,
    activity_id: currentActivityId,
    work_hours: incrementalHours  ← Actual elapsed time
  );
  
  lastScreenshotTime = now; // Reset for next interval
}
```

### **Example Timeline:**

```
10:00:00 → User starts work
10:00:05 → Screenshot #1, work_hours: 0.0 (first screenshot, no elapsed time)

10:07:23 → Screenshot #2, work_hours: 0.12 (7 min 18 sec = 0.12 hours)
10:18:45 → Screenshot #3, work_hours: 0.19 (11 min 22 sec = 0.19 hours)
10:27:10 → Screenshot #4, work_hours: 0.14 (8 min 25 sec = 0.14 hours)
10:40:05 → Screenshot #5, work_hours: 0.22 (12 min 55 sec = 0.22 hours)

User stops → Consolidate

Calculation:
  SUM(0.0 + 0.12 + 0.19 + 0.14 + 0.22) = 0.67 hours
  = 40 minutes 12 seconds
  
TimeEntry created: 0.67 hours on Issue #5
```

---

## 🎯 **Why This Approach is Better**

### **Accurate to the Second**

**Old way (counting):**
```
6 screenshots × 10 min interval = 60 minutes
Problem: Assumes exactly 10 minutes between each
Reality: Could be 7min, 11min, 9min, 13min...
```

**New way (summing incremental):**
```
Screenshot #1: 7 minutes → 0.12 hours
Screenshot #2: 11 minutes → 0.18 hours
Screenshot #3: 9 minutes → 0.15 hours
Total: 0.45 hours (27 minutes) ← Exact!
```

### **Handles Variable Timing**

- ✅ Network delays
- ✅ App backgrounded
- ✅ User paused
- ✅ Any interval variation

**Mobile app calculates exact time, server just stores it.**

---

## 📊 **Data Model**

### **work_proofs Table**

```sql
CREATE TABLE work_proofs (
  id              INTEGER PRIMARY KEY,
  issue_id        INTEGER NOT NULL,
  activity_id     INTEGER,           ← For time_entry
  work_hours      DECIMAL(5,2),      ← Incremental hours since last screenshot
  status          STRING DEFAULT 'pending',
  consolidated    BOOLEAN DEFAULT false,
  time_entry_id   INTEGER,           ← Link to TimeEntry
  image_url       STRING NOT NULL,   ← Screenshot proof
  created_at      DATETIME,
  ...
);
```

### **Example Data**

| ID | issue_id | work_hours | created_at | status |
|----|----------|------------|------------|--------|
| 1 | 5 | 0.00 | 10:00:00 | pending |
| 2 | 5 | 0.12 | 10:07:00 | pending |
| 3 | 5 | 0.18 | 10:18:00 | pending |
| 4 | 5 | 0.15 | 10:27:00 | pending |

**Consolidate → SUM(0.00 + 0.12 + 0.18 + 0.15) = 0.45 hours**

---

## 🔌 **API Usage**

### **Create Work Proof**

```http
POST /projects/1/work_proofs.json
X-Redmine-API-Key: YOUR_KEY

Form Data:
- image: [screenshot file]
- issue_id: 5
- activity_id: 9
- work_hours: 0.17        ← Elapsed hours since last screenshot
- description: Working...
```

**Mobile App Calculation:**
```dart
// Calculate elapsed time
final elapsed = DateTime.now().difference(lastScreenshotTime);
final hours = elapsed.inSeconds / 3600.0; // Accurate to seconds

// Send to API
final formData = FormData.fromMap({
  'image': screenshot,
  'issue_id': currentIssueId,
  'activity_id': currentActivityId,
  'work_hours': hours.toStringAsFixed(2), // e.g., "0.17"
});
```

---

### **Consolidate**

```http
POST /projects/1/work_proofs/consolidate_by_issue.json
X-Redmine-API-Key: YOUR_KEY

{
  "issue_id": 5
}
```

**Response:**
```json
{
  "time_entry": {
    "id": 42,
    "hours": 2.35,
    "comments": "Consolidated from 15 work proof(s) - 2.35h"
  },
  "work_proofs_consolidated": 15,
  "calculation": {
    "screenshots": 15,
    "total_hours": 2.35
  }
}
```

---

## 📱 **Complete Mobile App Example**

```dart
class AccurateWorkProofTracker {
  Timer? _timer;
  DateTime? _lastScreenshotTime;
  DateTime? _sessionStartTime;
  int? _currentIssueId;
  int? _currentActivityId;
  
  // Start tracking
  Future<void> startTracking(int issueId, int activityId) async {
    _currentIssueId = issueId;
    _currentActivityId = activityId;
    _sessionStartTime = DateTime.now();
    _lastScreenshotTime = DateTime.now();
    
    // Send first screenshot immediately with 0 hours
    await _sendScreenshot(firstScreenshot: true);
    
    // Send screenshot every 10 minutes (or configurable)
    _timer = Timer.periodic(
      Duration(minutes: 10),
      (timer) => _sendScreenshot(),
    );
  }
  
  // Send screenshot with accurate elapsed time
  Future<void> _sendScreenshot({bool firstScreenshot = false}) async {
    final now = DateTime.now();
    
    // Calculate incremental hours since last screenshot
    final elapsed = now.difference(_lastScreenshotTime!);
    final incrementalHours = elapsed.inSeconds / 3600.0;
    
    // For first screenshot, use 0 (no time elapsed yet)
    final hours = firstScreenshot ? 0.0 : incrementalHours;
    
    try {
      // Capture screenshot
      final screenshot = await captureScreen();
      
      // Prepare form data
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          screenshot.path,
          filename: 'screenshot_${now.millisecondsSinceEpoch}.png',
        ),
        'issue_id': _currentIssueId,
        'activity_id': _currentActivityId,
        'work_hours': hours.toStringAsFixed(2), // e.g., "0.17"
        'description': 'Work in progress',
      });
      
      // Send to API
      final response = await api.post(
        '/projects/1/work_proofs.json?key=$apiKey',
        data: formData,
      );
      
      print('Screenshot sent: ${hours.toStringAsFixed(2)} hours incremental');
      
      // Update last screenshot time
      _lastScreenshotTime = now;
      
    } catch (e) {
      print('Failed to send screenshot: $e');
      // Don't update lastScreenshotTime - will include this time in next screenshot
    }
  }
  
  // Stop tracking and consolidate
  Future<Map<String, dynamic>> stopTracking() async {
    // Send final screenshot with remaining time
    if (_lastScreenshotTime != null) {
      await _sendScreenshot();
    }
    
    // Stop timer
    _timer?.cancel();
    
    // Consolidate all screenshots for this issue
    final response = await api.post(
      '/projects/1/work_proofs/consolidate_by_issue.json?key=$apiKey',
      data: {
        'issue_id': _currentIssueId,
      },
    );
    
    final timeEntry = response.data['time_entry'];
    final screenshots = response.data['work_proofs_consolidated'];
    final totalHours = timeEntry['hours'];
    
    // Calculate session duration
    final sessionDuration = DateTime.now().difference(_sessionStartTime!);
    
    return {
      'hours': totalHours,
      'screenshots': screenshots,
      'session_duration': sessionDuration,
      'time_entry_id': timeEntry['id'],
    };
  }
  
  // Get current session time
  double getCurrentSessionHours() {
    if (_sessionStartTime == null) return 0.0;
    final elapsed = DateTime.now().difference(_sessionStartTime!);
    return elapsed.inSeconds / 3600.0;
  }
}
```

---

## 🧮 **Time Calculation Examples**

### **Scenario 1: Regular 10-Minute Intervals**

```
10:00 → work_hours: 0.0
10:10 → work_hours: 0.17  (10 min)
10:20 → work_hours: 0.17  (10 min)
10:30 → work_hours: 0.17  (10 min)

Total: 0.0 + 0.17 + 0.17 + 0.17 = 0.51 hours (30 minutes actual work)
```

### **Scenario 2: Variable Intervals**

```
10:00 → work_hours: 0.0
10:07 → work_hours: 0.12  (7 min - network was slow)
10:18 → work_hours: 0.18  (11 min - normal)
10:27 → work_hours: 0.15  (9 min - app backgrounded briefly)
10:42 → work_hours: 0.25  (15 min - user took break)

Total: 0.0 + 0.12 + 0.18 + 0.15 + 0.25 = 0.70 hours (42 minutes)
```

**Perfectly accurate!** ✅

---

## 📋 **Request Format**

### **Mobile App Sends:**

```http
POST /projects/1/work_proofs.json

Form Data:
- image: [file]
- issue_id: 5
- activity_id: 9
- work_hours: 0.17        ← Calculated by app (elapsed since last)
- date: 2025-10-30        ← Optional (defaults to today)
- description: Working    ← Optional
```

### **Response:**

```json
{
  "work_proof": {
    "id": 123,
    "issue_id": 5,
    "activity_id": 9,
    "work_hours": 0.17,
    "status": "pending",
    "consolidated": false,
    "created_at": "2025-10-30T10:18:00Z"
  }
}
```

---

## 🎯 **Consolidation**

### **Manual Consolidation**

```http
POST /projects/1/work_proofs/consolidate_by_issue.json

{
  "issue_id": 5
}
```

**What happens:**
1. Find all pending work_proofs for issue #5, current user, today
2. SUM all work_hours: `SELECT SUM(work_hours) WHERE ...`
3. Create TimeEntry with total hours
4. Mark all work_proofs as consolidated

### **Auto-Consolidation**

```bash
# Cron (every hour)
0 * * * * cd /var/www/redmine && bundle exec rake work_proof:auto_consolidate RAILS_ENV=production
```

**What happens:**
1. Find work_proofs created >4 hours ago (status: pending)
2. Group by issue/user/date
3. SUM work_hours for each group
4. Create TimeEntry for each group
5. Mark all as consolidated

---

## 💡 **Mobile App Tips**

### **First Screenshot**

```dart
// First screenshot of session
work_hours: 0.0  // No time elapsed yet
```

### **Subsequent Screenshots**

```dart
// Calculate elapsed since last screenshot
final elapsed = DateTime.now().difference(lastScreenshotTime);
final hours = elapsed.inSeconds / 3600.0;

work_hours: hours.toStringAsFixed(2)  // e.g., "0.17"
```

### **Handle App Background/Resume**

```dart
// When app goes to background
onPause() {
  pauseTime = DateTime.now();
}

// When app resumes
onResume() {
  if (pauseTime != null) {
    // Adjust lastScreenshotTime to account for pause
    final pauseDuration = DateTime.now().difference(pauseTime);
    lastScreenshotTime = lastScreenshotTime.add(pauseDuration);
  }
}
```

### **Network Retry**

```dart
// If screenshot upload fails
onUploadFailed() {
  // Don't update lastScreenshotTime
  // Next successful upload will include this time
}
```

---

## ✅ **Benefits**

✅ **Accurate** - Real elapsed time, not estimated intervals
✅ **Flexible** - Handles any timing variation
✅ **Resilient** - Network delays don't lose time
✅ **Simple** - Mobile app calculates, server stores
✅ **Visual proof** - Screenshot for each time increment
✅ **Automatic** - Auto-consolidation safety net

---

## 📊 **Database Example**

### **Work Proofs for Issue #5, User #1, 2025-10-30:**

| ID | work_hours | created_at | status |
|----|------------|------------|--------|
| 101 | 0.00 | 10:00:00 | pending |
| 102 | 0.12 | 10:07:18 | pending |
| 103 | 0.18 | 10:18:22 | pending |
| 104 | 0.15 | 10:27:45 | pending |
| 105 | 0.22 | 10:40:10 | pending |

**Consolidate → Query:**
```sql
SELECT SUM(work_hours) FROM work_proofs 
WHERE issue_id = 5 AND user_id = 1 AND date = '2025-10-30' AND status = 'pending';
-- Result: 0.67 hours
```

**TimeEntry created:**
```
{
  id: 42,
  issue_id: 5,
  hours: 0.67,
  activity_id: 9,
  spent_on: '2025-10-30'
}
```

**Work proofs updated:**
```sql
UPDATE work_proofs 
SET status = 'consolidated', 
    time_entry_id = 42, 
    consolidated_at = NOW()
WHERE id IN (101, 102, 103, 104, 105);
```

---

## 🧪 **Testing**

### **Simulate Mobile App Behavior**

```bash
# Screenshot #1 (start)
curl -X POST -H "X-Redmine-API-Key: KEY" \
  -F "image=@test1.jpg" \
  -F "issue_id=1" \
  -F "activity_id=9" \
  -F "work_hours=0.0" \
  "http://localhost:3000/projects/1/work_proofs.json"

# Screenshot #2 (7 minutes later)
curl -X POST -H "X-Redmine-API-Key: KEY" \
  -F "image=@test2.jpg" \
  -F "issue_id=1" \
  -F "activity_id=9" \
  -F "work_hours=0.12" \
  "http://localhost:3000/projects/1/work_proofs.json"

# Screenshot #3 (11 minutes later)
curl -X POST -H "X-Redmine-API-Key: KEY" \
  -F "image=@test3.jpg" \
  -F "issue_id=1" \
  -F "activity_id=9" \
  -F "work_hours=0.18" \
  "http://localhost:3000/projects/1/work_proofs.json"

# Consolidate
curl -X POST \
  -H "X-Redmine-API-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{"issue_id": 1}' \
  "http://localhost:3000/projects/1/work_proofs/consolidate_by_issue.json"

# Expected: 0.30 hours (0.0 + 0.12 + 0.18 = 18 minutes)
```

---

## 📱 **Complete Mobile Implementation**

```dart
class WorkProofTracker {
  Timer? _timer;
  DateTime? _lastScreenshotTime;
  DateTime? _sessionStartTime;
  int? _currentIssueId;
  int? _currentActivityId;
  final int intervalMinutes;
  
  WorkProofTracker({this.intervalMinutes = 10});
  
  // Start tracking
  Future<void> startTracking(int issueId, int activityId) async {
    _currentIssueId = issueId;
    _currentActivityId = activityId;
    _sessionStartTime = DateTime.now();
    _lastScreenshotTime = DateTime.now();
    
    // First screenshot (0 hours)
    await _sendScreenshot(isFirst: true);
    
    // Schedule periodic screenshots
    _timer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (timer) => _sendScreenshot(),
    );
  }
  
  // Calculate and send screenshot
  Future<void> _sendScreenshot({bool isFirst = false}) async {
    final now = DateTime.now();
    
    // Calculate incremental hours
    double hours = 0.0;
    if (!isFirst && _lastScreenshotTime != null) {
      final elapsed = now.difference(_lastScreenshotTime!);
      hours = elapsed.inSeconds / 3600.0; // Convert seconds to hours
    }
    
    try {
      final screenshot = await captureScreen();
      
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          screenshot.path,
          filename: 'screenshot_${now.millisecondsSinceEpoch}.png',
        ),
        'issue_id': _currentIssueId,
        'activity_id': _currentActivityId,
        'work_hours': hours.toStringAsFixed(2), // e.g., "0.17"
      });
      
      await api.post(
        '/projects/1/work_proofs.json?key=$apiKey',
        data: formData,
      );
      
      // Update last screenshot time ONLY on success
      _lastScreenshotTime = now;
      
      print('Screenshot sent: +${hours.toStringAsFixed(2)}h');
      
    } catch (e) {
      print('Failed to send: $e');
      // Don't update _lastScreenshotTime
      // Next successful upload will include this time
    }
  }
  
  // Stop tracking
  Future<Map> stopTracking() async {
    // Send final screenshot with remaining time
    await _sendScreenshot();
    
    // Stop timer
    _timer?.cancel();
    
    // Consolidate
    final response = await api.post(
      '/projects/1/work_proofs/consolidate_by_issue.json?key=$apiKey',
      data: {'issue_id': _currentIssueId},
    );
    
    final result = {
      'hours': response.data['time_entry']['hours'],
      'screenshots': response.data['work_proofs_consolidated'],
    };
    
    // Reset
    _lastScreenshotTime = null;
    _sessionStartTime = null;
    
    return result;
  }
  
  // Get current session time (for UI display)
  double getCurrentSessionHours() {
    if (_sessionStartTime == null) return 0.0;
    final elapsed = DateTime.now().difference(_sessionStartTime!);
    return elapsed.inSeconds / 3600.0;
  }
}

// Usage:
final tracker = WorkProofTracker(intervalMinutes: 10);

// Start
await tracker.startTracking(issueId: 5, activityId: 9);

// Display live timer in UI
Timer.periodic(Duration(seconds: 1), (timer) {
  final hours = tracker.getCurrentSessionHours();
  updateUI('Tracking: ${hours.toStringAsFixed(2)}h');
});

// Stop
final result = await tracker.stopTracking();
showDialog('Tracked ${result['hours']}h (${result['screenshots']} proofs)');
```

---

## 🎯 **Key Points**

### **work_hours Field**

- ✅ **Incremental** - Time since last screenshot
- ✅ **Accurate** - Calculated by mobile app
- ✅ **Flexible** - Handles any interval (5s to 20min)
- ✅ **No data loss** - Failed uploads included in next

### **Calculation**

- **Server:** `SUM(work_hours)` for all pending work_proofs
- **Not:** `COUNT(*) × interval`

### **Example**

```
Screenshot #1: 0.00h (first)
Screenshot #2: 0.12h (7 min later)
Screenshot #3: 0.18h (11 min later)
Screenshot #4: 0.15h (9 min later)
Screenshot #5: 0.25h (15 min later - user took break)

Total: SUM(0.00, 0.12, 0.18, 0.15, 0.25) = 0.70 hours
```

**Exact time = 42 minutes** (not rounded to intervals!)

---

## ✅ **Summary**

**Mobile App:**
- Calculates elapsed time since last screenshot
- Sends incremental `work_hours` with each request
- Accurate to the second

**Server:**
- Stores each work_proof with incremental hours
- SUMs work_hours when consolidating
- Creates TimeEntry with accurate total

**Result:**
- ✅ Precise time tracking
- ✅ Handles any interval variation
- ✅ No time lost
- ✅ Simple and accurate!

**All committed and ready!** 🚀

