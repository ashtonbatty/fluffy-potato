# Ansible Service Manager

A flexible, DRY Ansible framework for managing custom services with advanced control over stop/start operations, return code handling, and graceful shutdown with fallback kill mechanisms.

## Features

- **Graceful Service Management**: Stop services with automatic fallback to force-kill if graceful shutdown fails
- **Security Controls**: Input validation, force-kill toggle, process identifier length validation
- **Flexible Return Code Handling**: Support for scripts with non-standard return codes (backwards RC logic)
- **Configurable Validation**: Validate operations via output strings, return codes, or both
- **DRY Architecture**: Service-specific configurations in separate files, unified orchestration playbook
- **Ordered Execution**: Services start/stop in defined order across inventory groups
- **Block-Rescue Pattern**: Automatic fallback to process kill if graceful stop fails
- **Idempotency**: Skip operations if service already in desired state
- **Retry Logic**: Automatic retries with configurable delays for status verification
- **Script Validation**: Pre-flight checks for script existence and permissions

## Directory Structure

```
ansible-cal/
├── README.md
├── LICENSE                            # MIT License
├── .gitignore                         # Ignore .ansible/ artifacts
├── .yamllint                          # YAML lint configuration
├── orchestrate.yml                    # Unified playbook for all operations
├── .github/workflows/
│   └── lint.yml                       # CI: ansible-lint + yamllint
├── inventory/
│   └── hosts                          # Inventory with service groups
├── vars/
│   ├── services.yml                   # Central services registry
│   ├── foo.yml                        # Foo service configuration
│   ├── bar.yml                        # Bar service configuration
│   └── elephant.yml                   # Elephant service configuration
└── roles/
    └── cal_role/
        ├── defaults/
        │   └── main.yml               # Default variables
        ├── meta/
        │   └── main.yml               # Role metadata
        └── tasks/
            ├── main.yml               # Input validation + script validation + task router
            ├── start.yml              # Start with idempotency + retries
            ├── stop.yml               # Stop with block-rescue + force-kill fallback
            └── status.yml             # Status check
```

## Prerequisites

- Ansible 2.9 or higher
- Service control scripts (e.g., `/scripts/foo.sh`, `/scripts/bar.sh`)
- Sufficient permissions to kill processes (for force-kill fallback)

## Quick Start

### 1. Configure Inventory

Edit `inventory/hosts` to specify which hosts run each service:

```ini
[foo_servers]
host1.example.com
host2.example.com

[bar_servers]
host3.example.com

[elephant_servers]
host4.example.com

[all_services:children]
foo_servers
bar_servers
elephant_servers
```

### 2. Configure Services

Each service has a vars file in `vars/` with `cal_role_` prefixed variables. Example `vars/foo.yml`:

```yaml
cal_role_service_name: "foo"
cal_role_service_script: "/scripts/foo.sh"
cal_role_process_identifier: "COMPONENT=foo"
inventory_group: "foo_servers"
```

### 3. Run Playbooks

All operations use the unified `orchestrate.yml` playbook with a `service_action` parameter:

**Start all services:**
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

**Stop all services:**
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

**Check service status:**
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

## Configuration

### Role Defaults

All configurable options are in `roles/cal_role/defaults/main.yml`:

```yaml
# Service configuration
cal_role_service_name: "myservice"
cal_role_service_script: "/scripts/{{ cal_role_service_name }}.sh"
cal_role_process_identifier: "COMPONENT={{ cal_role_service_name }}"

# Privilege escalation for service operations
cal_role_service_become: false
cal_role_service_become_user: "root"
cal_role_service_become_flags: ""

# String validation for commands
cal_role_start_check_string: "starting"
cal_role_stop_check_string: "stopping"
cal_role_running_check_string: "running"
cal_role_stopped_check_string: "stopped"

# Force kill configuration
cal_role_allow_force_kill: true

# Timing configuration
cal_role_post_kill_wait_seconds: 3
cal_role_retry_delay: 3

# Return code configuration
cal_role_start_check_rc: true
cal_role_start_expect_zero_rc: true
cal_role_stop_check_rc: true
cal_role_stop_expect_zero_rc: true
cal_role_status_check_rc: true
cal_role_status_expect_zero_rc: true

# Service operation to perform (start, stop, status)
cal_role_service_action: "status"
```

### Service-Specific Variables

Override defaults in service var files (`vars/*.yml`):

```yaml
cal_role_service_name: "myservice"
cal_role_service_script: "/opt/myapp/control.sh"
cal_role_process_identifier: "java.*myservice"
cal_role_retry_delay: 5

# For scripts with backwards return codes
cal_role_stop_expect_zero_rc: false
cal_role_status_expect_zero_rc: false
```

## Advanced Usage

### Scripts with Backwards Return Codes

Some scripts return non-zero for success and zero for failure:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "cal_role_stop_expect_zero_rc=false" \
  -e "cal_role_status_expect_zero_rc=false"
```

### Ignore Return Codes Completely

Only validate via output strings:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start \
  -e "cal_role_start_check_rc=false" \
  -e "cal_role_status_check_rc=false"
```

### Disable Force Kill for Safety

Prevent automatic pkill fallback:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "cal_role_allow_force_kill=false"
```

### Override Per Service

Use extra-vars files for complex overrides:

```yaml
# custom_foo.yml
cal_role_retry_delay: 10
cal_role_stop_expect_zero_rc: false
cal_role_process_identifier: "java.*custom_pattern"
cal_role_allow_force_kill: false
```

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e @custom_foo.yml
```

## How It Works

### Pre-flight Validation

Before any operation, the role validates:
1. **Service action**: Must be one of [start, stop, status] to prevent path traversal
2. **Service script**: Exists at specified path
3. **Service script**: Has execute permission

### Start Operation

1. **Idempotency check**: Skip if service already running
2. Execute `cal_role_service_script start`
3. Validate output contains `cal_role_start_check_string` ("starting")
4. Validate return code (if `cal_role_start_check_rc` is true)
5. **Retry loop**: Check status up to 3 times with `cal_role_retry_delay` between attempts
6. Validate output contains `cal_role_running_check_string` ("running")

### Stop Operation (Block-Rescue Pattern)

**Pre-check:**
1. **Idempotency check**: Skip if service already stopped

**Block (graceful stop):**
1. Execute `cal_role_service_script stop`
2. Validate output contains `cal_role_stop_check_string` ("stopping")
3. **Retry loop**: Check status up to 3 times with `cal_role_retry_delay` between attempts
4. Validate output contains `cal_role_stopped_check_string` ("stopped")

**Rescue (force kill - if block fails and `cal_role_allow_force_kill` is true):**
1. **Validate**: Assert `cal_role_allow_force_kill` is true
2. **Validate**: Assert `cal_role_process_identifier` is >= 5 characters (specificity check)
3. Log failure message
4. Execute `pkill -9 -f -- "{{ cal_role_process_identifier }}"` (properly quoted for security)
5. Wait `cal_role_post_kill_wait_seconds`
6. **Retry loop**: Verify service stopped with 2 retries
7. Validate service is stopped

### Status Check

1. Execute `cal_role_service_script status`
2. Display full status output
3. Show return code
4. Indicate if service is running or stopped

## Adding New Services

1. **Create vars file** (`vars/newservice.yml`):
   ```yaml
   cal_role_service_name: "newservice"
   cal_role_service_script: "/scripts/newservice.sh"
   cal_role_process_identifier: "COMPONENT=newservice"
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
       cal_role_service_action: "{{ service_action | default('status') }}"
     roles:
       - cal_role
   ```

4. **Update services registry** (`vars/services.yml`) for documentation:
   ```yaml
   newservice:
     group: newservice_servers
     vars_file: vars/newservice.yml
     order: 4
   ```

## Troubleshooting

### Service won't stop gracefully

Check the stop check string matches your script output:
```bash
/scripts/foo.sh stop
# Should output something containing "stopping"
```

Adjust `cal_role_stop_check_string` in vars file if needed.

### Return code validation failing

Your script may have non-standard return codes. Either:
- Disable RC checking: `cal_role_stop_check_rc: false`
- Invert RC logic: `cal_role_stop_expect_zero_rc: false`

### Process kill not working

Verify `cal_role_process_identifier` matches your running process:
```bash
ps aux | grep "COMPONENT=foo"
```

Adjust `cal_role_process_identifier` in vars file if needed.

### Force kill is disabled

If you see an assertion failure about force kill being disabled:
- Either fix the service script so it stops gracefully
- Or explicitly enable force kill: `cal_role_allow_force_kill: true`

### Process identifier too short

If you see a validation error about process identifier length:
- Use a more specific identifier (>= 5 characters)
- Example: "COMPONENT=foo" instead of "foo"

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
    cal_role_service_action: "stop"
  roles:
    - cal_role
```

### Custom Validation Strings

Override check strings for services with different output:

```yaml
# vars/custom.yml
cal_role_service_name: "custom"
cal_role_service_script: "/opt/custom/control.sh"
cal_role_start_check_string: "Service is starting"
cal_role_running_check_string: "Service is active"
cal_role_stop_check_string: "Shutdown initiated"
cal_role_stopped_check_string: "Service is inactive"
```

### Mixed Return Code Behavior

Different commands may have different RC behaviors:

```yaml
# vars/mixed.yml
cal_role_service_name: "mixed"
cal_role_stop_expect_zero_rc: false   # stop returns 1 for success
cal_role_status_expect_zero_rc: true  # status returns 0 for success
```

## Security Considerations

1. **Input Validation**: Service action is validated against a whitelist [start, stop, status] to prevent path traversal attacks
2. **Force Kill Control**: `cal_role_allow_force_kill` boolean provides explicit opt-in for dangerous pkill operations
3. **Process Identifier Validation**: Enforces minimum 5-character length to prevent accidentally killing wrong processes
4. **Shell Injection Protection**: Process identifier is properly quoted with Ansible's `quote` filter
5. **Privilege Escalation**: Explicit become controls (`cal_role_service_become`) with user and flags configuration

## Best Practices

1. **Test service scripts independently** before using with Ansible
2. **Verify check strings** match actual script output
3. **Set appropriate timeouts** for your service startup/shutdown times
4. **Use specific process identifiers** (>= 5 chars) to avoid killing wrong processes
5. **Keep service vars files in version control** for reproducibility
6. **Document custom configurations** in service-specific README files
7. **Disable force kill in production** unless absolutely necessary (`cal_role_allow_force_kill: false`)
8. **Run ansible-lint** before committing changes to catch issues early

## Development

### Running Linters

```bash
# Run ansible-lint
ansible-lint

# Run yamllint
yamllint .
```

### CI/CD

GitHub Actions workflow automatically runs linters on push/PR to main branch.

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

When adding new services or features:
1. Maintain the DRY principle
2. Keep service-specific config in vars files
3. Use `cal_role_` prefix for all role variables
4. Update this README with new features
5. Run `ansible-lint` to ensure code quality
6. Test thoroughly before deploying to production
