# WorkProof Time Tracking API

Complete time tracking system with auto-consolidation to Redmine time entries.

---

## 🎯 **Overview**

WorkProof now includes automatic time tracking:
- Client app sends work proofs every 5-10 minutes
- System tracks total hours worked
- Auto-consolidates to Redmine time_entries after 4 hours
- Manual clock-out option
- Prevents forgotten clock-outs

---

## 📊 **Status Workflow**

```
pending → clocked_in → clocked_out → calculated → consolidated
   ↓          ↓            ↓              ↓            ↓
 Start     Tracking    Manual Stop   Auto-Stop   Time Entry
  work     (5-10min)   by user       (>4h)      Created
```

| Status | Description | Can Edit | Can Consolidate |
|--------|-------------|----------|-----------------|
| **pending** | Initial state | ✅ Yes | ❌ No |
| **clocked_in** | Actively tracking | ✅ Yes | ❌ No |
| **clocked_out** | Manually stopped | ❌ No | ✅ Yes |
| **calculated** | Auto-stopped (>4h) | ❌ No | ✅ Yes |
| **consolidated** | Converted to time_entry | ❌ No | ❌ Already done |

---

## 🔌 **API Endpoints**

### **1. Create Work Proof (Start Tracking)**

```http
POST /projects/:project_id/work_proofs.json
Content-Type: multipart/form-data
X-Redmine-API-Key: YOUR_KEY

Form Data:
- image: [file]
- project_id: 1
- issue_id: 1
- activity_id: 9              ← Required for time tracking
- work_hours: 0.08            ← ~5 minutes (configurable)
- status: pending             ← Or clocked_in
- description: Started work
```

**Response:**
```json
{
  "work_proof": {
    "id": 1,
    "status": "pending",
    "clocked_in_at": "2025-10-30T10:00:00Z",
    "clocked_out_at": null,
    "clock_duration": 0.08,
    "activity_id": 9,
    "consolidated": false
  }
}
```

---

### **2. Update Work Proof (Continue Tracking)**

Send every 5-10 minutes with incremental hours:

```http
POST /projects/1/work_proofs.json
X-Redmine-API-Key: YOUR_KEY

{
  "issue_id": 1,
  "activity_id": 9,
  "work_hours": 0.16,     ← 10 minutes
  "status": "clocked_in"
}
```

**Client Logic:**
```javascript
// Example: Send every 10 minutes
setInterval(() => {
  const minutesWorked = (Date.now() - startTime) / 60000;
  const hours = (minutesWorked / 60).toFixed(2);
  
  sendWorkProof({
    issue_id: currentIssueId,
    activity_id: currentActivityId,
    work_hours: hours,
    status: 'clocked_in'
  });
}, 10 * 60 * 1000); // Every 10 minutes
```

---

### **3. Clock Out (Manual Stop)**

```http
POST /projects/1/work_proofs/1/clock_out.json
X-Redmine-API-Key: YOUR_KEY
```

**Response:**
```json
{
  "work_proof": {
    "id": 1,
    "status": "calculated",
    "clocked_in_at": "2025-10-30T10:00:00Z",
    "clocked_out_at": "2025-10-30T12:30:00Z",
    "clock_duration": 2.5,
    "work_hours": 2.5
  }
}
```

**What it does:**
- Sets `clocked_out_at` to current time
- Calculates total hours
- Updates `work_hours`
- Changes status to `calculated`

---

### **4. Consolidate to Time Entry**

```http
POST /projects/1/work_proofs/1/consolidate.json
X-Redmine-API-Key: YOUR_KEY
```

**Response:**
```json
{
  "work_proof": {
    "id": 1,
    "status": "consolidated",
    "time_entry_id": 42
  },
  "time_entry": {
    "id": 42,
    "hours": 2.5,
    "spent_on": "2025-10-30",
    "activity_id": 9,
    "comments": "Work proof #1"
  }
}
```

**What it does:**
- Creates Redmine TimeEntry
- Links work_proof to time_entry
- Sets status to `consolidated`
- Records `consolidated_at` timestamp

---

### **5. Consolidate by Issue (Batch)**

Combine multiple work proofs for same issue/user/date:

```http
POST /projects/1/work_proofs/consolidate_by_issue.json
X-Redmine-API-Key: YOUR_KEY
Content-Type: application/json

{
  "issue_id": 1,
  "user_id": 5,        ← Optional (defaults to current user)
  "date": "2025-10-30" ← Optional (defaults to today)
}
```

**Response:**
```json
{
  "time_entry": {
    "id": 43,
    "hours": 5.75,
    "spent_on": "2025-10-30",
    "activity_id": 9,
    "comments": "Consolidated from 7 work proof(s)"
  },
  "work_proofs_consolidated": 7
}
```

**Use case:** End of day - consolidate all work on an issue

---

## ⏱️ **Auto-Consolidation**

### **How It Works**

System automatically consolidates work proofs that are:
- ✅ Status: `pending` or `clocked_in`
- ✅ Started >4 hours ago
- ✅ Not already consolidated

**Process:**
1. Find old work proofs (>4 hours)
2. Auto clock-out if needed
3. Calculate total hours
4. Create time_entry
5. Mark as consolidated

### **Setup Cron Job**

Run hourly to process forgotten clock-outs:

```bash
# Edit crontab
crontab -e

# Add this line (runs every hour)
0 * * * * cd /var/www/redmine && bundle exec rake work_proof:auto_consolidate RAILS_ENV=production >> log/auto_consolidate.log 2>&1
```

**For development/testing:**
```bash
cd /Users/muhsinzyne/work/redmine-dev/redmine
bundle exec rake work_proof:auto_consolidate
```

---

## 📱 **Mobile App Integration**

### **Complete Workflow**

```javascript
class WorkProofTracker {
  startTracking(issueId, activityId) {
    this.startTime = Date.now();
    this.issueId = issueId;
    this.activityId = activityId;
    this.currentWorkProofId = null;
    
    // Send initial work proof
    this.sendWorkProof();
    
    // Send updates every 10 minutes
    this.interval = setInterval(() => {
      this.sendWorkProof();
    }, 10 * 60 * 1000);
  }
  
  async sendWorkProof() {
    const hours = this.getElapsedHours();
    
    const formData = new FormData();
    formData.append('image', await this.captureScreenshot());
    formData.append('issue_id', this.issueId);
    formData.append('activity_id', this.activityId);
    formData.append('work_hours', hours);
    formData.append('status', 'clocked_in');
    
    const response = await api.post(
      `/projects/1/work_proofs.json?key=${apiKey}`,
      formData
    );
    
    this.currentWorkProofId = response.data.work_proof.id;
  }
  
  async stopTracking() {
    clearInterval(this.interval);
    
    if (this.currentWorkProofId) {
      // Clock out
      await api.post(
        `/projects/1/work_proofs/${this.currentWorkProofId}/clock_out.json?key=${apiKey}`
      );
      
      // Optional: Consolidate immediately
      await api.post(
        `/projects/1/work_proofs/${this.currentWorkProofId}/consolidate.json?key=${apiKey}`
      );
    }
  }
  
  getElapsedHours() {
    const elapsed = Date.now() - this.startTime;
    return (elapsed / 3600000).toFixed(2); // Convert ms to hours
  }
}
```

---

## 🔍 **Query Examples**

### **Get Active Tracking Sessions**

```http
GET /projects/1/work_proofs.json?status=clocked_in
```

### **Get Pending Consolidation**

```http
GET /projects/1/work_proofs.json?status=calculated
```

### **Get Today's Work**

```http
GET /projects/1/work_proofs.json?date=2025-10-30
```

---

## 🛠️ **Rake Tasks**

### **Auto-Consolidate**

```bash
# Consolidate old entries
bundle exec rake work_proof:auto_consolidate

# Output:
# Starting auto-consolidation of old work proofs...
# Consolidated 5 work proofs
```

### **Check Pending**

```bash
# See what needs consolidation
bundle exec rake work_proof:check_pending

# Output:
# Found 3 work proofs needing consolidation:
#   - WorkProof #1: John Doe on Fix bug (2.5h)
#   - WorkProof #2: Jane Smith on Feature X (5.0h)
#   - WorkProof #3: Bob Johnson on Review (1.75h)
```

---

## 📊 **Database Schema**

```sql
work_proofs:
  - activity_id (integer)         ← TimeEntryActivity
  - time_entry_id (integer)       ← Link to created TimeEntry
  - clocked_in_at (datetime)      ← Start time
  - clocked_out_at (datetime)     ← End time
  - status (string)               ← Workflow state
  - work_hours (decimal 5,2)      ← Total hours
  - consolidated (boolean)        ← Quick check flag
  - consolidated_at (datetime)    ← When consolidated
```

---

## ✅ **Testing**

### **1. Create and Track**

```bash
# Start tracking
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  -F "image=@test.jpg" \
  -F "issue_id=1" \
  -F "activity_id=9" \
  -F "work_hours=0.08" \
  "http://localhost:3000/projects/1/work_proofs.json"
```

### **2. Clock Out**

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  "http://localhost:3000/projects/1/work_proofs/1/clock_out.json"
```

### **3. Consolidate**

```bash
curl -X POST \
  -H "X-Redmine-API-Key: YOUR_KEY" \
  "http://localhost:3000/projects/1/work_proofs/1/consolidate.json"
```

### **4. Check Time Entry**

```bash
curl -H "X-Redmine-API-Key: YOUR_KEY" \
  "http://localhost:3000/time_entries.json"
```

---

## 💡 **Best Practices**

### **Interval Configuration**

```javascript
// Short interval (more accurate, more data)
const INTERVAL = 5 * 60 * 1000; // 5 minutes

// Medium interval (balanced)
const INTERVAL = 10 * 60 * 1000; // 10 minutes

// Long interval (less accurate, less data)
const INTERVAL = 15 * 60 * 1000; // 15 minutes
```

### **Error Handling**

```javascript
async sendWorkProof() {
  try {
    await this.doSendWorkProof();
  } catch (error) {
    console.error('Failed to send work proof:', error);
    // Queue for retry
    this.queueForRetry();
  }
}
```

### **Offline Support**

```javascript
if (navigator.onLine) {
  sendWorkProof();
} else {
  queueOffline();
}

window.addEventListener('online', () => {
  syncOfflineQueue();
});
```

---

## 📈 **Benefits**

✅ **Accurate time tracking** - Incremental updates
✅ **Prevents data loss** - Auto-consolidation after 4h
✅ **Integrates with Redmine** - Creates time_entries
✅ **Flexible intervals** - 5, 10, 15 minutes (configurable)
✅ **Batch processing** - Consolidate by issue
✅ **Automatic cleanup** - Forgotten clock-outs handled
✅ **Activity tracking** - Links to Redmine activities

---

## 🎯 **Summary**

**Start tracking:**
```
POST /work_proofs (with activity_id)
```

**Keep tracking:**
```
POST /work_proofs every 5-10 min
```

**Stop tracking:**
```
POST /work_proofs/:id/clock_out
```

**Create time entry:**
```
POST /work_proofs/:id/consolidate
```

**Auto-consolidation:**
```
Cron: rake work_proof:auto_consolidate
```

**Status flow:**
```
pending → clocked_in → calculated → consolidated
```

**All committed and ready to use!** 🚀

