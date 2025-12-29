# Operator Quick Start Guide

## Welcome!

This guide helps you get started with operating the log storage and analytics application services using Ansible. If you're new to this system, start here.

## What This System Does

This Ansible framework manages the **application layer** of our log storage and analytics platform:

- **Ingestion services**: Receive logs from various sources
- **ETL/Processing services**: Transform and enrich log data
- **Loader services**: Load processed data into Greenplum database
- **Queue services**: Manage data flow between components

⚠️ **Note**: This does NOT manage the Greenplum database itself - that's handled separately by the database team.

---

## The Three Commands You'll Use Most

### 1. Check Status (Safe - Read Only)

Use this anytime to see what's running:

```bash
cd /opt/ansible/fluffy-potato
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

✅ **Safe to run anytime** - This is read-only, won't change anything

### 2. Stop All Services

Used for weekly backups and monthly updates:

```bash
cd /opt/ansible/fluffy-potato
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

**What Happens**:
1. Stops data loaders first (elephant)
2. Stops ETL/processing (bar)
3. Waits for queue to drain (5-30 minutes)
4. Stops ingestion last (foo)
5. Sends email report with results

⚠️ **Application downtime begins** - Only run during maintenance windows

### 3. Start All Services

Used after backups/updates to restore service:

```bash
cd /opt/ansible/fluffy-potato
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

**What Happens**:
1. Starts ingestion first (foo)
2. Starts ETL/processing (bar)
3. Starts data loaders last (elephant)
4. Sends email report with results

✅ **Services resume** - Data pipeline starts processing

---

## Common Operations

### Weekly Backup Procedure (Every Saturday 22:00 PST)

**Full procedure**: See [runbooks/weekly-app-shutdown-for-backup.md](runbooks/weekly-app-shutdown-for-backup.md)

**Quick version**:
```bash
# 1. Post notification in Slack #ops-maintenance
"🔧 Starting weekly app shutdown for backup"

# 2. Stop application
cd /opt/ansible/fluffy-potato
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop

# 3. Notify database team backup can start
"✅ Application stopped, ready for backup"

# 4. Wait for database team to complete backup (2-4 hours)

# 5. Start application
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start

# 6. Verify services healthy
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status

# 7. Post completion in Slack
"✅ Weekly backup complete, all services healthy"
```

### Monthly Update Procedure (First Sunday 02:00 PST)

**Full procedure**: See [runbooks/monthly-app-update.md](runbooks/monthly-app-update.md)

**Quick version**:
```bash
# 1. Stop application (same as backup)
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop

# 2. Deploy new version (release engineer handles this)

# 3. Start application
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start

# 4. Run smoke tests

# 5. Monitor for 15 minutes
```

### Emergency Restart

**Full procedure**: See [runbooks/emergency-restart.md](runbooks/emergency-restart.md)

**When to use**:
- Services crashed unexpectedly
- Application not responding
- After infrastructure failure resolved

**Quick version**:
```bash
# 1. Declare incident in #incidents

# 2. Force stop if needed
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop

# 3. Start services
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start

# 4. Verify and monitor
```

---

## Understanding the Output

### Successful Playbook Run

```
PLAY RECAP ********************************************************************
app-01.dc1.example.com     : ok=10   changed=3    unreachable=0    failed=0
app-02.dc1.example.com     : ok=10   changed=3    unreachable=0    failed=0
db-coord-01.dc1.example.com: ok=8    changed=2    unreachable=0    failed=0
```

✅ **Good indicators**:
- `failed=0` on all hosts
- `unreachable=0` on all hosts
- Email report received within 5 minutes

### Failed Playbook Run

```
TASK [Stop service for foo] ****
fatal: [app-01]: FAILED! => {"msg": "Service failed to stop gracefully"}

PLAY RECAP ********************************************************************
app-01.dc1.example.com     : ok=5    changed=1    unreachable=0    failed=1
```

❌ **Problem indicators**:
- `failed=1` or higher
- `unreachable=1` or higher
- Task shows `fatal` in red

**What to do**: See [runbooks/troubleshooting-common-issues.md](runbooks/troubleshooting-common-issues.md)

---

## Email Reports

After every start/stop operation, you'll receive an email report.

### Successful Report

```
Subject: [PROD] [SUCCESS] stop workflow completed

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

Force Kill Events: None
File Monitoring Events: None
```

✅ **This is good** - All tasks succeeded, no force kills needed

### Report with Warnings

```
Subject: [PROD] [SUCCESS] stop workflow completed

Force Kill Events
=================
Service: bar
Host: db-coord-01.dc1.example.com
Process: COMPONENT=bar
Timestamp: 2025-12-26T22:15:30Z
```

⚠️ **Review needed** - Service was force killed
- Check why graceful stop failed
- Review service logs
- Document in change ticket
- If recurring, create issue for platform team

---

## Safety Rules

### ✅ DO

1. **Always check status first** before making changes
2. **Run in approved maintenance windows**
   - Weekly backups: Saturday 22:00-23:00 PST
   - Monthly updates: First Sunday 02:00-04:00 PST
3. **Post notifications** in Slack before maintenance
4. **Review email reports** after operations
5. **Escalate early** if something seems wrong
6. **Document incidents** in change tickets

### ❌ DON'T

1. **Don't run outside maintenance windows** (except emergencies)
2. **Don't skip queue drain** - Data loss risk
3. **Don't manually kill processes** without understanding why
4. **Don't modify configuration** without change approval
5. **Don't ignore email warnings** - They indicate issues
6. **Don't wait > 15 minutes** if stuck - Escalate

---

## When Things Go Wrong

### "Queue drain timeout"

**What it means**: Files still in queue after 30 minutes

**What to do**:
1. Check for old stuck files: `ssh queue-01 "ls -lht /tmp/*.lock | head"`
2. If files > 1 hour old, safe to delete them
3. See troubleshooting guide for details

### "Service won't stop"

**What it means**: Service not responding to stop command

**What to do**:
1. Check service logs: `ssh app-01 "tail -50 /var/log/app/foo.log"`
2. Wait for timeout (playbook will force kill if enabled)
3. Review force kill event in email report
4. Document in change ticket

### "Service won't start"

**What it means**: Service failing to start after stop

**What to do**:
1. Check logs: `ssh app-01 "tail -100 /var/log/app/foo.log"`
2. Verify configuration: Check for recent changes
3. Check dependencies: Is database available?
4. See troubleshooting guide or escalate

---

## Getting Help

### Self-Service Resources

1. **Status check** (always safe):
   ```bash
   ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
   ```

2. **Troubleshooting guide**: [runbooks/troubleshooting-common-issues.md](runbooks/troubleshooting-common-issues.md)

3. **Detailed runbooks**: [runbooks/](runbooks/)

4. **Architecture docs**: [architecture.md](architecture.md)

### Escalation

**When to escalate**:
- ❌ Stuck for > 15 minutes
- ❌ Services won't start after backup
- ❌ Unclear what's happening
- ❌ Data integrity concerns
- ❌ P1/P2 incident

**How to escalate**:
- **Urgent (P1/P2)**: PagerDuty + Slack #incidents
- **Normal issues**: Slack #platform-ops
- **Questions**: Slack #ops-help

**What to include**:
- What you were trying to do
- What command you ran
- Error message (exact text)
- Current service status
- What you've tried so far

---

## Training Path

### Week 1: Shadow & Learn
- [ ] Read this guide
- [ ] Read weekly backup runbook
- [ ] Shadow experienced operator during Saturday backup
- [ ] Review email reports from that backup
- [ ] Ask questions in #ops-help

### Week 2: Supervised Practice
- [ ] Perform status checks independently
- [ ] Perform weekly backup with experienced operator watching
- [ ] Follow runbook step-by-step
- [ ] Document any issues or questions

### Week 3: Increased Independence
- [ ] Perform 2 weekly backups with light supervision
- [ ] Read monthly update runbook
- [ ] Read emergency restart runbook
- [ ] Read troubleshooting guide

### Week 4: Independent Operations
- [ ] Perform weekly backup independently
- [ ] Complete operator knowledge check
- [ ] Added to on-call rotation
- [ ] Know when and how to escalate

---

## Quick Reference Card

Print this and keep it handy:

```
ANSIBLE LOG ANALYTICS - QUICK REFERENCE

Directory: /opt/ansible/fluffy-potato

STATUS (Safe - Read Only):
  ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status

STOP (Maintenance Only):
  ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop

START (After Maintenance):
  ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start

TROUBLESHOOTING:
  Service logs:  ssh app-01 "tail -100 /var/log/app/app.log"
  Queue status:  ssh queue-01 "ls -lht /tmp/*.lock | head"
  Process list:  ssh app-01 "ps aux | grep foo"

ESCALATION:
  Urgent:   PagerDuty + Slack #incidents
  Normal:   Slack #platform-ops
  Help:     Slack #ops-help

RUNBOOKS: /opt/ansible/fluffy-potato/docs/runbooks/
  - weekly-app-shutdown-for-backup.md
  - monthly-app-update.md
  - emergency-restart.md
  - troubleshooting-common-issues.md

SUCCESS INDICATORS:
  ✅ failed=0 on all hosts
  ✅ Email report received
  ✅ All services "Running: Yes"

FAILURE INDICATORS:
  ❌ failed=1 or higher
  ❌ Task shows "fatal"
  ❌ Timeout without completing

MAINTENANCE WINDOWS:
  Weekly:   Saturday 22:00-23:00 PST
  Monthly:  First Sunday 02:00-04:00 PST
```

---

## Next Steps

1. **Read the weekly backup runbook**: [runbooks/weekly-app-shutdown-for-backup.md](runbooks/weekly-app-shutdown-for-backup.md)

2. **Practice in dev/staging**: Get familiar with the commands

3. **Shadow an experienced operator**: Learn the flow hands-on

4. **Ask questions**: Better to ask than to guess

**Remember**:
- It's OK to not know everything
- Always ask if unsure
- Escalate early if stuck
- Safety first - don't rush

---

**Last Updated**: 2025-12-26
**Questions?**: Ask in Slack #ops-help
**Feedback**: Suggest improvements to this guide
