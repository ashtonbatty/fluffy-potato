# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible framework for managing custom services with graceful stop/start operations, configurable return code handling, and automatic fallback to force-kill when graceful shutdown fails. Includes idempotency checks, retry logic, script validation, and security controls. Supports both script-based and systemd service management.

## Common Commands

```bash
# Run unified orchestration playbook
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status

# Override role variables at runtime (note: appname_ prefix)
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "appname_post_kill_wait_seconds=10"
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "appname_stop_expected_rc=1"

# Disable force kill for safety
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop -e "appname_allow_force_kill=false"

# Syntax check
ansible-playbook --syntax-check orchestrate.yml
```

## Architecture

### appname Role

Central role in `roles/appname/` that handles all service operations:
- `tasks/main.yml` - Input validation + script validation + routes to action-specific task file
- `tasks/start.yml` - Script-based idempotent start with retry logic
- `tasks/stop.yml` - Script-based block-rescue pattern with force-kill fallback
- `tasks/status.yml` - Script-based status check
- `tasks/start_service.yml` - Systemd-based start
- `tasks/stop_service.yml` - Systemd-based stop
- `tasks/status_service.yml` - Systemd-based status check
- `tasks/wait_for_files_deleted.yml` - File monitoring between service operations
- `tasks/send_workflow_report.yml` - Comprehensive workflow reporting
- `defaults/main.yml` - All configurable variables with defaults
- `meta/main.yml` - Role metadata for Ansible Galaxy

### Workflow Orchestration

The framework uses separate workflow playbooks for different operations:
- `playbooks/appname_start.yml` - Start workflow (foo → bar → elephant)
- `playbooks/appname_stop.yml` - Stop workflow (elephant → bar → foo, includes file monitoring)
- `playbooks/appname_status.yml` - Status workflow (foo → bar → elephant)

`orchestrate.yml` - Router playbook that delegates to the appropriate workflow based on `service_action`.

### Service Configuration

Each service has a vars file in `vars/` with `appname_` prefixed variables:
- `appname_service_name` - Service identifier
- `appname_service_script` - Path to control script (optional - omit for systemd services)
- `appname_process_identifier` - Pattern for pkill fallback (must be >= 5 chars, properly quoted for security)
- `inventory_group` - Target host group (not prefixed, used by orchestration)

### Key Features

- **Dual Mode Support**: Use custom control scripts OR Ansible's systemd module
- **Input Validation**: Service action restricted to [start, stop, status] to prevent path traversal
- **Idempotency**: Skip start if running, skip stop if stopped
- **Retry Logic**: Status checks retry up to 3 times with delays
- **Script Validation**: Pre-flight check for existence and execute permission
- **Security Controls**:
  - `appname_allow_force_kill` - Explicit boolean to enable/disable pkill fallback (default: true)
  - `appname_process_identifier` - Validated for length >= 5 chars to ensure specificity
  - Process identifier properly quoted in pkill command to prevent injection

### Return Code Handling

Scripts with non-standard return codes are supported via:
- `appname_start_expected_rc` - Expected return code for start (default: 0, set to null to skip)
- `appname_stop_expected_rc` - Expected return code for stop (default: 0, set to null to skip)
- `appname_status_expected_rc` - Expected return code for status (default: 0, set to null to skip)

## Adding a New Service

1. Create `vars/newservice.yml` with service configuration (using `appname_` prefix):
   ```yaml
   appname_service_name: "newservice"
   appname_service_script: "/scripts/newservice.sh"  # Omit for systemd services
   appname_process_identifier: "COMPONENT=newservice"  # Only needed for script-based
   inventory_group: "newservice_servers"
   ```
2. Add `[newservice_servers]` group to `inventory/hosts`
3. Add service to all three workflow playbooks (appname_start.yml, appname_stop.yml, appname_status.yml)
