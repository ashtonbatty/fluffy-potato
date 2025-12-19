# Ansible Service Manager

A flexible, DRY Ansible framework for managing custom services with advanced control over stop/start operations, return code handling, and graceful shutdown with fallback kill mechanisms.

## Features

- **Graceful Service Management**: Stop services with automatic fallback to force-kill if graceful shutdown fails
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
├── orchestrate.yml                    # Unified playbook for all operations
├── inventory/
│   └── hosts                          # Inventory with service groups
├── vars/
│   ├── services.yml                   # Central services registry
│   ├── foo.yml                        # Foo service configuration
│   ├── bar.yml                        # Bar service configuration
│   └── elephant.yml                   # Elephant service configuration
├── roles/
│   └── cal_role/
│       ├── defaults/
│       │   └── main.yml               # Default variables
│       ├── meta/
│       │   └── main.yml               # Role metadata
│       └── tasks/
│           ├── main.yml               # Script validation + task router
│           ├── start.yml              # Start with idempotency + retries
│           ├── stop.yml               # Stop with block-rescue + retries
│           └── status.yml             # Status check
└── stop_foo_service.yml               # Standalone stop playbook (legacy)
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

Each service has a vars file in `vars/`. Example `vars/foo.yml`:

```yaml
service_name: "foo"
service_script: "/scripts/foo.sh"
process_identifier: "COMPONENT=foo"
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
service_name: "myservice"
service_script: "/scripts/{{ service_name }}.sh"
process_identifier: "COMPONENT={{ service_name }}"

# String validation for commands
start_check_string: "starting"
stop_check_string: "stopping"
running_check_string: "running"
stopped_check_string: "stopped"

# Timing configuration
wait_seconds: 10
post_kill_wait_seconds: 3

# Return code configuration
start_check_rc: true
start_expect_zero_rc: true
stop_check_rc: true
stop_expect_zero_rc: true
status_check_rc: true
status_expect_zero_rc: true
```

### Service-Specific Variables

Override defaults in service var files (`vars/*.yml`):

```yaml
service_name: "myservice"
service_script: "/opt/myapp/control.sh"
process_identifier: "java.*myservice"
wait_seconds: 15

# For scripts with backwards return codes
stop_expect_zero_rc: false
status_expect_zero_rc: false
```

## Advanced Usage

### Scripts with Backwards Return Codes

Some scripts return non-zero for success and zero for failure:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e "stop_expect_zero_rc=false" \
  -e "status_expect_zero_rc=false"
```

### Ignore Return Codes Completely

Only validate via output strings:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start \
  -e "start_check_rc=false" \
  -e "status_check_rc=false"
```

### Custom Timing

Adjust wait times for slow-starting services:

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start \
  -e "wait_seconds=30"
```

### Override Per Service

Use extra-vars files for complex overrides:

```yaml
# custom_foo.yml
wait_seconds: 20
stop_expect_zero_rc: false
process_identifier: "java.*custom_pattern"
```

```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop \
  -e @custom_foo.yml
```

## How It Works

### Pre-flight Validation

Before any operation, the role validates:
1. Service script exists at specified path
2. Service script has execute permission

### Start Operation

1. **Idempotency check**: Skip if service already running
2. Execute `service_script start`
3. Validate output contains `start_check_string` ("starting")
4. Validate return code (if `start_check_rc` is true)
5. **Retry loop**: Check status up to 3 times with delays
6. Validate output contains `running_check_string` ("running")

### Stop Operation (Block-Rescue Pattern)

**Pre-check:**
1. **Idempotency check**: Skip if service already stopped

**Block (graceful stop):**
1. Execute `service_script stop`
2. Validate output contains `stop_check_string` ("stopping")
3. **Retry loop**: Check status up to 3 times with delays
4. Validate output contains `stopped_check_string` ("stopped")

**Rescue (force kill - if block fails):**
1. Log failure message
2. Execute `pkill -9 -f "process_identifier"` (properly quoted for security)
3. Wait `post_kill_wait_seconds`
4. **Retry loop**: Verify service stopped with retries
5. Validate service is stopped

### Status Check

1. Execute `service_script status`
2. Display full status output
3. Show return code
4. Indicate if service is running or stopped

## Adding New Services

1. **Create vars file** (`vars/newservice.yml`):
   ```yaml
   service_name: "newservice"
   service_script: "/scripts/newservice.sh"
   process_identifier: "COMPONENT=newservice"
   inventory_group: "newservice_servers"
   ```

2. **Add inventory group** (`inventory/hosts`):
   ```ini
   [newservice_servers]
   host5.example.com
   ```

3. **Add play to orchestrate.yml**:
   ```yaml
   - name: "{{ service_action | capitalize }} newservice service"
     hosts: newservice_servers
     gather_facts: false
     vars_files:
       - vars/newservice.yml
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

Adjust `stop_check_string` in vars file if needed.

### Return code validation failing

Your script may have non-standard return codes. Either:
- Disable RC checking: `stop_check_rc: false`
- Invert RC logic: `stop_expect_zero_rc: false`

### Process kill not working

Verify `process_identifier` matches your running process:
```bash
ps aux | grep "COMPONENT=foo"
```

Adjust `process_identifier` in vars file if needed.

### Service starts too slowly

Increase wait time:
```yaml
wait_seconds: 30
```

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
    service_action: "stop"
  roles:
    - cal_role
```

### Custom Validation Strings

Override check strings for services with different output:

```yaml
# vars/custom.yml
service_name: "custom"
service_script: "/opt/custom/control.sh"
start_check_string: "Service is starting"
running_check_string: "Service is active"
stop_check_string: "Shutdown initiated"
stopped_check_string: "Service is inactive"
```

### Mixed Return Code Behavior

Different commands may have different RC behaviors:

```yaml
# vars/mixed.yml
service_name: "mixed"
stop_expect_zero_rc: false   # stop returns 1 for success
status_expect_zero_rc: true  # status returns 0 for success
```

## Best Practices

1. **Test service scripts independently** before using with Ansible
2. **Verify check strings** match actual script output
3. **Set appropriate timeouts** for your service startup/shutdown times
4. **Use specific process identifiers** to avoid killing wrong processes
5. **Keep service vars files in version control** for reproducibility
6. **Document custom configurations** in service-specific README files

## License

This project is provided as-is for internal use.

## Contributing

When adding new services or features:
1. Maintain the DRY principle
2. Keep service-specific config in vars files
3. Update this README with new features
4. Test thoroughly before deploying to production
