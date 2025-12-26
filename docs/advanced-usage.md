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

You can override service-specific settings in multiple ways:

**Option 1: Edit the service's group_vars file directly** (recommended for permanent changes):

```yaml
# inventory/group_vars/foo_servers.yml
appname_retry_delay: 10
appname_stop_expected_rc: 1  # Non-zero expected
appname_process_identifier: "java.*custom_pattern"
appname_allow_force_kill: false
```

**Option 2: Use extra-vars file for temporary overrides**:

```yaml
# custom_overrides.yml
appname_retry_delay: 10
appname_stop_expected_rc: 1  # Non-zero expected
appname_process_identifier: "java.*custom_pattern"
appname_allow_force_kill: false
```

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e @custom_overrides.yml
```

**Option 3: Tier-specific overrides** (affects all services on that tier):

```yaml
# inventory/group_vars/db_segs_tier.yml
appname_retry_delay: 10
appname_script_timeout: 600
```

