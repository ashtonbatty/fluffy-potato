## Examples

### Managing Individual Services

Use the role directly for single service operations:

```yaml
- name: Stop foo service only
  hosts: foo_servers
  gather_facts: false
  vars:
    appname_service_action: "stop"
  roles:
    - appname
```

Variables are automatically loaded from `inventory/group_vars/foo_servers.yml` based on the host group.

### Custom Validation Strings

Override check strings for services with different output:

```yaml
# inventory/group_vars/custom_servers.yml
appname_service_name: "custom"
appname_service_script: "/opt/custom/control.sh"
appname_start_check_string: "Service is starting"
appname_running_check_string: "Service is active"
appname_stop_check_string: "Shutdown initiated"
appname_stopped_check_string: "Service is inactive"
```

### Mixed Return Code Behavior

Different commands may have different RC behaviors:

```yaml
# inventory/group_vars/mixed_servers.yml
appname_service_name: "mixed"
appname_stop_expected_rc: 1  # Non-zero expected - stop returns 1 for success
# start_expected_rc and status_expected_rc use default: 0
```

### Using Service Module Mode (Systemd Services)

For standard systemd services, omit `appname_service_script` to use Ansible's systemd module:

```yaml
# inventory/group_vars/nginx_servers.yml
appname_service_name: "nginx"
# No appname_service_script defined - will use systemd module

# Optional: Enable service at boot
appname_service_enabled: true
```

This is useful for managing standard system services like nginx, postgresql, or any other systemd-managed service without requiring custom control scripts.

### Mixed Environment (Script and Systemd Services)

You can mix script-based and systemd-based services in the same workflow:

```yaml
# inventory/group_vars/custom_app_servers.yml - Script-based service
appname_service_name: "custom_app"
appname_service_script: "/opt/custom/control.sh"
appname_process_identifier: "COMPONENT=custom_app"

# inventory/group_vars/database_servers.yml - Systemd service
appname_service_name: "postgresql"
# No appname_service_script defined
appname_service_enabled: true
```

