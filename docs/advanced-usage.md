## Advanced Usage

### Scripts with Backwards Return Codes

Some scripts return non-zero for success and zero for failure:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "cal_stop_expected_rc=1" \
  -e "cal_status_expected_rc=1"
```

### Ignore Return Codes Completely

Only validate via output strings:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start \
  -e "" \
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
cal_stop_expected_rc: 1  # Non-zero expected
cal_process_identifier: "java.*custom_pattern"
cal_allow_force_kill: false
```

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e @custom_foo.yml
```

