## Configuration

### Role Defaults

All configurable options are in `roles/appname/defaults/main.yml`:

```yaml
# Service configuration
appname_service_name: "myservice"
appname_service_script: "/scripts/{{ appname_service_name }}.sh"
appname_process_identifier: "COMPONENT={{ appname_service_name }}"

# Privilege escalation for service operations
appname_service_become: false
appname_service_become_user: "root"
appname_service_become_flags: ""

# String validation for commands
appname_start_check_string: "starting"
appname_stop_check_string: "stopping"
appname_running_check_string: "running"
appname_stopped_check_string: "stopped"

# Force kill configuration
appname_allow_force_kill: true

# Timing configuration
appname_post_kill_wait_seconds: 3
appname_retry_delay: 3
appname_start_retries: 3
appname_stop_retries: 3
appname_stop_kill_retries: 2
appname_script_timeout: 300

# Return code configuration
appname_start_expected_rc: 0

appname_stop_expected_rc: 0

appname_status_expected_rc: 0


# Service operation to perform (start, stop, status)
appname_service_action: "status"
```

### Service Control Modes

The role supports two modes of operation:

#### Script-Based Mode (Default)

When `appname_service_script` is defined, the role uses custom control scripts:

```yaml
appname_service_name: "myservice"
appname_service_script: "/opt/myapp/control.sh"
appname_process_identifier: "java.*myservice"
appname_retry_delay: 5

# For scripts with backwards return codes
appname_stop_expected_rc: 1  # Non-zero expected
appname_status_expected_rc: 1  # Non-zero expected
```

This mode provides:
- Full control over service lifecycle via custom scripts
- Output string validation
- Return code validation
- Automatic fallback to force kill if graceful stop fails

#### Service Module Mode

When `appname_service_script` is **not defined**, the role uses Ansible's systemd module:

```yaml
appname_service_name: "myservice"
# appname_service_script not defined - will use systemd module

# Optional service module configuration
appname_service_enabled: true  # Enable service at boot
appname_service_daemon_reload: false  # Reload systemd daemon
```

This mode provides:
- Standard systemd service management
- No custom scripts required
- Automatic idempotency
- Works with any systemd-managed service

**To use service module mode**, simply omit the `appname_service_script` variable in your service vars file.

### Service-Specific Variables

Override defaults in service var files (`vars/*.yml`).

