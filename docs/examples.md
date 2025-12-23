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
    appname_service_action: "stop"
  roles:
    - appname
```

### Custom Validation Strings

Override check strings for services with different output:

```yaml
# vars/custom.yml
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
# vars/mixed.yml
appname_service_name: "mixed"
appname_stop_expected_rc: 1  # Non-zero expected   # stop returns 1 for success
  # status returns 0 for success
```

### Using Service Module Mode (Systemd Services)

For standard systemd services, omit `appname_service_script` to use Ansible's systemd module:

```yaml
# vars/nginx.yml
appname_service_name: "nginx"
# No appname_service_script defined - will use systemd module
inventory_group: "webservers"

# Optional: Enable service at boot
appname_service_enabled: true
```

This is useful for managing standard system services like nginx, postgresql, or any other systemd-managed service without requiring custom control scripts.

### Mixed Environment (Script and Systemd Services)

You can mix script-based and systemd-based services in the same workflow:

```yaml
# vars/custom_app.yml - Script-based service
appname_service_name: "custom_app"
appname_service_script: "/opt/custom/control.sh"
appname_process_identifier: "COMPONENT=custom_app"
inventory_group: "app_servers"

# vars/database.yml - Systemd service
appname_service_name: "postgresql"
# No appname_service_script defined
inventory_group: "db_servers"
appname_service_enabled: true
```

