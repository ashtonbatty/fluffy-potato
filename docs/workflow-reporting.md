## Comprehensive Workflow Reporting

**All workflow runs (start, stop, status) send email reports** with comprehensive execution details. This ensures full audit trail and visibility into service management operations.

### What's Included in Every Report

1. **Workflow Metadata**:
   - Workflow type (start/stop)
   - Start and end timestamps
   - Total duration
   - User who initiated the workflow
   - Ansible control node hostname
   - Workflow status (success/failed)

2. **Task Execution Timeline**:
   - Each service/task with start/end times and duration
   - Success/failure status for each task
   - Error messages if tasks failed

3. **Force Kill Events** (stop workflow only):
   - Hostname, service name, timestamp
   - Process identifier used for kill
   - Full `ps aux` output captured before kill

4. **File Monitoring Events** (stop workflow only):
   - Hostname, directory, timeout
   - List of files still present after timeout
   - File details: size, modification time, owner, permissions

5. **Failure Details** (if workflow failed):
   - Which task failed
   - Which service failed
   - Failure timestamp
   - Complete error message and details

### Report Behavior

- **Success**: Email subject starts with `[SUCCESS]`, clean workflow summary
- **Failure**: Email subject starts with `[FAILURE]`, prominent failure notification at top of email body, workflow fails after sending report
- **Always Sent**: Reports are sent for every start/stop workflow run, whether successful or failed

### Force Kill Reporting

When a service fails to stop gracefully and requires force kill:

1. Process details are captured using `ps aux` before the kill
2. The kill event is recorded with hostname, service name, timestamp, process identifier, and ps details
3. Event is included in the comprehensive workflow report

### File Monitoring Feature

During service stop operations, you can configure the framework to wait for specific files to be deleted from a directory. This is useful for ensuring that services have fully cleaned up their temporary files, lock files, or data files before proceeding with the next service stop.

**How It Works:**

1. After stopping the first service (foo), the file monitor checks the configured directory
2. It waits up to `appname_file_monitor_timeout` seconds for matching files to be deleted
3. If files remain after timeout, it gathers hostname, filenames, and file stats (size, timestamp, owner, permissions)
4. Event is recorded and added to the consolidated report (sent at end of workflow)
5. Optionally fails the playbook (controlled by `appname_file_monitor_fail_on_timeout`)

### Configuration Example

```yaml
# Enable file monitoring for cleanup between foo and bar services
appname_file_monitor_enabled: true
appname_file_monitor_path: "/var/app/temp"
appname_file_monitor_patterns:
  - "*.tmp"
  - "*.lock"
  - "*.pid"
appname_file_monitor_timeout: 120
appname_file_monitor_check_interval: 5
appname_file_monitor_fail_on_timeout: false

# Email configuration
appname_email_enabled: true
appname_email_smtp_host: "mail.example.com"
appname_email_smtp_port: 587
appname_email_from: "ansible@myserver.com"
appname_email_to: "ops-team@example.com"
appname_email_subject_prefix: "[Production Alert]"
appname_email_secure: "starttls"
```

### Email Report Format

Every start/stop workflow run sends a comprehensive email report. Example for a successful stop workflow:

```
Subject: [Ansible Alert] [SUCCESS] STOP workflow completed - ansible-control

================================================================================
WORKFLOW REPORT: STOP
================================================================================

Workflow Status: SUCCESS
Workflow Type: stop
Started: 2025-12-23T19:25:00Z
Completed: 2025-12-23T19:27:30Z
Duration: 150 seconds (2.5 minutes)

Initiated By: john.doe
Ansible Control Node: ansible-control

================================================================================
TASK EXECUTION TIMELINE
================================================================================

Service: elephant
Action: stop
Start Time: 2025-12-23T19:25:05Z
End Time: 2025-12-23T19:25:45Z
Status: SUCCESS
Duration: 40 seconds

Service: bar
Action: stop
Start Time: 2025-12-23T19:25:50Z
End Time: 2025-12-23T19:26:20Z
Status: SUCCESS
Duration: 30 seconds

Service: file_monitoring
Action: wait_for_deletion
Start Time: 2025-12-23T19:26:25Z
End Time: 2025-12-23T19:26:30Z
Status: SUCCESS
Duration: 5 seconds

Service: foo
Action: stop
Start Time: 2025-12-23T19:26:35Z
End Time: 2025-12-23T19:27:25Z
Status: SUCCESS
Duration: 50 seconds

================================================================================
FORCE KILL EVENTS (1):
--------------------------------------------------------------------------------

Hostname: webserver01
Service: foo
Timestamp: 2025-12-23T19:27:15Z
Process Identifier: COMPONENT=foo

Process Details (ps aux):
appuser  12345  2.5  1.2 456789 123456 ?  Ssl  19:25   0:15 /usr/bin/foo --config=/etc/foo.conf

================================================================================
FILE MONITORING EVENTS (1):
--------------------------------------------------------------------------------

Hostname: webserver02
Directory: /var/app/temp
Timeout: 120 seconds

Remaining files (2):

File: /var/app/temp/app.lock
  Size: 4096 bytes (0.00 MB)
  Modified: 2025-12-22 19:30:45
  Owner: appuser
  Permissions: 0644

File: /var/app/temp/cache.tmp
  Size: 2048576 bytes (1.95 MB)
  Modified: 2025-12-22 19:32:10
  Owner: appuser
  Permissions: 0644

================================================================================
SUMMARY
================================================================================

Workflow: STOP
Status: SUCCESS
Total Tasks: 4
Successful Tasks: 4
Failed Tasks: 0
Force Kills: 1
File Monitoring Issues: 1

================================================================================
END OF REPORT
================================================================================
```

Example subject line for a failed workflow:
```
Subject: [Ansible Alert] [FAILURE] START workflow completed - ansible-control
```

The email body for failed workflows includes a prominent failure notice at the top with failure details.

### Usage

File monitoring runs automatically during stop operations between foo and bar services when enabled:

```bash
# With file monitoring enabled
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

### Disabling File Monitoring

To skip file monitoring (enabled by default in production), disable it:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml \
  -e service_action=stop \
  -e appname_file_monitor_enabled=false
```

