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
