# Ansible Role: appname

Ansible role for managing custom services with graceful stop/start operations, configurable return code handling, and automatic fallback to force-kill when graceful shutdown fails.

## Features

- **Dual-Mode Operation**: Support for both custom control scripts and systemd services
- **Graceful Shutdown with Fallback**: Attempts graceful stop, falls back to force-kill if configured
- **Idempotency**: Checks service status before start/stop operations
- **Retry Logic**: Configurable retries with delays for reliability
- **Script Validation**: Pre-flight checks for script existence and executability
- **Security Controls**: Process identifier validation, explicit force-kill permission
- **Return Code Handling**: Support for non-standard return codes
- **Comprehensive Reporting**: Detailed workflow reports with timing and error information

## Requirements

- Ansible >= 2.9
- Python >= 3.6
- Target hosts must have:
  - systemd (for systemd mode)
  - pkill/ps (for script mode with force-kill)

## Role Variables

### Core Configuration

```yaml
# Service identifier (required)
appname_service_name: "myservice"

# Service action to perform (required)
appname_service_action: "start"  # start|stop|status

# Script path for script-based mode (optional)
# Omit this variable to use systemd mode
appname_service_script: "/scripts/myservice.sh"

# Process identifier for force-kill (script mode only)
# Must be >= 5 characters for safety
appname_process_identifier: "COMPONENT=myservice"
```

### Service Mode Variables (systemd only)

```yaml
# Whether to enable service at boot (optional)
appname_service_enabled: true

# Reload systemd daemon before operation (optional)
appname_service_daemon_reload: false
```

### Security & Safety

```yaml
# Enable/disable force-kill fallback
appname_allow_force_kill: true

# Privilege escalation settings
appname_service_become: false
appname_service_become_user: "root"
appname_service_become_flags: ""
```

### Timing Configuration

```yaml
# Retry settings
appname_retry_delay: 3
appname_start_retries: 3
appname_stop_retries: 3
appname_stop_kill_retries: 2

# Wait time after force kill
appname_post_kill_wait_seconds: 3

# Script execution timeout
appname_script_timeout: 300
```

### Return Code Configuration

```yaml
# Expected return codes (set to null to skip checking)
appname_start_expected_rc: 0
appname_stop_expected_rc: 0
appname_status_expected_rc: 0
```

### Email Reporting

```yaml
# Email notification settings
appname_email_enabled: true
appname_email_smtp_host: "localhost"
appname_email_smtp_port: 25
appname_email_from: "ansible@{{ inventory_hostname }}"
appname_email_to: "admin@example.com"
appname_email_subject_prefix: "[Ansible Alert]"
appname_email_secure: "never"
```

## Dependencies

None.

## Example Playbook

### Script-Based Service

```yaml
- name: Manage custom service with script
  hosts: app_servers
  vars:
    appname_service_name: "myapp"
    appname_service_script: "/opt/myapp/control.sh"
    appname_process_identifier: "java.*myapp"
    appname_service_action: "start"
    appname_allow_force_kill: true
  roles:
    - appname
```

### Systemd Service

```yaml
- name: Manage systemd service
  hosts: app_servers
  vars:
    appname_service_name: "nginx"
    appname_service_action: "restart"
    appname_service_enabled: true
  roles:
    - appname
```

### Custom Return Codes

```yaml
- name: Service with non-standard return code
  hosts: legacy_servers
  vars:
    appname_service_name: "legacy-app"
    appname_service_script: "/scripts/legacy.sh"
    appname_stop_expected_rc: 1  # This service returns 1 on successful stop
    appname_service_action: "stop"
  roles:
    - appname
```

## Testing

The role includes Molecule tests for both script-based and systemd modes:

```bash
cd roles/appname
molecule test
```

See `molecule/default/README.md` for more testing details.

## License

MIT

## Author Information

Created for managing complex service dependencies and lifecycle requirements.
