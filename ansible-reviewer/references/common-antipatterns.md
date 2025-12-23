# Common Ansible Antipatterns

## Command Module Abuse

### Antipattern: Using Shell for Everything
```yaml
# Bad
- name: Create directory
  ansible.builtin.shell: mkdir -p /opt/myapp

- name: Copy file
  ansible.builtin.shell: cp source.txt /opt/myapp/

# Good
- name: Create directory
  ansible.builtin.file:
    path: /opt/myapp
    state: directory

- name: Copy file
  ansible.builtin.copy:
    src: source.txt
    dest: /opt/myapp/
```

**Why it's bad**: Shell commands are not idempotent, harder to test, and error-prone.

### Antipattern: Parsing Command Output
```yaml
# Bad
- name: Get service status
  ansible.builtin.shell: systemctl status myapp | grep Active | awk '{print $2}'
  register: status

# Good
- name: Get service status
  ansible.builtin.systemd:
    name: myapp
  register: status
  check_mode: true
```

**Why it's bad**: Brittle, output format can change, not cross-platform.

## Idempotency Violations

### Antipattern: No Changed_when on Commands
```yaml
# Bad - always shows as changed
- name: Check configuration
  ansible.builtin.command: /scripts/verify_config.sh

# Good
- name: Check configuration
  ansible.builtin.command: /scripts/verify_config.sh
  register: result
  changed_when: false
  failed_when: result.rc != 0
```

### Antipattern: Destructive Operations Without Checks
```yaml
# Bad - always deletes and recreates
- name: Reset application
  ansible.builtin.file:
    path: /opt/myapp
    state: absent

- name: Create application directory
  ansible.builtin.file:
    path: /opt/myapp
    state: directory

# Good - check state first
- name: Check if reset needed
  ansible.builtin.stat:
    path: /opt/myapp/.needs_reset
  register: reset_marker

- name: Reset application
  ansible.builtin.file:
    path: /opt/myapp
    state: absent
  when: reset_marker.stat.exists
```

## Variable Misuse

### Antipattern: No Variable Prefixes
```yaml
# Bad - variables pollute global namespace
service_name: myapp
port: 8080
user: appuser

# Good - role-prefixed variables
myapp_service_name: myapp
myapp_port: 8080
myapp_user: appuser
```

**Why it's bad**: Name collisions across roles, debugging nightmare.

### Antipattern: Hardcoded Values
```yaml
# Bad - magic numbers and strings
- name: Configure service
  ansible.builtin.template:
    src: config.j2
    dest: /etc/myapp.conf
  # Template has hardcoded values

# Good - parameterized
- name: Configure service
  ansible.builtin.template:
    src: config.j2
    dest: "{{ myapp_config_path }}"
  # Template uses variables
```

### Antipattern: Using set_fact in Loops
```yaml
# Bad - very slow
- name: Process items
  ansible.builtin.set_fact:
    results: "{{ results | default([]) + [item] }}"
  loop: "{{ large_list }}"

# Good - use map/select filters
- name: Process items
  ansible.builtin.set_fact:
    results: "{{ large_list | map('extract', ...) | list }}"
```

**Why it's bad**: O(n²) complexity, extremely slow for large lists.

## Handler Misuse

### Antipattern: Handlers That Always Run
```yaml
# Bad
- name: Update config
  ansible.builtin.copy:
    src: config.txt
    dest: /etc/config.txt
  notify: Restart service
  changed_when: true  # Always notifies!

# Good
- name: Update config
  ansible.builtin.copy:
    src: config.txt
    dest: /etc/config.txt
  notify: Restart service
  # Only notifies when actually changed
```

### Antipattern: Handlers for Non-Idempotent Tasks
```yaml
# Bad - handler runs every time
- name: Check logs
  ansible.builtin.command: grep ERROR /var/log/app.log
  notify: Send alert

# Good - use separate task with condition
- name: Check logs
  ansible.builtin.command: grep ERROR /var/log/app.log
  register: errors
  failed_when: false
  changed_when: false

- name: Send alert
  ansible.builtin.mail:
    subject: "Errors found"
  when: errors.stdout_lines | length > 0
```

## Security Antipatterns

### Antipattern: Secrets in Plain Text
```yaml
# Bad
db_password: "supersecret123"

# Good
db_password: "{{ vault_db_password }}"
# ansible-vault encrypt_string 'supersecret123' --name 'vault_db_password'
```

### Antipattern: No Input Validation
```yaml
# Bad
- name: Execute user action
  ansible.builtin.include_tasks: "{{ user_action }}.yml"

# Good
- name: Validate user action
  ansible.builtin.assert:
    that:
      - user_action in ['start', 'stop', 'restart']
    fail_msg: "Invalid action: {{ user_action }}"

- name: Execute user action
  ansible.builtin.include_tasks: "{{ user_action }}.yml"
```

### Antipattern: Global Become
```yaml
# Bad
- hosts: all
  become: true
  tasks:
    - name: Read a file  # Doesn't need root
      ansible.builtin.slurp:
        path: /tmp/data.txt

# Good
- hosts: all
  tasks:
    - name: Read a file
      ansible.builtin.slurp:
        path: /tmp/data.txt

    - name: Install package
      ansible.builtin.apt:
        name: nginx
      become: true  # Only where needed
```

## Structure Antipatterns

### Antipattern: Monolithic Main.yml
```yaml
# Bad - tasks/main.yml with 500 lines
- name: Install dependencies
  # 50 tasks...

- name: Configure application
  # 100 tasks...

- name: Setup monitoring
  # 50 tasks...

# Good - split into files
# tasks/main.yml
- ansible.builtin.import_tasks: dependencies.yml
- ansible.builtin.import_tasks: configure.yml
- ansible.builtin.import_tasks: monitoring.yml
```

### Antipattern: Deep Task Includes
```yaml
# Bad - include chain 5 levels deep
# main.yml -> setup.yml -> install.yml -> packages.yml -> apt.yml

# Good - flat structure
# main.yml directly includes all needed files
```

**Why it's bad**: Hard to trace flow, debugging nightmare, performance impact.

### Antipattern: Playbook-Role Confusion
```yaml
# Bad - role contains playbook logic
# roles/myapp/tasks/main.yml
- hosts: databases
  tasks:
    - name: Configure DB

# Good - keep playbook logic in playbooks
# playbook.yml
- hosts: databases
  roles:
    - myapp
```

## Performance Antipatterns

### Antipattern: Serial: 1 Without Reason
```yaml
# Bad - unnecessarily slow
- hosts: webservers
  serial: 1
  # No reason for sequential execution

# Good - parallel by default
- hosts: webservers
  # Runs in parallel
```

### Antipattern: Gathering Facts Unnecessarily
```yaml
# Bad
- hosts: localhost
  gather_facts: true  # Wastes ~2 seconds
  tasks:
    - name: Local operation
      ansible.builtin.debug:
        msg: "Hello"

# Good
- hosts: localhost
  gather_facts: false
  tasks:
    - name: Local operation
      ansible.builtin.debug:
        msg: "Hello"
```

### Antipattern: Synchronous Long Tasks
```yaml
# Bad - blocks playbook for hours
- name: Large backup
  ansible.builtin.command: /scripts/backup_everything.sh

# Good - async execution
- name: Large backup
  ansible.builtin.command: /scripts/backup_everything.sh
  async: 7200
  poll: 60
```

## Error Handling Antipatterns

### Antipattern: Ignore_errors Everywhere
```yaml
# Bad
- name: Might fail task
  ansible.builtin.command: /scripts/flaky.sh
  ignore_errors: true

# Good - handle specific errors
- name: Might fail task
  ansible.builtin.command: /scripts/flaky.sh
  register: result
  failed_when: result.rc > 1  # Only fail on actual errors
```

### Antipattern: No Failed_when Logic
```yaml
# Bad - treats all non-zero as failure
- name: Check service
  ansible.builtin.command: /scripts/check.sh
  # Returns 1 for "not running" which is valid

# Good - define failure conditions
- name: Check service
  ansible.builtin.command: /scripts/check.sh
  register: result
  failed_when: result.rc > 1  # 0=running, 1=stopped, 2+=error
```

## Debugging Antipatterns

### Antipattern: Debug in Production
```yaml
# Bad - debug output always on
- name: Show variable
  ansible.builtin.debug:
    var: sensitive_data

# Good - conditional debug
- name: Show variable
  ansible.builtin.debug:
    var: sensitive_data
  when: debug_mode | default(false)
```

### Antipattern: No Task Names
```yaml
# Bad
- ansible.builtin.command: /scripts/setup.sh
- ansible.builtin.copy:
    src: file.txt
    dest: /tmp/

# Good
- name: "Run initial setup for {{ app_name }}"
  ansible.builtin.command: /scripts/setup.sh

- name: "Copy configuration to /tmp"
  ansible.builtin.copy:
    src: file.txt
    dest: /tmp/
```

**Why it's bad**: Makes debugging and logs incomprehensible.

## Template Antipatterns

### Antipattern: Logic in Templates
```yaml
# Bad - business logic in template
# templates/config.j2
{% if port > 1024 %}
  {% set safe_port = port %}
{% else %}
  {% set safe_port = 8080 %}
{% endif %}

# Good - logic in tasks
- name: Set safe port
  ansible.builtin.set_fact:
    safe_port: "{{ port if port > 1024 else 8080 }}"
```

### Antipattern: Duplicated Templates
```yaml
# Bad - three nearly identical templates
templates/
  config_dev.j2
  config_staging.j2
  config_prod.j2

# Good - one parameterized template
templates/
  config.j2  # Uses variables for differences
```

## Testing Antipatterns

### Antipattern: No Check Mode Support
```yaml
# Bad - fails in check mode
- name: Modify config
  ansible.builtin.shell: sed -i 's/foo/bar/' /etc/config

# Good - check mode compatible
- name: Modify config
  ansible.builtin.lineinfile:
    path: /etc/config
    regexp: '^foo'
    line: 'bar'
```

### Antipattern: No Idempotency Tests
```yaml
# Bad - never tested if running twice is safe
- name: Setup application
  ansible.builtin.command: /scripts/setup.sh

# Good - include idempotency test
# Run playbook twice, second run should have 0 changes
```

## Review Checklist

When reviewing code, look for:
- [ ] Shell/command instead of dedicated modules
- [ ] Missing changed_when on commands
- [ ] Variables without role prefix
- [ ] Hardcoded values instead of variables
- [ ] Secrets in plain text
- [ ] No input validation
- [ ] Global become
- [ ] Monolithic task files
- [ ] Ignore_errors without reason
- [ ] Debug statements in production
- [ ] No task names
- [ ] Logic in templates
- [ ] Gathering facts when not needed
