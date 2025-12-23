# Ansible Service Manager

A flexible, DRY Ansible framework for managing custom services with advanced control over stop/start operations, return code handling, and graceful shutdown with fallback kill mechanisms.

## Features

- **Graceful Service Management**: Stop services with automatic fallback to force-kill if graceful shutdown fails
- **Comprehensive Workflow Reporting**: Email reports for ALL start/stop runs with timing, user, host, task details, force kills, file monitoring, and failure information
- **Separate Start/Stop Workflows**: Different service ordering - Start: foo → bar → elephant, Stop: elephant → bar → foo
- **File Deletion Monitoring**: Wait for files to be deleted during stop operations with timeout tracking
- **Security Controls**: Input validation, force-kill toggle, process identifier length validation
- **Flexible Return Code Handling**: Support for scripts with non-standard return codes (backwards RC logic)
- **Configurable Validation**: Validate operations via output strings, return codes, or both
- **DRY Architecture**: Service-specific configurations in separate files, unified orchestration playbook
- **Ordered Execution**: Services start/stop in defined order across inventory groups
- **Block-Rescue Pattern**: Automatic fallback to process kill if graceful stop fails
- **Idempotency**: Skip operations if service already in desired state
- **Retry Logic**: Automatic retries with configurable delays for status verification
- **Script Validation**: Pre-flight checks for script existence and permissions

## Directory Structure

```
ansible-cal/
├── README.md
├── LICENSE                            # MIT License
├── .gitignore                         # Ignore .ansible/ artifacts
├── .yamllint                          # YAML lint configuration
├── orchestrate.yml                    # Router playbook - routes to start/stop/status workflows
├── .github/workflows/
│   └── lint.yml                       # CI: ansible-lint + yamllint
├── playbooks/
│   ├── cal_start.yml                  # Start workflow (foo -> bar -> elephant)
│   ├── cal_stop.yml                   # Stop workflow (elephant -> bar -> foo)
│   └── cal_status.yml                 # Status workflow (foo -> bar -> elephant)
├── inventory/
│   └── hosts                          # Inventory with service groups
├── vars/
│   ├── services.yml                   # Central services registry
│   ├── foo.yml                        # Foo service configuration
│   ├── bar.yml                        # Bar service configuration
│   └── elephant.yml                   # Elephant service configuration
└── roles/
    └── cal/
        ├── defaults/
        │   └── main.yml               # Default variables
        ├── meta/
        │   └── main.yml               # Role metadata
        └── tasks/
            ├── main.yml                       # Input validation + script validation + task router
            ├── start.yml                      # Start with idempotency + retries
            ├── stop.yml                       # Stop with block-rescue + force-kill fallback + event tracking
            ├── status.yml                     # Status check
            ├── wait_for_files_deleted.yml     # File deletion monitoring with event recording
            └── send_workflow_report.yml       # Comprehensive workflow reporting (all runs)
```

## Prerequisites

- Ansible 2.9 or higher
- Service control scripts (e.g., `/scripts/foo.sh`, `/scripts/bar.sh`)
- Sufficient permissions to kill processes (for force-kill fallback)

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts` to specify which hosts run each service:

```ini
[foo_servers]
host1.example.com
host2.example.com

[bar_servers]
host3.example.com

[elephant_servers]
host4.example.com

[all_services:children]
foo_servers
bar_servers
elephant_servers
```

### 2. Configure Services

Each service has a vars file in `vars/` with `cal_` prefixed variables. Example `vars/foo.yml`:

```yaml
cal_service_name: "foo"
cal_service_script: "/scripts/foo.sh"
cal_process_identifier: "COMPONENT=foo"
inventory_group: "foo_servers"
```

### 3. Run Playbooks

All operations use the unified `orchestrate.yml` playbook with a `service_action` parameter. The playbook routes to different workflows based on the action:

**Start all services** (order: foo → bar → elephant):
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

**Stop all services** (order: elephant → bar → foo):
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

**Check service status** (order: foo → bar → elephant):
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

**Note**:
- Start and stop workflows execute services in opposite orders
- Stop workflow includes file monitoring between services
- All workflows (start, stop, status) send comprehensive email reports with timing, force kill events, file monitoring events, and failure details (if any)

## Configuration

### Role Defaults

All configurable options are in `roles/cal/defaults/main.yml`:

```yaml
# Service configuration
cal_service_name: "myservice"
cal_service_script: "/scripts/{{ cal_service_name }}.sh"
cal_process_identifier: "COMPONENT={{ cal_service_name }}"

# Privilege escalation for service operations
cal_service_become: false
cal_service_become_user: "root"
cal_service_become_flags: ""

# String validation for commands
cal_start_check_string: "starting"
cal_stop_check_string: "stopping"
cal_running_check_string: "running"
cal_stopped_check_string: "stopped"

# Force kill configuration
cal_allow_force_kill: true

# Timing configuration
cal_post_kill_wait_seconds: 3
cal_retry_delay: 3
cal_start_retries: 3
cal_stop_retries: 3
cal_stop_kill_retries: 2
cal_script_timeout: 300

# Return code configuration
cal_start_check_rc: true
cal_start_expect_zero_rc: true
cal_stop_check_rc: true
cal_stop_expect_zero_rc: true
cal_status_check_rc: true
cal_status_expect_zero_rc: true

# Service operation to perform (start, stop, status)
cal_service_action: "status"
```

### Service-Specific Variables

Override defaults in service var files (`vars/*.yml`):

```yaml
cal_service_name: "myservice"
cal_service_script: "/opt/myapp/control.sh"
cal_process_identifier: "java.*myservice"
cal_retry_delay: 5

# For scripts with backwards return codes
cal_stop_expect_zero_rc: false
cal_status_expect_zero_rc: false
```

## Advanced Usage

### Scripts with Backwards Return Codes

Some scripts return non-zero for success and zero for failure:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "cal_stop_expect_zero_rc=false" \
  -e "cal_status_expect_zero_rc=false"
```

### Ignore Return Codes Completely

Only validate via output strings:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start \
  -e "cal_start_check_rc=false" \
  -e "cal_status_check_rc=false"
```

### Disable Force Kill for Safety

Prevent automatic pkill fallback:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "cal_allow_force_kill=false"
```

### Override Per Service

Use extra-vars files for complex overrides:

```yaml
# custom_foo.yml
cal_retry_delay: 10
cal_stop_expect_zero_rc: false
cal_process_identifier: "java.*custom_pattern"
cal_allow_force_kill: false
```

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e @custom_foo.yml
```

## How It Works

### Pre-flight Validation

Before any operation, the role validates:
1. **Service action**: Must be one of [start, stop, status] to prevent path traversal
2. **Service script**: Exists at specified path
3. **Service script**: Has execute permission

### Start Operation

1. **Idempotency check**: Skip if service already running
2. Execute `cal_service_script start`
3. Validate output contains `cal_start_check_string` ("starting")
4. Validate return code (if `cal_start_check_rc` is true)
5. **Retry loop**: Check status up to 3 times with `cal_retry_delay` between attempts
6. Validate output contains `cal_running_check_string` ("running")

### Stop Operation (Block-Rescue Pattern)

**Pre-check:**
1. **Idempotency check**: Skip if service already stopped

**Block (graceful stop):**
1. Execute `cal_service_script stop`
2. Validate output contains `cal_stop_check_string` ("stopping")
3. **Retry loop**: Check status up to 3 times with `cal_retry_delay` between attempts
4. Validate output contains `cal_stopped_check_string` ("stopped")

**Rescue (force kill - if block fails and `cal_allow_force_kill` is true):**
1. **Validate**: Assert `cal_allow_force_kill` is true
2. **Validate**: Assert `cal_process_identifier` is >= 5 characters (specificity check)
3. Log failure message
4. Execute `pkill -9 -f -- "{{ cal_process_identifier }}"` (properly quoted for security)
5. Wait `cal_post_kill_wait_seconds`
6. **Retry loop**: Verify service stopped with 2 retries
7. Validate service is stopped

### Status Check

1. Execute `cal_service_script status`
2. Display full status output
3. Show return code
4. Indicate if service is running or stopped

## Adding New Services

1. **Create vars file** (`vars/newservice.yml`):
   ```yaml
   cal_service_name: "newservice"
   cal_service_script: "/scripts/newservice.sh"
   cal_process_identifier: "COMPONENT=newservice"
   inventory_group: "newservice_servers"
   ```

2. **Add inventory group** (`inventory/hosts`):
   ```ini
   [newservice_servers]
   host5.example.com
   ```

3. **Add play to orchestrate.yml**:
   ```yaml
   - name: "Newservice service - {{ service_action | default('status') | capitalize }}"
     hosts: newservice_servers
     gather_facts: false
     vars_files:
       - vars/newservice.yml
     vars:
       cal_service_action: "{{ service_action | default('status') }}"
     roles:
       - cal
   ```

4. **Update services registry** (`vars/services.yml`) for documentation:
   ```yaml
   newservice:
     group: newservice_servers
     vars_file: vars/newservice.yml
     order: 4
   ```

## Troubleshooting

### Service won't stop gracefully

Check the stop check string matches your script output:
```bash
/scripts/foo.sh stop
# Should output something containing "stopping"
```

Adjust `cal_stop_check_string` in vars file if needed.

### Return code validation failing

Your script may have non-standard return codes. Either:
- Disable RC checking: `cal_stop_check_rc: false`
- Invert RC logic: `cal_stop_expect_zero_rc: false`

### Process kill not working

Verify `cal_process_identifier` matches your running process:
```bash
ps aux | grep "COMPONENT=foo"
```

Adjust `cal_process_identifier` in vars file if needed.

**IMPORTANT - Test Process Kill Patterns Before Production:**

Before enabling force kill in production, **always test your process identifier pattern** to ensure it only matches intended processes:

```bash
# 1. List all processes that match your pattern
pgrep -af "COMPONENT=foo"

# 2. Verify ONLY your service processes are listed
# If other processes appear, make your pattern more specific

# 3. Test with pkill dry-run (list what would be killed)
pkill -9 -f --list-name "COMPONENT=foo"

# 4. Double-check by running your status check
/scripts/foo.sh status
```

If your pattern is too broad, you risk killing unrelated processes. Use specific identifiers like:
- ✅ Good: `"COMPONENT=myservice"` (15+ chars, unique to your service)
- ✅ Good: `"java.*com.example.MyService"` (full class name)
- ❌ Bad: `"foo"` (too short, too generic)
- ❌ Bad: `"python"` (would kill ALL Python processes)

Consider testing in a non-production environment first, or disable force kill initially with `cal_allow_force_kill: false` until patterns are validated.

### Force kill is disabled

If you see an assertion failure about force kill being disabled:
- Either fix the service script so it stops gracefully
- Or explicitly enable force kill: `cal_allow_force_kill: true`

### Process identifier too short

If you see a validation error about process identifier length:
- Use a more specific identifier (>= 5 characters)
- Example: "COMPONENT=foo" instead of "foo"

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
2. It waits up to `cal_file_monitor_timeout` seconds for matching files to be deleted
3. If files remain after timeout, it gathers hostname, filenames, and file stats (size, timestamp, owner, permissions)
4. Event is recorded and added to the consolidated report (sent at end of workflow)
5. Optionally fails the playbook (controlled by `cal_file_monitor_fail_on_timeout`)

### Configuration Example

```yaml
# Enable file monitoring for cleanup between foo and bar services
cal_file_monitor_enabled: true
cal_file_monitor_path: "/var/app/temp"
cal_file_monitor_patterns:
  - "*.tmp"
  - "*.lock"
  - "*.pid"
cal_file_monitor_timeout: 120
cal_file_monitor_check_interval: 5
cal_file_monitor_fail_on_timeout: false

# Email configuration
cal_email_enabled: true
cal_email_smtp_host: "mail.example.com"
cal_email_smtp_port: 587
cal_email_from: "ansible@myserver.com"
cal_email_to: "ops-team@example.com"
cal_email_subject_prefix: "[Production Alert]"
cal_email_secure: "starttls"
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
  -e cal_file_monitor_enabled=false
```

## Examples

### Managing Individual Services

Use the role directly for single service operations:

```yaml
- name: Stop foo service only
  hosts: foo_servers
  gather_facts: false
  vars_files:
    - vars/foo.yml
  vars:
    cal_service_action: "stop"
  roles:
    - cal
```

### Custom Validation Strings

Override check strings for services with different output:

```yaml
# vars/custom.yml
cal_service_name: "custom"
cal_service_script: "/opt/custom/control.sh"
cal_start_check_string: "Service is starting"
cal_running_check_string: "Service is active"
cal_stop_check_string: "Shutdown initiated"
cal_stopped_check_string: "Service is inactive"
```

### Mixed Return Code Behavior

Different commands may have different RC behaviors:

```yaml
# vars/mixed.yml
cal_service_name: "mixed"
cal_stop_expect_zero_rc: false   # stop returns 1 for success
cal_status_expect_zero_rc: true  # status returns 0 for success
```

## Configuration Variables Reference

### Timing & Retry Configuration

- `cal_post_kill_wait_seconds` (default: 3) - Seconds to wait after force kill before verification
- `cal_retry_delay` (default: 3) - Seconds between retry attempts
- `cal_start_retries` (default: 3) - Number of retries for start status verification
- `cal_stop_retries` (default: 3) - Number of retries for graceful stop verification
- `cal_stop_kill_retries` (default: 2) - Number of retries after force kill
- `cal_script_timeout` (default: 300) - Maximum seconds for any script execution before timeout

Adjust these based on your service's startup/shutdown characteristics. Services that take longer to start/stop should have higher retry counts and delays.

### File Monitoring Configuration

- `cal_file_monitor_enabled` (default: false) - Enable file deletion monitoring
- `cal_file_monitor_path` (default: "/tmp") - Directory path to monitor
- `cal_file_monitor_patterns` (default: ["*.tmp", "*.lock"]) - List of file patterns to monitor
- `cal_file_monitor_timeout` (default: 300) - Maximum seconds to wait for file deletion
- `cal_file_monitor_check_interval` (default: 5) - Seconds between file checks
- `cal_file_monitor_fail_on_timeout` (default: true) - Fail playbook if files remain after timeout

### Email Notification Configuration

- `cal_email_enabled` (default: true) - Enable email notifications
- `cal_email_smtp_host` (default: "localhost") - SMTP server hostname
- `cal_email_smtp_port` (default: 25) - SMTP server port
- `cal_email_from` (default: "ansible@{{ inventory_hostname }}") - From email address
- `cal_email_to` (default: "admin@example.com") - To email address
- `cal_email_subject_prefix` (default: "[Ansible Alert]") - Email subject prefix
- `cal_email_secure` (default: "never") - Email security (never/try/always)

## Security Considerations

1. **Input Validation**: Service action is validated against a whitelist [start, stop, status] to prevent path traversal attacks
2. **Force Kill Control**: `cal_allow_force_kill` boolean provides explicit opt-in for dangerous pkill operations
3. **Process Identifier Validation**: Enforces minimum 5-character length to prevent accidentally killing wrong processes
4. **Shell Injection Protection**: Process identifier is properly quoted with Ansible's `quote` filter
5. **Privilege Escalation**: Explicit become controls (`cal_service_become`) with user and flags configuration
6. **Script Timeout**: All script executions have configurable timeout (`cal_script_timeout`) to prevent hung processes from blocking playbooks indefinitely

## Best Practices

1. **Test service scripts independently** before using with Ansible
2. **Verify check strings** match actual script output
3. **Set appropriate timeouts** for your service startup/shutdown times
4. **Use specific process identifiers** (>= 5 chars) to avoid killing wrong processes
5. **Keep service vars files in version control** for reproducibility
6. **Document custom configurations** in service-specific README files
7. **Disable force kill in production** unless absolutely necessary (`cal_allow_force_kill: false`)
8. **Run ansible-lint** before committing changes to catch issues early

## Development

### Running Linters

```bash
# Run ansible-lint
ansible-lint

# Run yamllint
yamllint .
```

### CI/CD

GitHub Actions workflow automatically runs linters on push/PR to main branch.

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

When adding new services or features:
1. Maintain the DRY principle
2. Keep service-specific config in vars files
3. Use `cal_` prefix for all role variables
4. Update this README with new features
5. Run `ansible-lint` to ensure code quality
6. Test thoroughly before deploying to production
