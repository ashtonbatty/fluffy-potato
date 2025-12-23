# Molecule Test Scenario: Default

This scenario tests the appname role in a containerized environment using Podman.

## What It Tests

1. **Script-based Service Mode**
   - Creates a test service script at `/scripts/testservice.sh`
   - Tests status check with custom script

2. **Systemd Service Mode**
   - Creates a systemd service `systemd-test`
   - Tests start, status, and stop operations

## Requirements

- Podman installed and running
- Molecule installed (`pip install molecule molecule-plugins[podman]`)

## Running Tests

```bash
# Run the full test suite
cd roles/appname
molecule test

# Create and provision the instance
molecule converge

# Run verification checks
molecule verify

# Clean up test environment
molecule destroy
```

## Test Container

- **Platform**: Fedora (latest)
- **Image**: quay.io/fedora/fedora:latest
- **Systemd**: Enabled (required for systemd service tests)
- **Privileges**: Required for systemd operations

## Expected Outcomes

All tests should pass, demonstrating:
- Script validation works correctly
- Script-based operations execute successfully
- Systemd service operations work in dual-mode
- Return code handling functions as expected
