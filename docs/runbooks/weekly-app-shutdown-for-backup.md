# Weekly Application Shutdown for Database Backup

## Overview

**Purpose**: Stop application services to allow database team to perform full backup
**Frequency**: Weekly (every Saturday)
**Duration**: 30-45 minutes total application downtime
**Performed by**: On-call operations engineer
**Coordinates with**: Database backup team

## Maintenance Window

- **Start Time**: Saturday 22:00 PST
- **End Time**: Saturday 23:00 PST (target)
- **Maximum Duration**: 1 hour
- **Backup Duration**: 2-4 hours (database team handles this)

## Prerequisites

- [ ] You are in the approved maintenance window
- [ ] No P1/P2 incidents in progress
- [ ] Database team confirmed ready for backup
- [ ] Access to ansible control node
- [ ] PagerDuty/Slack available for escalation

---

## Procedure

### Phase 1: Pre-Shutdown (5 minutes)

#### 1.1 Post Maintenance Notification

```bash
# Post in Slack #ops-maintenance
"🔧 Starting weekly app shutdown for database backup
 - Start time: [current time]
 - Expected downtime: 30-45 minutes
 - Will notify when backup begins"
```

#### 1.2 Verify System State

```bash
# Navigate to ansible directory
cd /opt/ansible/fluffy-potato

# Check current service status (read-only, safe)
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

**Expected Output**:
```
TASK [Display service status for foo] ****
ok: [app-01.dc1.example.com] => {
    "msg": [
        "Service: foo",
        "Status output: foo is running",
        "Running: Yes"
    ]
}
```

✅ **Success**: All services show "Running: Yes"
❌ **Failure**: If services already stopped, verify if this is expected

#### 1.3 Check Monitoring Dashboard

- Open monitoring dashboard
- Verify no active critical alerts
- Note current ingestion rate (for post-restart comparison)

### Phase 2: Application Shutdown (10-15 minutes)

#### 2.1 Initiate Application Stop

```bash
# Stop all application services
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

**What You'll See**:

The playbook will execute in this order:
1. **Elephant service** (data loaders) stops first
2. **Bar service** (middleware/ETL) stops second
3. **Queue monitoring** - Waits for files to be processed
4. **Foo service** (ingestion) stops last

#### 2.2 Monitor Queue Drain

Watch for this task output:

```
TASK [Wait for pipeline queue to drain from /tmp] ****
```

**Expected**:
```
ok: [queue-01.dc1.example.com] (item=0)
changed: false
```

✅ **Success**: Task completes within 5-10 minutes
⚠️ **Warning**: If retrying multiple times (more than 10), see troubleshooting below

💡 **Tip**: Queue drain timeout is 30 minutes (configurable). You'll see retry messages every 5 seconds.

#### 2.3 Verify Successful Shutdown

**Play Recap Should Show**:

```
PLAY RECAP ********************************************************************
app-01.dc1.example.com     : ok=10   changed=3    unreachable=0    failed=0
app-02.dc1.example.com     : ok=10   changed=3    unreachable=0    failed=0
db-coord-01.dc1.example.com: ok=8    changed=2    unreachable=0    failed=0
queue-01.dc1.example.com   : ok=6    changed=1    unreachable=0    failed=0
```

✅ **All `failed=0`** - Shutdown successful
❌ **Any `failed=1` or higher** - See troubleshooting section

#### 2.4 Confirm Services Stopped

```bash
# Double-check all services are stopped
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

**Expected Output**:
```
TASK [Display service status] ****
ok: [app-01] => {
    "msg": [
        "Service: foo",
        "Running: No",
        "Stopped: Yes"
    ]
}
```

✅ **All services**: "Running: No", "Stopped: Yes"

### Phase 3: Handoff to Database Team (2 minutes)

#### 3.1 Check Email Workflow Report

- Check email for workflow report (sent automatically)
- Subject should be: `[PROD] [SUCCESS] stop workflow completed`
- Review for any warnings or force-kill events

**Sample Report**:
```
Workflow Summary
================
Type: stop
Status: success
Duration: 847 seconds (14 minutes)

Task Execution Timeline
========================
1. elephant - stop - 120s - success
2. bar - stop - 95s - success
3. file_monitoring - wait_for_deletion - 312s - success
4. foo - stop - 45s - success
```

⚠️ **If you see force-kill events**: Note in handoff, may indicate app issues

#### 3.2 Notify Database Team

```bash
# Post in Slack #database-team
"✅ Application shutdown complete
 - All services stopped successfully
 - Queue drained (312 files processed)
 - System ready for backup
 - Workflow report: [link to email]

 Database team: You may proceed with backup"
```

#### 3.3 Update Change Ticket

- Update change management ticket with shutdown completion
- Note actual shutdown time
- Attach email workflow report

### Phase 4: Wait for Database Backup (2-4 hours)

**During Backup**:
- Monitor Slack #database-team for backup completion
- Services remain stopped
- No action required from ops during this phase

⚠️ **Do not restart services until database team confirms backup complete**

### Phase 5: Application Restart (10-15 minutes)

#### 5.1 Wait for Database Team Confirmation

**Required confirmation** from database team:
```
"✅ Database backup complete
 - Backup successful
 - Database restarted and online
 - Safe to restart application services"
```

#### 5.2 Start Application Services

```bash
# Restart all application services
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

**Service Start Order**:
1. **Foo service** (ingestion) starts first
2. **Bar service** (middleware/ETL) starts second
3. **Elephant service** (loaders) starts last

**Expected Output**:
```
TASK [Service started successfully for foo] ****
ok: [app-01] => {
    "msg": "foo started successfully and is running"
}
```

#### 5.3 Verify Service Health

```bash
# Check all services running
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

✅ **All services**: "Running: Yes"

#### 5.4 Verify Application Function

**Manual checks**:

1. **Check ingestion**:
   ```bash
   # Verify logs being received
   ssh app-01 "tail -20 /var/log/app/ingestion.log"
   ```
   Expected: Recent timestamps (within last 2 minutes)

2. **Check processing**:
   ```bash
   # Verify queue has activity
   ls -lht /tmp/*.processing | head -5
   ```
   Expected: New files being created

3. **Check monitoring dashboard**:
   - Ingestion rate returning to normal
   - No error spikes
   - All health checks green

### Phase 6: Post-Restart Verification (5 minutes)

#### 6.1 Monitor for 5 Minutes

- Watch monitoring dashboard for anomalies
- Check error logs for any startup issues
- Verify data pipeline is flowing

#### 6.2 Check Email Workflow Report

- Subject should be: `[PROD] [SUCCESS] start workflow completed`
- Verify all services started successfully
- Note any warnings

#### 6.3 Final Notification

```bash
# Post in Slack #ops-maintenance
"✅ Weekly backup maintenance complete
 - Application shutdown: 14 minutes
 - Database backup: 2h 34m (database team)
 - Application restart: 8 minutes
 - All services healthy
 - Total downtime: 45 minutes

 Next backup: [Next Saturday date] 22:00 PST"
```

#### 6.4 Close Change Ticket

- Mark change request as complete
- Attach both workflow reports (stop and start)
- Note total downtime: [actual time]

---

## Troubleshooting

### Issue: Queue Drain Timeout

**Symptom**:
```
TASK [Wait for pipeline queue to drain] ****
FAILED! => {"msg": "Pipeline queue drain timeout: 45 files still present"}
```

**Cause**: Files stuck in queue for > 30 minutes

**Solution**:

1. **Check for old stuck files**:
   ```bash
   ansible queue_servers -i inventory/hosts -m shell \
     -a "find /tmp -name '*.lock' -o -name '*.tmp' -mmin +60 -ls"
   ```

2. **Identify stuck processes**:
   ```bash
   ansible all -i inventory/hosts -m shell \
     -a "ps aux | grep -E 'loader|etl|processor' | grep -v grep"
   ```

3. **If files are old (> 1 hour)**:
   ```bash
   # Remove old stuck files
   ansible queue_servers -i inventory/hosts -m shell \
     -a "find /tmp -name '*.lock' -mmin +60 -delete"

   # Re-run stop playbook
   ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
   ```

4. **If processes are stuck**:
   - Document process IDs and command lines
   - Escalate to platform team
   - May need manual kill after investigation

### Issue: Service Won't Stop

**Symptom**:
```
TASK [Stop service for foo] ****
fatal: [app-01]: FAILED! => {"msg": "Service failed to stop gracefully"}
```

**Solution**:

1. **Check service logs**:
   ```bash
   ssh app-01 "tail -100 /var/log/app/foo.log"
   ```

2. **Try manual stop**:
   ```bash
   ssh app-01 "/scripts/foo.sh stop"
   ```

3. **If service is critical for backup** (loaders/ETL):
   - Escalate immediately to platform team
   - Database backup cannot proceed with loaders running

4. **If service is non-critical** (APIs):
   - Document in change ticket
   - May proceed with backup if database team approves
   - Address service issue after backup

### Issue: Service Won't Start After Backup

**Symptom**:
```
TASK [Verify service is running for foo] ****
FAILED! => {"msg": "Service not running after 3 retries"}
```

**Solution**:

1. **Check why service failed to start**:
   ```bash
   ssh app-01 "/scripts/foo.sh status"
   ssh app-01 "tail -50 /var/log/app/foo.log"
   ```

2. **Common causes**:
   - Configuration error: Check for recent config changes
   - Port already in use: `netstat -tlnp | grep [port]`
   - Missing dependencies: Check service dependencies
   - Database not ready: Verify database is actually online

3. **Try manual start**:
   ```bash
   ssh app-01 "/scripts/foo.sh start"
   # Watch output for errors
   ```

4. **If multiple services fail**:
   - Possible database connectivity issue
   - Escalate to database team
   - Verify database is accepting connections

### Issue: Force Kill Event in Report

**Symptom**: Email report shows:
```
Force Kill Events
=================
Service: bar
Host: db-coord-01.dc1.example.com
Process: COMPONENT=bar
Timestamp: 2025-12-26T22:15:30Z
```

**Impact**:
- Usually OK for stateless services (ingestion, APIs)
- ⚠️ **Concern** for stateful services (ETL jobs, loaders)

**Actions**:

1. **Check which service was killed**:
   - Review email report for service name and host

2. **For loader services**:
   - Coordinate with database team
   - May need to verify no partial loads
   - Check database logs for uncommitted transactions

3. **For ETL services**:
   - Check for incomplete transformation jobs
   - May need to replay ETL pipeline

4. **Document incident**:
   - Note in change ticket
   - If recurring, create issue for platform team

### Issue: Email Report Not Received

**Symptom**: No workflow report email after 5 minutes

**Causes**:
- SMTP server issue
- Email configuration incorrect
- Playbook failed before sending report

**Solution**:

1. **Check playbook completed**:
   - Review terminal output for completion
   - Look for "PLAY RECAP" at end

2. **Check localhost facts** (where email is sent from):
   ```bash
   ansible localhost -m debug -a "var=hostvars['localhost']['workflow_metadata']"
   ```

3. **Test email manually**:
   ```bash
   # Send test email
   echo "Test" | mail -s "Test Email" ops-team@company.com
   ```

4. **Workflow report is also displayed in terminal**:
   - Scroll back in terminal output
   - Look for "TASK [Display workflow report]"
   - Report text is shown even if email fails

---

## Escalation Criteria

**Escalate immediately if**:

- ❌ Queue drain timeout exceeds 30 minutes
- ❌ Data loader services won't stop after 15 minutes
- ❌ Services won't restart after backup
- ❌ Any data corruption suspected
- ❌ Unclear about any step in procedure

**Escalation Contacts**:
- Platform Team: Slack #platform-ops
- On-call Engineer: PagerDuty
- Database Team: Slack #database-team

**Don't escalate for**:
- ✅ Force kill of ingestion/API services (document only)
- ✅ Queue drain taking 10-15 minutes (within normal range)
- ✅ Individual service restart delays < 5 minutes

---

## Success Metrics

**Target Metrics**:
- Application shutdown: < 15 minutes
- Queue drain: < 10 minutes
- Application restart: < 10 minutes
- Total downtime: < 45 minutes

**Track in Change Ticket**:
- Actual shutdown time
- Queue drain time
- Any force-kill events
- Total downtime
- Issues encountered

---

## Notes for Next Time

After each backup operation, note:
- Any deviations from procedure
- Services that took longer than expected
- Queue files that required investigation
- Suggested improvements to procedure

**Example**:
```
2025-12-26 Backup Notes:
- Bar service took 12 minutes to stop (investigating why)
- 15 stuck .lock files from previous week (need cleanup process)
- Total downtime: 38 minutes (better than target)
```

---

**Last Updated**: 2025-12-26
**Next Review**: After 3 successful backup cycles
