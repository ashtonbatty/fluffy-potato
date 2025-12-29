# Troubleshooting Common Issues

## Overview

This guide covers common problems encountered during application service operations and their solutions. Organized by symptom for quick reference during incidents.

---

## Quick Diagnostic Commands

Keep these handy for rapid troubleshooting:

```bash
# Check service status
cd /opt/ansible/fluffy-potato
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status

# Check if hosts are reachable
ansible all -i inventory/hosts -m ping

# Check system resources on all hosts
ansible all -i inventory/hosts -m shell -a "uptime && free -m && df -h / | tail -1"

# Check application logs for errors
ansible all -i inventory/hosts -m shell \
  -a "tail -50 /var/log/app/app.log | grep -i error || echo 'No errors'"

# Check running processes
ansible all -i inventory/hosts -m shell -a "ps aux | grep -E 'foo|bar|elephant' | grep -v grep"
```

---

## Service Start/Stop Issues

### Issue: Service Won't Stop (Graceful Stop Hangs)

**Symptoms**:
- Stop playbook hangs on "Stop service for X"
- Timeout after several retries
- Process still running after stop attempt

**Diagnosis**:

```bash
# Check if process is actually running
ssh app-01 "ps aux | grep foo | grep -v grep"

# Check what the process is doing
ssh app-01 "strace -p [PID]"

# Check if process has open files
ssh app-01 "lsof -p [PID] | head -20"
```

**Common Causes**:

1. **Waiting for in-flight requests**:
   - Normal behavior, wait for timeout
   - Check service logs for graceful shutdown messages

2. **Stuck on database connection**:
   ```bash
   # Check for long-running database queries
   ssh db-coord-01 "psql -U appuser -d analytics -c \"
     SELECT pid, now() - query_start as duration, query
     FROM pg_stat_activity
     WHERE state = 'active'
     ORDER BY duration DESC
     LIMIT 10;
   \""
   ```

3. **Deadlock or infinite loop**:
   - Check CPU usage: `top -b -n 1 | grep foo`
   - May need force kill

**Solutions**:

```bash
# Option 1: Wait longer (increase timeout)
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "appname_script_timeout=1800"

# Option 2: Force kill (if timeout exceeded and safe to kill)
# This is automatically handled if appname_allow_force_kill=true

# Option 3: Manual investigation and kill
ssh app-01 "kill -TERM [PID]"  # Try graceful first
sleep 10
ssh app-01 "kill -KILL [PID]"  # Force if needed
```

### Issue: Service Won't Start

**Symptoms**:
- Start playbook fails with "Service not running after retries"
- Process starts but immediately crashes
- Status check shows "Stopped: Yes" after start attempt

**Diagnosis**:

```bash
# Try manual start to see error
ssh app-01 "/scripts/foo.sh start"

# Check logs immediately after start attempt
ssh app-01 "tail -100 /var/log/app/foo.log"

# Check if port is already in use
ssh app-01 "netstat -tlnp | grep 8080"

# Verify configuration
ssh app-01 "/opt/app/bin/validate-config /opt/app/config/app.yml"
```

**Common Causes & Solutions**:

#### 1. Configuration Error

**Symptom**: Logs show "Invalid configuration" or "Parse error"

```bash
# Validate configuration syntax
ssh app-01 "/opt/app/bin/validate-config /opt/app/config/app.yml"

# Check for recent config changes
ssh app-01 "ls -la /opt/app/config/"

# Compare with working host
diff <(ssh app-01 "cat /opt/app/config/app.yml") \
     <(ssh app-02 "cat /opt/app/config/app.yml")
```

**Solution**: Fix configuration and retry start

#### 2. Port Already in Use

**Symptom**: Logs show "Address already in use" or "bind: Address already in use"

```bash
# Find what's using the port
ssh app-01 "netstat -tlnp | grep 8080"
ssh app-01 "lsof -i :8080"

# Check if it's a stale process from previous run
ssh app-01 "ps aux | grep [PID]"
```

**Solution**:
```bash
# If stale process, kill it
ssh app-01 "kill -9 [PID]"

# If legitimate process, investigate why it's running
```

#### 3. Missing Dependencies

**Symptom**: Logs show "Connection refused" or "Cannot connect to database"

```bash
# Check database connectivity
ssh app-01 "nc -zv db-coord-01 5432"
ssh app-01 "psql -U appuser -h db-coord-01 -d analytics -c 'SELECT 1'"

# Check external API dependencies
ssh app-01 "curl -v http://external-api:8080/health"
```

**Solution**: Ensure dependencies are available before starting service

#### 4. Insufficient Resources

**Symptom**: Service starts but OOM killer terminates it

```bash
# Check memory
ssh app-01 "free -m"

# Check for OOM events
ssh app-01 "dmesg | grep -i 'out of memory'"

# Check disk space
ssh app-01 "df -h"
```

**Solution**:
```bash
# Clear cache if memory low
ssh app-01 "sync && echo 3 > /proc/sys/vm/drop_caches"

# Clean up logs if disk full
ssh app-01 "find /var/log -name '*.log' -mtime +7 -delete"
```

#### 5. Permission Issues

**Symptom**: Logs show "Permission denied"

```bash
# Check file ownership
ssh app-01 "ls -la /opt/app/"
ssh app-01 "ls -la /var/log/app/"
ssh app-01 "ls -la /var/run/app/"

# Check if service user can access files
ssh app-01 "sudo -u appuser ls -la /opt/app/"
```

**Solution**:
```bash
# Fix ownership
ssh app-01 "chown -R appuser:appuser /opt/app/"
ssh app-01 "chown -R appuser:appuser /var/log/app/"
```

### Issue: Service Status Check Fails

**Symptoms**:
- Status playbook returns unexpected output
- Service running but status shows "stopped"
- Status check times out

**Diagnosis**:

```bash
# Run status manually
ssh app-01 "/scripts/foo.sh status"

# Check what the status script looks for
ssh app-01 "cat /scripts/foo.sh | grep -A 10 'status)'"

# Verify process is actually running
ssh app-01 "ps aux | grep foo | grep -v grep"
```

**Common Causes**:

1. **Status script checks wrong PID file**:
   - Verify PID file location matches actual
   - Check if PID file is stale

2. **Status script checks wrong process pattern**:
   - Compare `appname_running_check_string` with actual output
   - Check if output format changed

3. **Status script timeout**:
   - Increase timeout value
   - Check if status command is hanging

**Solution**:

```bash
# Update check strings in group_vars if output changed
# inventory/group_vars/foo_servers.yml
appname_running_check_string: "actual output when running"
appname_stopped_check_string: "actual output when stopped"
```

---

## Queue and File Monitoring Issues

### Issue: Queue Drain Timeout

**Symptoms**:
- "Pipeline queue drain timeout: X files still present"
- Stop workflow fails at file monitoring step
- Queue not processing files

**Diagnosis**:

```bash
# Check how many files are in queue
ssh queue-01 "ls -1 /tmp/*.lock /tmp/*.tmp 2>/dev/null | wc -l"

# Check age of files
ssh queue-01 "ls -lht /tmp/*.lock /tmp/*.tmp 2>/dev/null | head -20"

# Check for processing activity
ssh queue-01 "lsof /tmp/*.processing 2>/dev/null"

# Check queue processing services
ssh queue-01 "ps aux | grep -E 'processor|loader|etl' | grep -v grep"
```

**Common Causes & Solutions**:

#### 1. Old Stuck Files from Previous Runs

**Symptom**: Files older than 1 hour still present

```bash
# Identify old files
ssh queue-01 "find /tmp -name '*.lock' -o -name '*.tmp' | xargs ls -lh"

# Check if files are being accessed
ssh queue-01 "lsof /tmp/*.lock 2>/dev/null"
```

**Solution**:
```bash
# If files > 1 hour old and not being accessed, safe to remove
ssh queue-01 "find /tmp -name '*.lock' -mmin +60 -delete"
ssh queue-01 "find /tmp -name '*.tmp' -mmin +60 -delete"

# Retry stop operation
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

#### 2. Processing Service Still Running

**Symptom**: Files being actively processed, slowly draining

```bash
# Check processor status
ssh queue-01 "ps aux | grep processor"

# Check processing rate
watch -n 5 'ssh queue-01 "ls -1 /tmp/*.processing 2>/dev/null | wc -l"'
```

**Solution**:
```bash
# If draining slowly but making progress, increase timeout
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "appname_file_monitor_timeout=3600"  # 1 hour

# If stuck, stop processor first
ssh queue-01 "/scripts/processor.sh stop"
```

#### 3. Queue Backlog Too Large

**Symptom**: Thousands of files, will take hours to drain

```bash
# Count queue size
ssh queue-01 "ls -1 /tmp/*.lock 2>/dev/null | wc -l"

# Estimate drain time
# (files / processing_rate) = time in seconds
```

**Solution**:

**Option A**: Wait for drain (if time permits)
```bash
# Increase timeout to allow drain
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "appname_file_monitor_timeout=7200"  # 2 hours
```

**Option B**: Skip drain for maintenance (if acceptable)
```bash
# Disable queue monitoring for this run only
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "appname_file_monitor_enabled=false"

# Note: Files will remain in queue, processing will resume after restart
```

**Option C**: Manual intervention (emergencies only)
```bash
# Move files to backup location for later processing
ssh queue-01 "mkdir -p /backup/queue/$(date +%Y%m%d)"
ssh queue-01 "mv /tmp/*.lock /tmp/*.tmp /backup/queue/$(date +%Y%m%d)/"

# Process backup queue after maintenance
```

#### 4. Misconfigured File Patterns

**Symptom**: Files present but monitoring says queue is empty

**Diagnosis**:
```bash
# Check actual file patterns in queue
ssh queue-01 "ls -1 /tmp/ | grep -E '\.(lock|tmp|processing)$'"

# Compare with configured patterns
grep appname_file_monitor_patterns inventory/group_vars/queue_servers.yml
```

**Solution**: Update patterns to match actual files
```yaml
# inventory/group_vars/queue_servers.yml
appname_file_monitor_patterns:
  - "*.lock"
  - "*.tmp"
  - "*.processing"  # Add missing patterns
```

---

## Email and Reporting Issues

### Issue: Workflow Report Email Not Received

**Symptoms**:
- Playbook completes but no email received
- Email report task shows "changed" but nothing arrives
- Emails go to spam/junk

**Diagnosis**:

```bash
# Check if email is enabled
grep appname_email_enabled inventory/group_vars/all.yml

# Check SMTP configuration
grep -A 6 appname_email inventory/group_vars/all.yml

# Test email manually
ansible localhost -m community.general.mail \
  -a "host=smtp.company.com port=587 from=test@company.com to=your-email@company.com subject='Test' body='Test email'"
```

**Common Causes & Solutions**:

#### 1. SMTP Configuration Incorrect

```bash
# Verify SMTP server is reachable
nc -zv smtp.company.com 587

# Test SMTP authentication (if required)
telnet smtp.company.com 587
```

**Solution**: Update SMTP settings
```yaml
# inventory/group_vars/all.yml
appname_email_smtp_host: "correct-smtp-server.com"
appname_email_smtp_port: 587
appname_email_secure: "try"  # or "always" for TLS
```

#### 2. Email Disabled

```yaml
# Check configuration
grep appname_email_enabled inventory/group_vars/all.yml

# If false, enable it
appname_email_enabled: true
```

#### 3. Incorrect Recipient Address

```bash
# Check recipient configuration
grep appname_email_to inventory/group_vars/all.yml

# Make sure it's not the default example address
# Should NOT be: admin@example.com
```

**Solution**:
```yaml
# inventory/group_vars/all.yml
appname_email_to: "actual-ops-team@yourcompany.com"
```

#### 4. Emails Going to Spam

**Check**:
- Spam/junk folder
- Email filtering rules
- SPF/DKIM records for sender domain

**Solution**:
- Whitelist sender address in email system
- Update email subject prefix for better filtering
```yaml
appname_email_subject_prefix: "[PROD-ANSIBLE]"
```

### Issue: Workflow Report Shows Unexpected Information

**Symptoms**:
- Force kill events not expected
- Task timing seems wrong
- Missing task entries

**This is informational** - workflow reports show what actually happened:

- **Force kill events**: Service didn't stop gracefully, was killed
  - Check service logs to understand why graceful stop failed
  - Consider increasing stop timeout if happening frequently

- **Long task duration**: Tasks took longer than expected
  - Review task timing in report
  - Consider adjusting retry counts or timeouts

- **Missing tasks**: Tasks were skipped
  - Check if idempotency skip occurred (service already in desired state)
  - Review workflow logic for skip conditions

---

## Performance and Resource Issues

### Issue: High Memory Usage

**Symptoms**:
- Services slow or unresponsive
- OOM killer terminates processes
- Swap usage high

**Diagnosis**:

```bash
# Check memory usage on all hosts
ansible all -i inventory/hosts -m shell -a "free -h"

# Check which process is consuming memory
ansible all -i inventory/hosts -m shell \
  -a "ps aux --sort=-%mem | head -10"

# Check for memory leaks (compare over time)
ssh app-01 "ps -p [PID] -o pid,vsz,rss,cmd"
```

**Solutions**:

```bash
# Quick fix: Restart services to reclaim memory
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start

# Clear cache
ansible all -i inventory/hosts -m shell -a "sync && echo 3 > /proc/sys/vm/drop_caches"

# Long-term: Investigate memory leak
# - Collect heap dumps
# - Review application logs
# - Create ticket for dev team
```

### Issue: High CPU Usage

**Symptoms**:
- High load average
- Services slow to respond
- CPU constantly > 80%

**Diagnosis**:

```bash
# Check CPU usage
ansible all -i inventory/hosts -m shell -a "uptime"

# Check which process is consuming CPU
ansible all -i inventory/hosts -m shell \
  -a "ps aux --sort=-%cpu | head -10"

# Check for runaway processes
ssh app-01 "top -b -n 1 | head -20"
```

**Common Causes**:

1. **Infinite loop or deadlock**: Check application logs
2. **Too many requests**: Check request rate in monitoring
3. **Inefficient query**: Check database queries

**Solutions**:

```bash
# Quick fix: Restart affected service
ssh app-01 "/scripts/foo.sh restart"

# Long-term: Optimize code or queries
```

### Issue: Disk Space Full

**Symptoms**:
- "No space left on device" errors
- Services can't write logs
- Services fail to start

**Diagnosis**:

```bash
# Check disk usage on all hosts
ansible all -i inventory/hosts -m shell -a "df -h"

# Find large files
ansible all -i inventory/hosts -m shell \
  -a "du -sh /var/log/* /opt/* /tmp/* 2>/dev/null | sort -h | tail -10"

# Find old logs
ansible all -i inventory/hosts -m shell \
  -a "find /var/log -name '*.log' -mtime +30 -ls"
```

**Solutions**:

```bash
# Clean up old logs (> 30 days)
ansible all -i inventory/hosts -m shell \
  -a "find /var/log -name '*.log' -mtime +30 -delete"

# Compress large logs
ansible all -i inventory/hosts -m shell \
  -a "find /var/log -name '*.log' -size +100M -exec gzip {} \;"

# Clean up temp files
ansible all -i inventory/hosts -m shell \
  -a "find /tmp -type f -mtime +7 -delete"

# Check if logrotate is working
ansible all -i inventory/hosts -m shell -a "systemctl status logrotate"
```

---

## Network and Connectivity Issues

### Issue: Ansible Can't Reach Hosts

**Symptoms**:
- "Host unreachable" errors
- Playbook hangs on connecting
- Ping fails

**Diagnosis**:

```bash
# Test basic connectivity
ansible all -i inventory/hosts -m ping

# Check specific host
ssh app-01 "echo 'connected'"

# Check from control node
ping -c 3 app-01.dc1.example.com
```

**Solutions**:

1. **Host down**: Contact infrastructure team
2. **Network partition**: Check network status
3. **SSH keys**: Verify SSH access
4. **Firewall**: Check firewall rules

### Issue: Service Can't Connect to Database

**Symptoms**:
- "Connection refused" in logs
- Services fail to start
- Timeouts on database queries

**Diagnosis**:

```bash
# Test database connectivity from app server
ssh app-01 "nc -zv db-coord-01 5432"

# Test database login
ssh app-01 "psql -U appuser -h db-coord-01 -d analytics -c 'SELECT 1'"

# Check if database is listening
ssh db-coord-01 "netstat -tlnp | grep 5432"
```

**Solutions**:

```bash
# Verify database is running
ssh db-coord-01 "systemctl status postgresql"

# Check pg_hba.conf allows connections from app servers
ssh db-coord-01 "grep app /var/lib/pgsql/data/pg_hba.conf"

# Verify credentials in application config
ssh app-01 "grep database /opt/app/config/app.yml"
```

---

## Playbook Execution Issues

### Issue: Playbook Hangs

**Symptoms**:
- Playbook doesn't progress
- Stuck on one task for > 5 minutes
- No output or errors

**Quick Fix**:
```bash
# Ctrl+C to abort
# Check what task it hung on
# Run with verbose mode to see details
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status -vvv
```

**Common causes**:
- Task timeout too long
- Waiting for user input (shouldn't happen with these playbooks)
- Network connectivity issue
- Host unresponsive

### Issue: Permission Denied Errors

**Symptoms**:
- "Permission denied" during playbook execution
- Can't write files
- Can't restart services

**Check**:

```bash
# Verify become is configured
grep appname_service_become inventory/group_vars/all.yml

# Test sudo access
ssh app-01 "sudo -l"
```

**Solution**:
```yaml
# Ensure become is enabled in group_vars
appname_service_become: true
appname_service_become_user: "root"
```

---

## Getting Help

### Before Escalating

Collect this information:

1. **What were you trying to do?**
   - Which runbook/procedure?
   - What command did you run?

2. **What happened?**
   - Error messages (exact text)
   - Playbook output (PLAY RECAP)
   - Service status

3. **What have you tried?**
   - Troubleshooting steps from this guide
   - Any manual interventions

4. **Current state**:
   - Are services running or stopped?
   - Is this impacting production?
   - What's the urgency?

### Information to Provide

```bash
# Capture current state
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status > /tmp/status.log 2>&1

# Capture system resources
ansible all -i inventory/hosts -m shell \
  -a "uptime && free -m && df -h" > /tmp/resources.log 2>&1

# Capture recent logs
ansible all -i inventory/hosts -m shell \
  -a "tail -100 /var/log/app/app.log" > /tmp/app-logs.log 2>&1

# Attach these files when escalating
```

### Escalation Channels

- **Urgent (P1/P2)**: PagerDuty + Slack #incidents
- **Normal issues**: Slack #platform-ops
- **Questions**: Slack #ops-help
- **Bugs**: Create ticket in Jira

---

**Last Updated**: 2025-12-26
**Feedback**: Suggest improvements in #ops-docs
