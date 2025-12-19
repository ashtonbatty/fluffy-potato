# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible framework for managing custom services with graceful stop/start operations, configurable return code handling, and automatic fallback to force-kill when graceful shutdown fails. Includes idempotency checks, retry logic, script validation, and security controls.

## Common Commands

```bash
# Run unified orchestration playbook
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status

# Override role variables at runtime (note: cal_role_ prefix required)
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "cal_role_post_kill_wait_seconds=10"
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "cal_role_stop_expect_zero_rc=false"

# Disable force kill for safety
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "cal_role_allow_force_kill=false"

# Syntax check
ansible-playbook --syntax-check orchestrate.yml
```

## Architecture

### cal_role Role

Central role in `roles/cal_role/` that handles all service operations:
- `tasks/main.yml` - Input validation + script validation + routes to action-specific task file
- `tasks/start.yml` - Idempotent start with retry logic for status verification
- `tasks/stop.yml` - Block-rescue pattern: idempotent graceful stop with retries, fallback to `pkill -9`
- `tasks/status.yml` - Check and display service status
- `defaults/main.yml` - All configurable variables with defaults
- `meta/main.yml` - Role metadata for Ansible Galaxy

### Unified Orchestration

`orchestrate.yml` - Single playbook for all operations with `service_action` parameter:
1. Targets each service's inventory group in order
2. Loads service vars from `vars/{service}.yml`
3. Invokes the role with the specified action

Services execute in defined order (foo → bar → elephant).

### Service Configuration

Each service has a vars file in `vars/` with cal_role_ prefixed variables:
- `cal_role_service_name` - Service identifier
- `cal_role_service_script` - Path to control script
- `cal_role_process_identifier` - Pattern for pkill fallback (must be >= 5 chars, properly quoted for security)
- `inventory_group` - Target host group (not prefixed, used by orchestration)

Central registry in `vars/services.yml` documents all services.

### Key Features

- **Input Validation**: Service action restricted to [start, stop, status] to prevent path traversal
- **Idempotency**: Skip start if running, skip stop if stopped
- **Retry Logic**: Status checks retry up to 3 times with delays
- **Script Validation**: Pre-flight check for existence and execute permission
- **Security Controls**:
  - `cal_role_allow_force_kill` - Explicit boolean to enable/disable pkill fallback (default: true)
  - `cal_role_process_identifier` - Validated for length >= 5 chars to ensure specificity
  - Process identifier properly quoted in pkill command to prevent injection

### Return Code Handling

Scripts with non-standard return codes are supported via:
- `cal_role_*_check_rc: false` - Disable RC validation entirely
- `cal_role_*_expect_zero_rc: false` - Invert logic (non-zero = success)

Applies to: `cal_role_start_check_rc`, `cal_role_stop_check_rc`, `cal_role_status_check_rc`

## Adding a New Service

1. Create `vars/newservice.yml` with service configuration (using `cal_role_` prefix):
   ```yaml
   cal_role_service_name: "newservice"
   cal_role_service_script: "/scripts/newservice.sh"
   cal_role_process_identifier: "COMPONENT=newservice"
   inventory_group: "newservice_servers"
   ```
2. Add `[newservice_servers]` group to `inventory/hosts`
3. Add a new play to `orchestrate.yml` targeting the new group
4. Update `vars/services.yml` registry for documentation
