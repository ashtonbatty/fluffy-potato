# Ansible Best Practices

## Module Usage

### Use FQCN (Fully Qualified Collection Names)
```yaml
# Good
- ansible.builtin.command: echo "hello"
- community.general.make: target=install

# Bad (deprecated short form)
- command: echo "hello"
```

### Prefer Specific Modules Over Shell/Command
```yaml
# Good
- ansible.builtin.file:
    path: /tmp/foo
    state: absent

# Bad
- ansible.builtin.shell: rm -rf /tmp/foo
```

### Module Idempotency
- Use `creates` or `removes` with command/shell modules
- Check `changed_when` conditions
- Use `check_mode` compatible modules

## Task Attributes

### failed_when and changed_when
Always specify when behavior isn't obvious:

```yaml
- ansible.builtin.command: /scripts/check_status.sh
  register: result
  changed_when: "'modified' in result.stdout"
  failed_when: result.rc > 1  # 0=success, 1=warning, 2+=error
```

### Task Names
- Use descriptive, imperative names
- Include variable context when helpful
- Avoid generic names like "Run command"

```yaml
# Good
- name: "Install {{ package_name }} version {{ package_version }}"

# Bad
- name: Install package
```

## Variable Management

### Naming Conventions
- Role-specific prefix: `rolename_variable_name`
- No generic names that might collide
- Lowercase with underscores

```yaml
# Good
appname_role_service_name: "myservice"
appname_role_retry_delay: 3

# Bad
service: "myservice"  # Too generic
ServiceName: "myservice"  # Wrong case
```

### Variable Precedence
Understand the precedence order:
1. Extra vars (`-e`)
2. Task vars
3. Block vars
4. Role vars
5. Play vars
6. Host facts
7. Registered vars
8. Set_facts
9. Role defaults
10. Group vars
11. Host vars

Place variables at appropriate level:
- **defaults/**: Safe defaults, user can override
- **vars/**: Fixed values for role logic
- **group_vars/**: Environment-specific values
- **host_vars/**: Host-specific overrides

## Error Handling

### Use Block-Rescue-Always
```yaml
- name: Graceful degradation pattern
  block:
    - name: Try primary method
      ansible.builtin.command: /scripts/stop_gracefully.sh
  rescue:
    - name: Fallback method
      ansible.builtin.command: pkill -9 process
  always:
    - name: Cleanup
      ansible.builtin.file:
        path: /tmp/lockfile
        state: absent
```

### Explicit Error Messages
```yaml
- name: Validate prerequisites
  ansible.builtin.assert:
    that:
      - variable is defined
      - variable | length > 0
    fail_msg: "variable must be defined and non-empty"
    success_msg: "Prerequisites validated"
```

## Idempotency

### Pre-flight Checks
```yaml
- name: Check if already installed
  ansible.builtin.stat:
    path: /usr/bin/myapp
  register: myapp_binary

- name: Install application
  ansible.builtin.command: /installer/setup.sh
  when: not myapp_binary.stat.exists
```

### Conditional Execution
```yaml
- name: Check current state
  ansible.builtin.command: systemctl is-active myservice
  register: service_status
  failed_when: false
  changed_when: false

- name: Start service
  ansible.builtin.systemd:
    name: myservice
    state: started
  when: service_status.rc != 0
```

## Performance

### Gather Facts Selectively
```yaml
# Disable when not needed
- hosts: webservers
  gather_facts: false

# Or gather minimal facts
- hosts: webservers
  gather_facts: true
  gather_subset:
    - '!all'
    - '!min'
    - network
```

### Async and Poll
For long-running tasks:

```yaml
- name: Long running operation
  ansible.builtin.command: /scripts/backup.sh
  async: 3600
  poll: 10
```

### Serial Execution
For rolling updates:

```yaml
- hosts: webservers
  serial: 2  # Update 2 at a time
  tasks:
    - name: Update application
      ansible.builtin.apt:
        name: myapp
        state: latest
```

## Code Organization

### Role Structure
Standard directory layout:
```
role_name/
├── tasks/
│   ├── main.yml
│   ├── install.yml
│   └── configure.yml
├── handlers/
│   └── main.yml
├── defaults/
│   └── main.yml
├── vars/
│   └── main.yml
├── templates/
│   └── config.j2
├── files/
│   └── script.sh
└── meta/
    └── main.yml
```

### Task Files
- Keep main.yml as router/orchestrator
- Split complex logic into separate files
- Use `include_tasks` for conditional includes
- Use `import_tasks` for static includes

```yaml
# tasks/main.yml
- name: Load OS-specific variables
  ansible.builtin.include_vars: "{{ ansible_os_family }}.yml"

- name: Execute OS-specific tasks
  ansible.builtin.include_tasks: "{{ ansible_os_family }}.yml"
```

## Testing

### Check Mode
Make tasks check-mode safe:

```yaml
- name: Modify configuration
  ansible.builtin.lineinfile:
    path: /etc/config
    line: "option=value"
    create: true
  check_mode: true  # Test this
```

### Tags
Add tags for selective execution:

```yaml
- name: Install packages
  ansible.builtin.apt:
    name: "{{ item }}"
  loop:
    - nginx
    - redis
  tags:
    - packages
    - install
```

### Molecule Tests
Include tests for roles:
- Syntax checking
- Idempotency tests
- Side effect verification
- Multi-platform testing

## Documentation

### Task Comments
Comment complex logic:

```yaml
# This task handles the edge case where the service is in a
# failed state but still has a PID file. We need to clean up
# the PID file before attempting to start.
- name: Remove stale PID file
  ansible.builtin.file:
    path: /var/run/myservice.pid
    state: absent
  when: service_failed and pid_exists
```

### README
Include in role README:
- Purpose and use cases
- Requirements and dependencies
- Variable documentation
- Example playbook
- License

### Variable Documentation
Document variables in defaults/main.yml:

```yaml
# Service configuration
myapp_service_name: "myapp"  # Name of the systemd service
myapp_port: 8080            # Port to bind (1024-65535)
myapp_max_connections: 100  # Maximum concurrent connections
```

## Handlers

### Handler Best Practices
```yaml
# handlers/main.yml
- name: Restart nginx
  ansible.builtin.systemd:
    name: nginx
    state: restarted
  # Handlers only run once even if notified multiple times

# Use listen for grouped handlers
- name: Restart web services
  listen: "restart web stack"
  ansible.builtin.systemd:
    name: "{{ item }}"
    state: restarted
  loop:
    - nginx
    - php-fpm
```

### Handler Ordering
```yaml
- name: Reload configuration
  notify:
    - Validate config
    - Reload service
  # Handlers run in order listed in handlers/main.yml
```

## Loops

### Modern Loop Syntax
```yaml
# Good - modern syntax
- name: Install packages
  ansible.builtin.apt:
    name: "{{ item }}"
  loop:
    - nginx
    - redis

# Bad - deprecated
- name: Install packages
  ansible.builtin.apt:
    name: "{{ item }}"
  with_items:
    - nginx
    - redis
```

### Loop Control
```yaml
- name: Create users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
  loop: "{{ users }}"
  loop_control:
    label: "{{ item.name }}"  # Show only name in output
    pause: 1  # Wait 1 second between iterations
```

## Platform Independence

### OS Detection
```yaml
- name: Install package
  ansible.builtin.package:  # Works across package managers
    name: nginx
    state: present

- name: OS-specific task
  ansible.builtin.import_tasks: "{{ ansible_os_family }}.yml"
```

### Path Separators
Use Ansible filters:
```yaml
config_path: "{{ base_dir }}/config/app.conf"  # Unix-style
config_path: "{{ [base_dir, 'config', 'app.conf'] | path_join }}"  # Portable
```
