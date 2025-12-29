# Emergency Restart Procedure

## Overview

**Purpose**: Quickly restart application services during an outage or critical incident
**When to Use**: P1/P2 incidents, service failures, unplanned outages
**Duration**: 10-15 minutes
**Performed by**: On-call engineer
**Authority**: Can be executed without change approval during incidents

⚠️ **This is for emergencies only** - Use standard procedures for planned maintenance

---

## When to Use Emergency Restart

### Use emergency restart for:

- ✅ All services down unexpectedly
- ✅ Application crash or hang
- ✅ Memory leak causing OOM
- ✅ Cascading failures
- ✅ After infrastructure failure (power, network restored)
- ✅ Critical bug requiring immediate service restart

### Do NOT use emergency restart for:

- ❌ Planned maintenance (use weekly backup procedure)
- ❌ Application updates (use monthly update procedure)
- ❌ Individual service issues (restart that service only)
- ❌ Database issues (coordinate with database team)
- ❌ Network issues (fix network first)

---

## Pre-Flight Assessment (2 minutes)

### Quick Checks Before Restart

1. **Is this actually an emergency?**
   - Is service degraded or down?
   - Is this impacting customers?
   - Is immediate action required?

2. **What caused the outage?**
   - Infrastructure failure?
   - Application bug?
   - External dependency down?
   - Resource exhaustion?

3. **Will restart help?**
   - ✅ Application crash: Yes
   - ✅ Memory leak: Temporary fix
   - ✅ Hung processes: Yes
   - ❌ Database down: No - fix database first
   - ❌ Network partition: No - fix network first
   - ❌ Configuration error: No - fix config first

⚠️ **If restart won't help, address root cause instead**

---

## Emergency Restart Procedure

### Phase 1: Incident Declaration (1 minute)

#### 1.1 Declare Incident

```bash
# Slack #incidents
"🚨 INCIDENT DECLARED - Application Outage
 - Severity: P1
 - Impact: All services down
 - Action: Emergency restart in progress
 - Incident Commander: [Your name]
 - ETA: 15 minutes"
```

#### 1.2 Page Additional Resources (if needed)

- Major outage (P1): Page platform team
- Database suspected: Page database team
- Unknown cause: Page senior engineer

### Phase 2: Quick Assessment (2 minutes)

#### 2.1 Check Current Service State

```bash
cd /opt/ansible/fluffy-potato

# Quick status check
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

**Document current state**:
- Which services are down?
- Are any services still running?
- Any errors in output?

#### 2.2 Check System Resources

```bash
# Check if hosts are reachable
ansible all -i inventory/hosts -m ping

# Quick resource check
ansible all -i inventory/hosts -m shell \
  -a "uptime && free -h && df -h / | tail -1"
```

**Look for**:
- High load average
- Low memory
- Full disk
- Hosts unreachable

### Phase 3: Force Stop (If Needed) (3-5 minutes)

⚠️ **Only if services are hung or unresponsive**

#### 3.1 Attempt Graceful Stop First

```bash
# Try normal stop (2 minute timeout)
timeout 120 ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

#### 3.2 Force Kill If Graceful Stop Fails

```bash
# If graceful stop times out, force kill processes
ansible all -i inventory/hosts -m shell -a "pkill -9 -f 'COMPONENT=(foo|bar|elephant)'"

# Verify processes killed
ansible all -i inventory/hosts -m shell -a "ps aux | grep -E 'foo|bar|elephant' | grep -v grep || echo 'All processes stopped'"
```

✅ **Expected**: "All processes stopped"

#### 3.3 Clean Up Stale Resources

```bash
# Remove stale PID files
ansible all -i inventory/hosts -m shell -a "rm -f /var/run/app/*.pid"

# Remove stale lock files (if old)
ansible queue_servers -i inventory/hosts -m shell \
  -a "find /tmp -name '*.lock' -mmin +60 -delete"

# Clear shared memory segments (if application uses them)
ansible all -i inventory/hosts -m shell \
  -a "ipcs -m | grep appuser | awk '{print \$2}' | xargs -r ipcrm -m"
```

### Phase 4: Quick Health Check (1 minute)

Before restarting, verify infrastructure is healthy:

```bash
# Check disk space
ansible all -i inventory/hosts -m shell \
  -a "df -h / | awk 'NR==2 {print \$5}' | sed 's/%//'"
```

✅ **Expected**: < 90% on all hosts
❌ **If > 95%**: Clear logs before restart

```bash
# Check database connectivity (if applicable)
ansible app_tier -i inventory/hosts -m shell \
  -a "timeout 5 nc -zv db-coord-01 5432 2>&1 | grep succeeded"
```

✅ **Expected**: "succeeded"
❌ **If failed**: Database issue - coordinate with DB team

### Phase 5: Start Services (5-8 minutes)

#### 5.1 Start All Services

```bash
# Start services in normal order
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

**Watch for**:
- Services starting successfully
- No immediate crashes
- Status checks passing

#### 5.2 Verify Services Started

```bash
# Check status
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

✅ **All services**: "Running: Yes"
❌ **If services fail to start**: See troubleshooting section

### Phase 6: Immediate Verification (2 minutes)

#### 6.1 Smoke Tests

```bash
# Test ingestion endpoint
curl -f -X POST http://app-01:8080/v1/ingest \
  -H "Content-Type: application/json" \
  -d '{"test": "emergency_restart", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
```

✅ **Expected**: HTTP 200

```bash
# Test health endpoint
curl -f http://app-01:8080/v1/health
```

✅ **Expected**: HTTP 200, `{"status": "healthy"}`

#### 6.2 Check Logs

```bash
# Quick log check for errors
ansible all -i inventory/hosts -m shell \
  -a "tail -20 /var/log/app/app.log | grep -i -E 'error|exception|fatal' || echo 'No errors'"
```

#### 6.3 Check Monitoring

- Open monitoring dashboard
- Verify services showing as healthy
- Check for error rate spikes
- Verify ingestion resuming

### Phase 7: Incident Update (1 minute)

#### 7.1 Update Incident Channel

```bash
# Slack #incidents
"✅ Emergency restart complete
 - All services restarted
 - Smoke tests passed
 - Monitoring shows healthy
 - Total downtime: [X] minutes

 Monitoring for 15 minutes before resolving incident"
```

#### 7.2 Notify Stakeholders

```bash
# Slack #ops-status
"ℹ️ Service recovery in progress
 - Application services restarted
 - Smoke tests passed
 - Monitoring for stability
 - Updates in #incidents"
```

---

## Troubleshooting

### Issue: Services Won't Start After Restart

**Symptom**:
```
TASK [Verify service is running] ****
FAILED! => {"msg": "Service not running after 3 retries"}
```

**Quick Diagnosis**:

```bash
# Try manual start to see error
ssh app-01 "/scripts/foo.sh start"

# Check immediate logs
ssh app-01 "tail -50 /var/log/app/foo.log"
```

**Common Issues**:

1. **Configuration error**:
   ```bash
   # Validate config
   ssh app-01 "/opt/app/bin/validate-config /opt/app/config/app.yml"
   ```

2. **Port already in use**:
   ```bash
   # Check what's using the port
   ssh app-01 "netstat -tlnp | grep 8080"
   # Kill the process if it's stale
   ssh app-01 "kill -9 [PID]"
   ```

3. **Missing dependencies**:
   ```bash
   # Check database connectivity
   ssh app-01 "nc -zv db-coord-01 5432"
   ```

4. **Permissions issue**:
   ```bash
   # Check file ownership
   ssh app-01 "ls -la /opt/app/ /var/log/app/"
   ```

### Issue: Services Start But Crash Immediately

**Symptom**: Service shows "Running: Yes" then crashes within 30 seconds

**Check**:

```bash
# Watch logs in real-time
ssh app-01 "tail -f /var/log/app/app.log"

# Check for segmentation faults
ssh app-01 "dmesg | tail -20"

# Check memory available
ssh app-01 "free -h"
```

**Actions**:

1. **If memory issue**: Clear cache and retry
   ```bash
   ansible all -i inventory/hosts -m shell -a "sync && echo 3 > /proc/sys/vm/drop_caches"
   ```

2. **If configuration issue**: Fix config and retry
3. **If application bug**: May need code fix - escalate

### Issue: Database Connection Failures

**Symptom**: Logs show "Connection refused" or "Connection timeout" to database

**Check**:

```bash
# Verify database is actually up
ssh db-coord-01 "ps aux | grep postgres | grep -v grep"

# Test connection from app server
ssh app-01 "psql -U appuser -h db-coord-01 -d analytics -c 'SELECT 1'"
```

**Actions**:

1. **If database is down**: Coordinate with database team - don't restart app yet
2. **If network issue**: Check firewall rules, routing
3. **If credential issue**: Verify connection string in config

### Issue: Partial Service Start

**Symptom**: Some services running, some failed

```
app-01: Running: Yes
app-02: Running: No  <<<
app-03: Running: Yes
```

**Action**:

```bash
# Focus on failed host
ssh app-02 "tail -100 /var/log/app/app.log"

# Check for host-specific issues
ssh app-02 "df -h && free -h && uptime"

# Try manual restart on that host only
ssh app-02 "/scripts/service.sh stop && sleep 5 && /scripts/service.sh start"
```

### Issue: Services Running But Not Responding

**Symptom**: Status shows "Running: Yes" but health checks fail

**Check**:

```bash
# Check if port is listening
ansible all -i inventory/hosts -m shell -a "netstat -tlnp | grep 8080"

# Check if process is hung
ansible all -i inventory/hosts -m shell -a "ps aux | grep app | grep -v grep"

# Check for high CPU (infinite loop)
ansible all -i inventory/hosts -m shell -a "top -b -n 1 | head -20"
```

**Actions**:

1. **If hung**: Force kill and restart
2. **If deadlock**: May need code fix - collect thread dumps first
3. **If high CPU**: Investigate cause before restart

---

## Special Scenarios

### Scenario: After Infrastructure Failure

**Context**: Power outage, network partition, hardware failure resolved

**Additional Steps**:

1. **Verify infrastructure healthy**:
   ```bash
   # Check all hosts reachable
   ansible all -i inventory/hosts -m ping

   # Verify time sync
   ansible all -i inventory/hosts -m shell -a "date -u"
   ```

2. **Check database state**:
   - Coordinate with database team
   - Verify database is online and accepting connections
   - Check for any corruption or recovery needed

3. **Check storage mounts**:
   ```bash
   ansible all -i inventory/hosts -m shell -a "mount | grep /data"
   ```

4. **Then proceed with normal emergency restart**

### Scenario: Memory Leak / OOM

**Context**: Services killed by OOM killer

**Additional Steps**:

1. **Verify OOM occurred**:
   ```bash
   ansible all -i inventory/hosts -m shell \
     -a "dmesg | grep -i 'out of memory' | tail -5"
   ```

2. **Clear memory before restart**:
   ```bash
   # Drop caches
   ansible all -i inventory/hosts -m shell \
     -a "sync && echo 3 > /proc/sys/vm/drop_caches"

   # Verify memory available
   ansible all -i inventory/hosts -m shell -a "free -h"
   ```

3. **Monitor memory after restart**:
   ```bash
   # Watch memory usage
   watch -n 5 'ansible all -i inventory/hosts -m shell -a "free -h" | grep -A 1 total'
   ```

4. **Create incident for memory leak investigation**

### Scenario: After Failed Deployment

**Context**: Deployment went wrong, need to restore service quickly

**Options**:

1. **If backup exists from before deployment**:
   ```bash
   # Restore from backup (see monthly-app-update.md Phase 6)
   ansible all -i inventory/hosts -m shell -a "
     rm -rf /opt/app/* &&
     tar -xzf /opt/backups/app-[YYYYMMDD].tar.gz -C / --strip-components=2
   "

   # Then restart services
   ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
   ```

2. **If no backup**:
   - Escalate to platform team
   - May need to redeploy previous version from CI/CD

---

## Post-Emergency Actions

### Immediate (Within 1 hour)

- [ ] Monitor services for stability
- [ ] Check error rates and performance
- [ ] Verify data pipeline caught up
- [ ] Create detailed incident timeline
- [ ] Notify stakeholders of resolution

### Same Day

- [ ] Create incident ticket with details
- [ ] Document root cause (if known)
- [ ] Identify monitoring gaps
- [ ] Review email workflow reports

### Within 3 Days

- [ ] Conduct post-mortem
- [ ] Identify preventive measures
- [ ] Update runbooks if needed
- [ ] Implement fixes to prevent recurrence

---

## Escalation

### Escalate immediately if:

- ❌ Services won't start after 15 minutes
- ❌ Database connectivity issues
- ❌ Infrastructure problems (storage, network)
- ❌ Restart makes problem worse
- ❌ Unknown root cause
- ❌ Data integrity concerns

### Escalation Contacts

**During Emergency**:
- Platform Team: PagerDuty (auto-page for P1)
- Database Team: Slack #database-team + page
- Network Team: NOC hotline
- Management: [Phone numbers]

**Post-Emergency**:
- Schedule post-mortem: Slack #incidents
- Long-term fixes: Platform team sprint planning

---

## Emergency Restart Checklist

Quick checklist for high-pressure situations:

```
[ ] Declare incident in #incidents
[ ] Page additional resources if P1
[ ] Check service status
[ ] Check system resources (disk, memory)
[ ] Stop services (graceful or force)
[ ] Clean up stale resources
[ ] Verify infrastructure healthy
[ ] Start services
[ ] Verify services running
[ ] Smoke tests
[ ] Check monitoring dashboard
[ ] Update incident channel
[ ] Monitor for 15 minutes
[ ] Create incident ticket
```

---

## Key Differences from Planned Maintenance

| Aspect | Emergency Restart | Planned Maintenance |
|--------|------------------|---------------------|
| **Approval** | No approval needed | Change ticket required |
| **Queue drain** | Skip if safe | Always wait for drain |
| **Notifications** | During/after | 24 hours before |
| **Testing** | Minimal smoke tests | Full test suite |
| **Rollback plan** | Best effort | Documented and tested |
| **Documentation** | After the fact | Before execution |
| **Force kill** | Acceptable if needed | Avoid if possible |

---

**Last Updated**: 2025-12-26
**Emergency Hotline**: [Add your emergency contact info]
