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
cal_stop_expected_rc: 1  # Non-zero expected   # stop returns 1 for success
  # status returns 0 for success
```

