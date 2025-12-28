# Monthly Application Update Procedure

## Overview

**Purpose**: Deploy application updates (code, schemas, configurations) to production
**Frequency**: Monthly (first Sunday of each month)
**Duration**: 1-2 hours total (30-45 min application downtime)
**Performed by**: Release engineer + on-call ops
**Coordinates with**: Platform team, database team (if schema changes)

## Maintenance Window

- **Start Time**: First Sunday 02:00 PST
- **End Time**: First Sunday 04:00 PST (target)
- **Maximum Duration**: 2 hours
- **Application Downtime**: 30-45 minutes (during deployment only)

## Prerequisites

- [ ] Release notes reviewed and approved
- [ ] Deployment package tested in staging
- [ ] Rollback plan documented
- [ ] Database migrations reviewed (if applicable)
- [ ] Change management ticket approved
- [ ] On-call ops and release engineer available
- [ ] Platform team on standby

---

## Pre-Deployment Planning

### Update Checklist

Review the release package:

- [ ] **Version**: What version is being deployed? (e.g., v2.4.0)
- [ ] **Components affected**: Which services are being updated?
- [ ] **Breaking changes**: Any API changes or configuration updates?
- [ ] **Database migrations**: Schema changes required?
- [ ] **Rollback tested**: Can we revert to previous version?

### Communication Plan

**Pre-announcement** (24 hours before):
```
"📢 Monthly application update scheduled
 - Date: [First Sunday] 02:00-04:00 PST
 - Expected downtime: 30-45 minutes
 - Version: v2.4.0
 - Release notes: [link]

 Contact #platform-ops with questions"
```

---

## Procedure

### Phase 1: Pre-Update Preparation (15 minutes)

#### 1.1 Verify Deployment Package

```bash
# Navigate to deployment directory
cd /opt/deployments

# Verify package exists and checksums match
ls -lh app-v2.4.0.tar.gz
sha256sum -c app-v2.4.0.tar.gz.sha256
```

✅ **Expected**: Checksum matches

#### 1.2 Document Current State

```bash
# Record current version
cd /opt/ansible/fluffy-potato
ansible all -i inventory/hosts -m shell -a "cat /opt/app/VERSION"

# Save output to change ticket
```

**Example Output**:
```
app-01.dc1.example.com | CHANGED | rc=0 >>
v2.3.0

app-02.dc1.example.com | CHANGED | rc=0 >>
v2.3.0
```

💡 **Save this** - needed for rollback if required

#### 1.3 Backup Current Application

```bash
# Create backup of current application
ansible all -i inventory/hosts -m shell -a "tar -czf /opt/backups/app-$(date +%Y%m%d).tar.gz /opt/app/"
```

⚠️ **Critical**: Verify backups created on all hosts

#### 1.4 Post Update Start Notification

```bash
# Slack #ops-maintenance
"🚀 Starting monthly application update
 - Version: v2.3.0 → v2.4.0
 - Start time: [current time]
 - Expected downtime: 30-45 minutes
 - Release notes: [link]"
```

### Phase 2: Application Shutdown (10-15 minutes)

#### 2.1 Stop Application Services

```bash
cd /opt/ansible/fluffy-potato

# Stop all services (same as weekly backup)
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

**Expected Output**:
```
PLAY RECAP ********************************************************************
app-01     : ok=10   changed=3    failed=0
app-02     : ok=10   changed=3    failed=0
...
```

✅ **All `failed=0`** - Proceed to deployment
❌ **Any failures** - See [weekly backup runbook](weekly-app-shutdown-for-backup.md) troubleshooting

#### 2.2 Verify Services Stopped

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

✅ **All services**: "Running: No", "Stopped: Yes"

### Phase 3: Deploy Application Update (20-30 minutes)

#### 3.1 Deploy Application Code

```bash
# Navigate to deployment directory
cd /opt/deployments

# Deploy to all app servers
ansible app_tier -i /opt/ansible/fluffy-potato/inventory/hosts -m copy \
  -a "src=app-v2.4.0.tar.gz dest=/tmp/"

# Extract on each server
ansible app_tier -i /opt/ansible/fluffy-potato/inventory/hosts -m shell -a "
  cd /opt/app &&
  tar -xzf /tmp/app-v2.4.0.tar.gz --strip-components=1
"
```

**Expected**: All hosts report SUCCESS

#### 3.2 Update Configuration Files

If configuration changes are required:

```bash
# Deploy new configs
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m copy \
  -a "src=configs/production/ dest=/opt/app/config/"

# Verify config syntax
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m shell \
  -a "/opt/app/bin/validate-config /opt/app/config/app.yml"
```

✅ **Expected**: "Configuration valid" on all hosts

#### 3.3 Run Database Migrations (if applicable)

⚠️ **Critical**: Only if schema changes are included in release

```bash
# Run migrations from coordinator host
ssh db-coord-01.dc1.example.com

# Execute migrations
cd /opt/app/migrations
./run-migrations.sh v2.4.0

# Verify migration status
./check-migration-status.sh
```

**Expected Output**:
```
Migration v2.4.0: SUCCESS
- Added table: event_metadata
- Added index: idx_event_timestamp
- Migration time: 3m 24s
```

✅ **Migration successful** - Continue
❌ **Migration failed** - STOP, initiate rollback (see Phase 6)

#### 3.4 Update Service Scripts

If service control scripts changed:

```bash
# Update service scripts
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m copy \
  -a "src=scripts/service.sh dest=/scripts/service.sh mode=0755"

# Verify script syntax
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m shell \
  -a "bash -n /scripts/service.sh"
```

#### 3.5 Verify Deployment

```bash
# Verify version on all hosts
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m shell \
  -a "cat /opt/app/VERSION"
```

**Expected Output**:
```
app-01.dc1.example.com | CHANGED | rc=0 >>
v2.4.0

app-02.dc1.example.com | CHANGED | rc=0 >>
v2.4.0
```

✅ **All hosts show v2.4.0**

### Phase 4: Application Startup (10-15 minutes)

#### 4.1 Start Application Services

```bash
cd /opt/ansible/fluffy-potato

# Start all services
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

**Expected Output**:
```
PLAY RECAP ********************************************************************
app-01     : ok=8    changed=3    failed=0
app-02     : ok=8    changed=3    failed=0
```

✅ **All `failed=0`** - Services started successfully

#### 4.2 Verify Services Running

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

✅ **All services**: "Running: Yes"

### Phase 5: Post-Deployment Verification (15-20 minutes)

#### 5.1 Smoke Tests - Basic Functionality

```bash
# Test ingestion endpoint
curl -X POST http://app-01.dc1.example.com:8080/v1/ingest \
  -H "Content-Type: application/json" \
  -d '{"test": "data", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}'
```

✅ **Expected**: HTTP 200, `{"status": "accepted"}`

```bash
# Test API endpoint
curl http://app-01.dc1.example.com:8080/v1/health
```

✅ **Expected**: HTTP 200, `{"status": "healthy", "version": "v2.4.0"}`

#### 5.2 Smoke Tests - Data Pipeline

```bash
# Verify ingestion logs show activity
ssh app-01 "tail -20 /var/log/app/ingestion.log | grep -i accepted"
```

✅ **Expected**: Recent log entries (within last 2 minutes)

```bash
# Check queue processing
ls -lht /tmp/*.processing | head -5
```

✅ **Expected**: Files being created/processed

```bash
# Verify data reaching database (if possible)
ssh db-coord-01 "psql -U appuser -d analytics -c 'SELECT COUNT(*) FROM events WHERE created_at > NOW() - INTERVAL '\''5 minutes'\'''"
```

✅ **Expected**: Non-zero count showing recent data

#### 5.3 Monitoring Dashboard Checks

Check monitoring dashboard for:

- [ ] All service health checks: GREEN
- [ ] Ingestion rate: Returning to normal levels
- [ ] Error rate: No unusual spikes
- [ ] Response times: Within normal range
- [ ] Queue depth: Decreasing (catching up)

#### 5.4 Check Application Logs

```bash
# Check for errors on all hosts
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m shell \
  -a "tail -100 /var/log/app/app.log | grep -i -E 'error|exception|fatal' || echo 'No errors found'"
```

✅ **Expected**: "No errors found" or only expected warnings

#### 5.5 Extended Monitoring (15 minutes)

- Monitor for 15 minutes after startup
- Watch for memory leaks or resource issues
- Verify queue backlog being processed
- Check error rates remain stable

### Phase 6: Rollback (If Required)

⚠️ **Execute rollback if**:
- Smoke tests fail
- Critical errors in logs
- Service won't start
- Database migration failed
- Performance degradation > 50%

#### 6.1 Immediate Stop

```bash
cd /opt/ansible/fluffy-potato

# Stop all services immediately
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

#### 6.2 Rollback Database Migrations

```bash
# Only if migrations were run in Phase 3.3
ssh db-coord-01.dc1.example.com
cd /opt/app/migrations

# Rollback to previous version
./rollback-migrations.sh v2.3.0

# Verify rollback
./check-migration-status.sh
```

✅ **Expected**: Database at v2.3.0 schema

#### 6.3 Restore Previous Application Version

```bash
# Restore from backup created in Phase 1.3
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m shell -a "
  rm -rf /opt/app/* &&
  tar -xzf /opt/backups/app-$(date +%Y%m%d).tar.gz -C / --strip-components=2
"

# Verify version restored
ansible all -i /opt/ansible/fluffy-potato/inventory/hosts -m shell \
  -a "cat /opt/app/VERSION"
```

✅ **Expected**: All hosts show v2.3.0 (previous version)

#### 6.4 Restart Services

```bash
cd /opt/ansible/fluffy-potato
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

#### 6.5 Verify Rollback Successful

- Run smoke tests (Phase 5.1)
- Check monitoring dashboard
- Verify services healthy

#### 6.6 Escalate and Document

```bash
# Slack #ops-maintenance
"❌ ROLLBACK EXECUTED - Update to v2.4.0 failed
 - Rolled back to: v2.3.0
 - Reason: [describe failure]
 - Services restored and healthy
 - Incident ticket: [create ticket]

 Platform team: Please investigate before retry"
```

### Phase 7: Completion (5 minutes)

#### 7.1 Final Status Check

```bash
# Verify all services healthy
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

#### 7.2 Review Email Workflow Reports

Check for:
- Stop workflow: Successful with no force-kills
- Start workflow: All services started successfully
- No unexpected warnings

#### 7.3 Update Documentation

```bash
# Record successful update
echo "v2.4.0 - $(date -u +%Y-%m-%d) - Deployed successfully" >> /opt/app/CHANGELOG.md
```

#### 7.4 Post Completion Notification

```bash
# Slack #ops-maintenance
"✅ Monthly application update complete
 - Version: v2.3.0 → v2.4.0
 - Deployment time: 45 minutes
 - Downtime: 38 minutes
 - Smoke tests: PASSED
 - All services healthy

 Release notes: [link]
 Change ticket: [link]"
```

#### 7.5 Close Change Ticket

- Mark change request as complete
- Attach workflow reports
- Document any deviations
- Note actual downtime and deployment time

---

## Troubleshooting

### Issue: Smoke Tests Fail After Deployment

**Symptom**: HTTP 500 errors or service not responding

**Immediate Action**:
```bash
# Check application logs
ssh app-01 "tail -100 /var/log/app/app.log"

# Check if process is actually running
ssh app-01 "ps aux | grep app"
```

**Common Causes**:
1. Configuration error - Check `/opt/app/config/`
2. Missing dependencies - Check `/opt/app/requirements.txt`
3. Database connection issue - Verify DB credentials
4. Port conflict - Check if port already in use

**Decision Point**:
- If fixable in < 10 minutes: Fix and retry
- If unclear or complex: Execute rollback (Phase 6)

### Issue: Database Migration Fails

**Symptom**:
```
ERROR: Migration v2.4.0 failed
ALTER TABLE events ADD COLUMN metadata JSONB;
ERROR: duplicate column name "metadata"
```

**Action**:
⚠️ **STOP DEPLOYMENT** - Do not start services

**Steps**:
1. Document exact error message
2. Check migration log: `/opt/app/migrations/logs/`
3. Verify database state: Are partial changes applied?
4. Execute rollback (Phase 6)
5. Escalate to database team

**Do NOT**:
- Attempt to manually fix schema
- Continue deployment with failed migration
- Skip migration and start services

### Issue: Service Won't Start With New Version

**Symptom**:
```
TASK [Verify service is running] ****
FAILED! => {"msg": "Service not running after 3 retries"}
```

**Check**:
```bash
# Try manual start to see error
ssh app-01 "/scripts/service.sh start"

# Check logs immediately
ssh app-01 "tail -50 /var/log/app/app.log"
```

**Common Issues**:
- New config format incompatible
- Missing environment variables
- New dependency not installed
- Permission issues on new files

**Decision**:
- If error is clear and fixable: Fix and retry
- If unclear or requires investigation: Rollback

### Issue: Performance Degradation After Update

**Symptom**: Monitoring shows:
- Response times increased 2-3x
- CPU/memory usage much higher
- Queue backlog growing

**Action**:
1. **Document baseline metrics** from before update
2. **Check release notes** for known performance issues
3. **Monitor for 10 minutes** to see if it stabilizes

**Decision Criteria**:
- Response time < 2x baseline: Monitor, may be warmup
- Response time > 2x baseline: Consider rollback
- Error rate increasing: Immediate rollback
- Memory leak evident: Immediate rollback

### Issue: Partial Deployment (Some Hosts Failed)

**Symptom**:
```
app-01     : ok=15   changed=8    failed=0
app-02     : ok=8    changed=2    failed=1  <<<
app-03     : ok=15   changed=8    failed=0
```

**Action**:
⚠️ **Do not start services with mixed versions**

**Steps**:
1. Identify which host failed and why
2. Check if deployment files copied correctly
3. If recoverable: Fix failed host and retry deployment
4. If not recoverable: Rollback ALL hosts to previous version

**Never run mixed versions in production**

---

## Rollback Decision Matrix

| Condition | Severity | Action |
|-----------|----------|--------|
| Smoke test fails | CRITICAL | Immediate rollback |
| Database migration fails | CRITICAL | Immediate rollback |
| Service won't start | CRITICAL | Immediate rollback |
| Performance > 2x slower | HIGH | Rollback after 10 min monitoring |
| Minor errors in logs | MEDIUM | Investigate, rollback if not resolved in 15 min |
| Queue backlog growing | MEDIUM | Monitor, rollback if not catching up in 20 min |
| Single host deployment failed | HIGH | Rollback all hosts to maintain consistency |

---

## Post-Update Monitoring

### First 24 Hours

Monitor these metrics closely:

- [ ] Error rate (should be < baseline)
- [ ] Response times (should return to baseline within 1 hour)
- [ ] Queue depth (should clear backlog within 2 hours)
- [ ] Memory usage (watch for leaks)
- [ ] Disk usage (check for log spam)

### First Week

- [ ] Review error logs daily
- [ ] Check for any new patterns or issues
- [ ] Verify data quality in database
- [ ] Collect feedback from stakeholders

### Post-Mortem (If Issues Occurred)

If rollback was required or issues encountered:

1. **Schedule post-mortem** within 3 days
2. **Document timeline** of events
3. **Identify root cause** of failure
4. **Update deployment procedure** to prevent recurrence
5. **Retest in staging** before retry

---

## Success Metrics

**Target Metrics**:
- Total deployment time: < 60 minutes
- Application downtime: < 45 minutes
- Smoke tests: 100% pass rate
- Rollback rate: < 5% of deployments

**Track in Change Ticket**:
- Deployment start time
- Application stop/start times
- Smoke test results
- Issues encountered
- Total downtime
- Any deviations from procedure

---

## Release-Specific Notes

### v2.4.0 Example Notes

```yaml
# Update these for each release
version: "v2.4.0"
release_date: "2025-12-26"

changes:
  - "Added event metadata table"
  - "Updated ingestion API to v2"
  - "Improved ETL performance"

migrations:
  - "20251201_add_event_metadata.sql"
  - "20251215_create_indexes.sql"

config_changes:
  - "Added 'metadata_enabled: true' to app.yml"
  - "Updated API_VERSION to v2"

rollback_notes:
  - "Migrations are reversible"
  - "No data loss expected"
  - "API v1 still supported"

special_instructions:
  - "Verify metadata_enabled config before start"
  - "Monitor index creation time (may take 5-10 min)"
```

---

**Last Updated**: 2025-12-26
**Next Review**: After each deployment
