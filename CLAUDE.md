# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible framework for managing custom services with graceful stop/start operations, configurable return code handling, and automatic fallback to force-kill when graceful shutdown fails. Includes idempotency checks, retry logic, and script validation.

## Common Commands

```bash
# Run unified orchestration playbook
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status

# Override variables at runtime
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "wait_seconds=30"
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "stop_expect_zero_rc=false"

# Syntax check
ansible-playbook --syntax-check orchestrate.yml
```

## Architecture

### service_manager Role

Central role in `roles/service_manager/` that handles all service operations:
- `tasks/main.yml` - Script validation + routes to action-specific task file
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

Each service has a vars file in `vars/` with:
- `service_name` - Service identifier
- `service_script` - Path to control script
- `process_identifier` - Pattern for pkill fallback (properly quoted for security)
- `inventory_group` - Target host group

Central registry in `vars/services.yml` documents all services.

### Key Features

- **Idempotency**: Skip start if running, skip stop if stopped
- **Retry Logic**: Status checks retry up to 3 times with delays
- **Script Validation**: Pre-flight check for existence and execute permission
- **Security**: `process_identifier` properly quoted in pkill command

### Return Code Handling

Scripts with non-standard return codes are supported via:
- `*_check_rc: false` - Disable RC validation entirely
- `*_expect_zero_rc: false` - Invert logic (non-zero = success)

Applies to: `start_check_rc`, `stop_check_rc`, `status_check_rc`

## Adding a New Service

1. Create `vars/newservice.yml` with service configuration
2. Add `[newservice_servers]` group to `inventory/hosts`
3. Add a new play to `orchestrate.yml` targeting the new group
4. Update `vars/services.yml` registry for documentation
