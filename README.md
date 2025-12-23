# Ansible Service Manager

A flexible, DRY Ansible framework for managing custom services with graceful stop/start operations, comprehensive workflow reporting, and configurable return code handling.

## Key Features

- **Graceful Service Management** - Automatic fallback to force-kill if graceful shutdown fails
- **Comprehensive Workflow Reporting** - Email reports for ALL start/stop runs with timing, events, and failure details
- **Separate Start/Stop Workflows** - Different service ordering (Start: foo → bar → elephant, Stop: elephant → bar → foo)
- **File Deletion Monitoring** - Wait for files to be deleted during stop operations with timeout tracking
- **Security Controls** - Input validation, force-kill toggle, process identifier length validation
- **Flexible Return Code Handling** - Support for scripts with non-standard return codes
- **DRY Architecture** - Service-specific configurations in separate files, unified orchestration

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

[bar_servers]
host2.example.com

[elephant_servers]
host3.example.com
```

### 2. Configure Services

Each service has a vars file in `vars/` with `cal_` prefixed variables. Example `vars/foo.yml`:

```yaml
cal_service_name: "foo"
cal_service_script: "/scripts/foo.sh"
cal_process_identifier: "COMPONENT=foo"
inventory_group: "foo_servers"
```

### 3. Run Operations

**Start all services** (order: foo → bar → elephant):
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=start
```

**Stop all services** (order: elephant → bar → foo):
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=stop
```

**Check service status**:
```bash
ansible-playbook -i inventory/hosts orchestrate.yml -e service_action=status
```

## Directory Structure

```
ansible-cal/
├── orchestrate.yml                    # Router playbook
├── playbooks/
│   ├── cal_start.yml                  # Start workflow
│   ├── cal_stop.yml                   # Stop workflow
│   └── cal_status.yml                 # Status workflow
├── inventory/hosts                    # Inventory with service groups
├── vars/
│   ├── services.yml                   # Central services registry
│   ├── foo.yml                        # Service configurations
│   ├── bar.yml
│   └── elephant.yml
├── roles/cal/
│   ├── defaults/main.yml              # Default variables
│   ├── meta/main.yml                  # Role metadata
│   └── tasks/
│       ├── main.yml                   # Input validation + router
│       ├── start.yml                  # Start with idempotency
│       ├── stop.yml                   # Stop with force-kill fallback
│       ├── status.yml                 # Status check
│       ├── wait_for_files_deleted.yml # File monitoring
│       └── send_workflow_report.yml   # Workflow reporting
└── docs/                              # Detailed documentation
    ├── configuration.md
    ├── advanced-usage.md
    ├── workflow-reporting.md
    ├── troubleshooting.md
    ├── examples.md
    └── architecture.md
```

## Documentation

- **[Configuration](docs/configuration.md)** - Role defaults, service-specific variables, and configuration reference
- **[Advanced Usage](docs/advanced-usage.md)** - Backwards return codes, disabling force kill, per-service overrides
- **[Workflow Reporting](docs/workflow-reporting.md)** - Comprehensive email reporting, force kill events, file monitoring
- **[Troubleshooting](docs/troubleshooting.md)** - Common issues and solutions
- **[Examples](docs/examples.md)** - Usage examples and custom configurations
- **[Architecture](docs/architecture.md)** - How it works, adding services, security, best practices

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
3. Use `cal_` prefix for all role variables
4. Update documentation with new features
5. Run `ansible-lint` to ensure code quality
6. Test thoroughly before deploying to production
