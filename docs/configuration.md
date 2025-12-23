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
cal_start_expected_rc: 0

cal_stop_expected_rc: 0

cal_status_expected_rc: 0


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
cal_stop_expected_rc: 1  # Non-zero expected
cal_status_expected_rc: 1  # Non-zero expected
```

