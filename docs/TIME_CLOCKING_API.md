# Time Clocking API (Premium - No Screenshots)

For premium users who want to track time without screenshot requirements.

---

## 🎯 **Overview**

**Two Time Tracking Options:**

### **1. Work Proofs** (Standard Users)
- ✅ Requires screenshot every interval
- ✅ Visual proof of work
- ✅ More accountability
- ✅ Table: `work_proofs`

### **2. Time Clockings** (Premium Users)
- ✅ **No screenshot required**
- ✅ Just time tracking
- ✅ Trusted users
- ✅ Table: `time_clockings`

**Same workflow, different data!**

---

## 📊 **Database Schema**

```sql
time_clockings:
  - id
  - project_id (required)
  - issue_id (required)
  - user_id (required)
  - date (required)
  - activity_id (for time_entry)
  - time_hours (decimal 5,2) - Incremental hours
  - description (optional note)
  - status ('pending' or 'consolidated')
  - consolidated (boolean, default: false)
  - consolidated_at (timestamp)
  - time_entry_id (link to TimeEntry)
  - created_at
  - updated_at
```

**Identical to work_proofs, just without image_url!**

---

## 🔌 **API Endpoints**

### **1. Create Time Clocking**

```http
POST /projects/1/time_clockings.json
Content-Type: application/json
X-Redmine-API-Key: YOUR_KEY

{
  "issue_id": 5,
  "activity_id": 9,
  "time_hours": 0.17,
  "description": "Working on feature"
}
```

**Response:**
```json
{
  "time_clocking": {
    "id": 1,
    "issue_id": 5,
    "activity_id": 9,
    "time_hours": 0.17,
    "status": "pending",
    "date": "2025-10-30",
    "created_at": "2025-10-30T10:17:00Z"
  }
}
```

---

### **2. Consolidate by Issue**

```http
POST /projects/1/time_clockings/consolidate_by_issue.json
X-Redmine-API-Key: YOUR_KEY

{
  "issue_id": 5,
  "date": "2025-10-30"
}
```

**Response:**
```json
{
  "time_entry": {
    "id": 42,
    "hours": 2.35,
    "issue_id": 5,
    "activity_id": 9,
    "comments": "Consolidated from 12 time clocking(s) - 2.35h"
  },
  "time_clockings_consolidated": 12,
  "calculation": {
    "entries": 12,
    "total_hours": 2.35
  }
}
```

---

## 📱 **Mobile App Integration**

### **For Premium Users (No Screenshots)**

```dart
class TimeClockingTracker {
  Timer? _timer;
  DateTime? _lastClockingTime;
  int? _currentIssueId;
  int? _currentActivityId;
  
  // Start tracking (no screenshots)
  Future<void> startTracking(int issueId, int activityId) async {
    _currentIssueId = issueId;
    _currentActivityId = activityId;
    _lastClockingTime = DateTime.now();
    
    // Send first clocking (0 hours)
    await _sendClocking(hours: 0.0);
    
    // Send clocking every 10 minutes (no screenshot)
    _timer = Timer.periodic(
      Duration(minutes: 10),
      (timer) => _sendClocking(),
    );
  }
  
  // Send time clocking (NO screenshot)
  Future<void> _sendClocking({double? hours}) async {
    final now = DateTime.now();
    
    // Calculate incremental hours
    final elapsed = now.difference(_lastClockingTime!);
    final incrementalHours = hours ?? (elapsed.inSeconds / 3600.0);
    
    try {
      // NO image upload - just JSON
      final response = await api.post(
        '/projects/1/time_clockings.json?key=$apiKey',
        data: {
          'issue_id': _currentIssueId,
          'activity_id': _currentActivityId,
          'time_hours': incrementalHours.toStringAsFixed(2),
        },
      );
      
      _lastClockingTime = now;
      print('Clocking sent: +${incrementalHours.toStringAsFixed(2)}h');
      
    } catch (e) {
      print('Failed: $e');
    }
  }
  
  // Stop and consolidate
  Future<Map> stopTracking() async {
    // Send final clocking
    await _sendClocking();
    
    // Stop timer
    _timer?.cancel();
    
    // Consolidate
    final response = await api.post(
      '/projects/1/time_clockings/consolidate_by_issue.json?key=$apiKey',
      data: {'issue_id': _currentIssueId},
    );
    
    return {
      'hours': response.data['time_entry']['hours'],
      'entries': response.data['time_clockings_consolidated'],
    };
  }
}
```

---

## 🆚 **Comparison**

| Feature | Work Proofs | Time Clockings |
|---------|-------------|----------------|
| **Screenshot** | ✅ Required | ❌ Not required |
| **Visual Proof** | ✅ Yes | ❌ No |
| **Image Upload** | ✅ GCS/Local | ❌ None |
| **Bandwidth** | Higher | Lower |
| **Storage** | Higher | Minimal |
| **Trust Level** | All users | Premium/Trusted |
| **API Endpoint** | `/work_proofs` | `/time_clockings` |
| **Table** | `work_proofs` | `time_clockings` |
| **Consolidation** | Same process | Same process |
| **Auto-consolidation** | ✅ Yes | ✅ Yes |

---

## 🔑 **Use Cases**

### **Work Proofs (Screenshots)**
- Junior developers
- Remote workers
- Contractors
- Accountability required
- Visual documentation needed

### **Time Clockings (No Screenshots)**
- Senior developers
- Managers
- Trusted team members
- Premium subscription
- Less intrusive tracking

---

## 🧪 **Testing**

### **Create Time Clockings**

```bash
# Clocking #1 (first)
curl -X POST \
  -H "X-Redmine-API-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{"issue_id": 1, "activity_id": 9, "time_hours": 0.0}' \
  "http://localhost:3000/projects/1/time_clockings.json"

# Clocking #2 (~10 min later)
curl -X POST \
  -H "X-Redmine-API-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{"issue_id": 1, "activity_id": 9, "time_hours": 0.17}' \
  "http://localhost:3000/projects/1/time_clockings.json"

# Clocking #3 (~10 min later)
curl -X POST \
  -H "X-Redmine-API-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{"issue_id": 1, "activity_id": 9, "time_hours": 0.17}' \
  "http://localhost:3000/projects/1/time_clockings.json"
```

### **Consolidate**

```bash
curl -X POST \
  -H "X-Redmine-API-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{"issue_id": 1}' \
  "http://localhost:3000/projects/1/time_clockings/consolidate_by_issue.json"

# Expected: 0.34 hours (0.0 + 0.17 + 0.17)
```

---

## 🤖 **Auto-Consolidation**

### **Cron Setup (Both Systems)**

```bash
crontab -e

# Add:
0 * * * * cd /var/www/redmine && bundle exec rake time_clocking:auto_consolidate_all RAILS_ENV=production >> log/auto_consolidate.log 2>&1
```

This consolidates BOTH:
- Work proofs (with screenshots)
- Time clockings (without screenshots)

### **Individual Tasks**

```bash
# Work proofs only
bundle exec rake work_proof:auto_consolidate

# Time clockings only
bundle exec rake time_clocking:auto_consolidate

# Both
bundle exec rake time_clocking:auto_consolidate_all
```

---

## 🎯 **Summary**

**New Feature: Time Clockings**
- ✅ Same workflow as work_proofs
- ✅ No screenshot required
- ✅ JSON-only API
- ✅ Less bandwidth/storage
- ✅ For trusted/premium users

**Endpoints:**
```
POST /projects/1/time_clockings.json - Create clocking
POST /projects/1/time_clockings/consolidate_by_issue.json - Consolidate
```

**Database:**
- `time_clockings` table (similar to work_proofs)
- `time_hours` instead of screenshots

**Auto-consolidation:**
- Same 4-hour rule
- Same cron setup
- Separate or combined

**Ready for premium users!** 🎉

