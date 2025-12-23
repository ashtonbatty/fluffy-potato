## Advanced Usage

### Scripts with Backwards Return Codes

Some scripts return non-zero for success and zero for failure:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "appname_stop_expected_rc=1" \
  -e "appname_status_expected_rc=1"
```

### Ignore Return Codes Completely

Only validate via output strings:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start \
  -e "" \
  -e "appname_status_check_rc=false"
```

### Disable Force Kill for Safety

Prevent automatic pkill fallback:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "appname_allow_force_kill=false"
```

### Override Per Service

Use extra-vars files for complex overrides:

```yaml
# custom_foo.yml
appname_retry_delay: 10
appname_stop_expected_rc: 1  # Non-zero expected
appname_process_identifier: "java.*custom_pattern"
appname_allow_force_kill: false
```

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e @custom_foo.yml
```

