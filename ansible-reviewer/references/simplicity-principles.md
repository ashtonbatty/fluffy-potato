# Simplicity Principles: YAGNI and Avoiding Over-Engineering

## YAGNI: You Aren't Gonna Need It

YAGNI means: **Don't build features or abstractions until you actually need them.**

### YAGNI in Practice

**Over-engineered:**
```yaml
# Created dynamic service orchestration for 3 services
- name: Dynamic service management
  ansible.builtin.include_tasks: service_handler.yml
  loop: "{{ services }}"
  loop_control:
    loop_var: service
  vars:
    action: "{{ service_action }}"

# service_handler.yml with 50+ lines of logic
# services.yml with complex data structures
# Supports 20 different scenarios
```

**Simple:**
```yaml
# Three explicit plays - easier to understand and modify
- name: Foo service - {{ service_action }}
  hosts: foo_servers
  vars_files: [vars/foo.yml]
  roles: [service_role]

- name: Bar service - {{ service_action }}
  hosts: bar_servers
  vars_files: [vars/bar.yml]
  roles: [service_role]

- name: Baz service - {{ service_action }}
  hosts: baz_servers
  vars_files: [vars/baz.yml]
  roles: [service_role]
```

**Why simple is better:**
- Clear execution order (foo → bar → baz)
- Easy to modify (need different vars? Edit one play)
- Easy to debug (error in bar? Look at bar play)
- No hidden complexity in included files
- Can add play-specific logic without breaking abstraction

**When to use dynamic approach:** When you have 20+ services that change frequently.

## Three Strikes Rule

**Don't abstract until you've written something three times.**

### First time: Write it
```yaml
# playbook_a.yml
- name: Configure service A
  ansible.builtin.template:
    src: config_a.j2
    dest: /etc/service_a.conf
  notify: Restart service A
```

### Second time: Notice the pattern
```yaml
# playbook_b.yml - similar but slightly different
- name: Configure service B
  ansible.builtin.template:
    src: config_b.j2
    dest: /etc/service_b.conf
  notify: Restart service B
```

### Third time: Now abstract
```yaml
# Now you know the real pattern - create reusable role
# roles/config_service/tasks/main.yml
- name: "Configure {{ service_name }}"
  ansible.builtin.template:
    src: "{{ service_name }}.j2"
    dest: "/etc/{{ service_name }}.conf"
  notify: "Restart {{ service_name }}"
```

**Why wait:** First two times reveal what actually varies vs what you thought would vary.

## Premature Abstraction

### Example 1: Over-Abstracted Variables

**Over-engineered:**
```yaml
# defaults/main.yml
app_config:
  server:
    ports:
      http: 80
      https: 443
    ssl:
      enabled: true
      cert_path: /etc/ssl/cert.pem
  database:
    connections:
      pool_size: 10
      timeout: 30
  logging:
    level: info
    outputs:
      - file
      - syslog

# Usage requires deep traversal
- name: Set HTTP port
  ansible.builtin.lineinfile:
    line: "port={{ app_config.server.ports.http }}"
```

**Simple:**
```yaml
# defaults/main.yml
app_http_port: 80
app_https_port: 443
app_ssl_enabled: true
app_ssl_cert: /etc/ssl/cert.pem
app_db_pool_size: 10
app_db_timeout: 30
app_log_level: info
app_log_outputs: "file,syslog"

# Usage is straightforward
- name: Set HTTP port
  ansible.builtin.lineinfile:
    line: "port={{ app_http_port }}"
```

**When nested is better:** When you're passing the entire structure to a template or module.

### Example 2: Unnecessary Includes

**Over-engineered:**
```yaml
# tasks/main.yml
- ansible.builtin.include_tasks: validate.yml
- ansible.builtin.include_tasks: install.yml
- ansible.builtin.include_tasks: configure.yml
- ansible.builtin.include_tasks: start.yml

# Each file is 5-10 lines
```

**Simple:**
```yaml
# tasks/main.yml - everything in one file (40 lines)
- name: Validate prerequisites
  ansible.builtin.assert:
    that: prereq_met

- name: Install package
  ansible.builtin.apt:
    name: myapp

- name: Configure application
  ansible.builtin.template:
    src: config.j2
    dest: /etc/myapp.conf

- name: Start service
  ansible.builtin.systemd:
    name: myapp
    state: started
```

**When to split:** When a section exceeds ~50 lines OR is conditionally included.

## Gold Plating

Adding features "just in case" or "to be thorough."

### Example: Over-Validated Input

**Gold plated:**
```yaml
- name: Validate service name
  ansible.builtin.assert:
    that:
      - service_name is defined
      - service_name is string
      - service_name | length > 0
      - service_name | length <= 50
      - service_name is match('^[a-z][a-z0-9_-]*$')
    fail_msg: "Invalid service name format"

- name: Validate service name not reserved
  ansible.builtin.assert:
    that:
      - service_name not in reserved_names
    fail_msg: "Service name is reserved"

- name: Validate service name unique
  ansible.builtin.shell: systemctl list-units | grep -c "^{{ service_name }}"
  register: name_check
  failed_when: name_check.stdout | int > 0
```

**Appropriate:**
```yaml
- name: Validate service name
  ansible.builtin.assert:
    that:
      - service_name is defined
      - service_name | length > 0
    fail_msg: "service_name is required"
```

**Why:** Systemd will fail with a clear error if the name is invalid. Let it.

## Simplicity Checklist

### ✅ DO

**Use the simplest thing that works:**
```yaml
# Simple copy
- ansible.builtin.copy:
    src: config.txt
    dest: /etc/config.txt
```

**Be explicit and clear:**
```yaml
# Clear intent
- name: "Install {{ app_name }} version {{ app_version }}"
  ansible.builtin.apt:
    name: "{{ app_name }}"
    version: "{{ app_version }}"
```

**Handle errors at boundaries:**
```yaml
# Validate user input, not internal state
- name: Validate user-provided action
  ansible.builtin.assert:
    that: action in ['start', 'stop']

# Trust internal variables
- name: Execute action
  ansible.builtin.include_tasks: "{{ action }}.yml"
  # No need to re-validate
```

**Accept duplication over abstraction:**
```yaml
# Two similar tasks? That's fine.
- name: Configure prod database
  ansible.builtin.template:
    src: db_config.j2
    dest: /etc/prod_db.conf

- name: Configure staging database
  ansible.builtin.template:
    src: db_config.j2
    dest: /etc/staging_db.conf
```

### ❌ DON'T

**Don't create abstractions for < 3 uses:**
```yaml
# Overkill for 2 services
- ansible.builtin.include_role:
    name: generic_service_manager
  vars:
    service_definition: "{{ item }}"
  loop: "{{ services }}"
```

**Don't add configurability "just in case":**
```yaml
# Do you really need all these options?
enable_feature_x: true
feature_x_mode: "standard"
feature_x_timeout: 30
feature_x_retries: 3
feature_x_retry_delay: 5
# If nobody ever changes these, remove them
```

**Don't validate internal state:**
```yaml
# Unnecessary - you control this value
- assert:
    that: internal_var is defined
```

**Don't create layers of indirection:**
```yaml
# Too many hops
- include_tasks: orchestrator.yml
  # which includes: dispatcher.yml
  #   which includes: handler.yml
  #     which includes: executor.yml
```

## Real-World Examples

### Example: Service Orchestration

**Over-engineered (160 lines):**
- Dynamic service registry in YAML
- Generic service handler with 20 parameters
- Template-based task generation
- Meta-programming with variable variables
- Supports hypothetical future requirements

**Simple (40 lines):**
- Three explicit plays for three services
- Shared role with clear defaults
- Override per-service with vars files
- Supports actual current requirements

**Result:** Simple version is:
- 4x less code
- 10x easier to debug
- 100x easier to modify
- Does everything needed

### Example: Configuration Management

**Over-engineered:**
```yaml
# config_engine that handles 50 file types
config_files:
  - type: yaml
    src: app.yml
    dest: /etc/app.yml
    parser: yaml_processor
    validators:
      - yaml_syntax
      - schema_validator
    transformers:
      - key_mapper
      - value_interpolator

# Requires custom modules, filters, and 500 lines of code
```

**Simple:**
```yaml
- name: Deploy YAML config
  ansible.builtin.template:
    src: app.yml.j2
    dest: /etc/app.yml
    validate: yamllint %s
```

**Result:** Solves the actual problem with built-in modules.

## When to Add Complexity

Add complexity when:

1. **Pattern proven by repetition**: Written 3+ times
2. **Clear current need**: Not hypothetical future
3. **Reduces total complexity**: Net simplification
4. **Well-understood pattern**: Team knows the abstraction

**Example of justified complexity:**
```yaml
# You have 50 nearly identical services
# Dynamic approach reduces 2000 lines to 200
# Team is familiar with the pattern
# Changes affect all 50 services consistently
# JUSTIFIED
```

## Simplicity Principles Summary

1. **YAGNI**: Don't build it until you need it
2. **Three Strikes**: Don't abstract until 3rd occurrence
3. **Duplication > Abstraction**: For < 3 uses
4. **Explicit > Implicit**: Clear beats clever
5. **Flat > Nested**: Avoid deep includes
6. **Boundaries**: Validate at edges only
7. **Delete > Add**: Remove unused features
8. **Standard > Custom**: Use built-in modules

## Review Questions

When reviewing, ask:

1. **Is this solving a real problem or a hypothetical one?**
   - If hypothetical: Remove it

2. **Could this be three simple things instead of one complex thing?**
   - If yes: Simplify

3. **Would deleting this break anything today?**
   - If no: Delete it

4. **How many times is this pattern actually used?**
   - If < 3: Inline it

5. **Does this make the common case harder to understand?**
   - If yes: Simplify

6. **Would a new team member understand this in 5 minutes?**
   - If no: Simplify or document

7. **What is the cost/benefit ratio of this abstraction?**
   - Lines saved vs complexity added

8. **Is there a simpler Ansible built-in that does this?**
   - If yes: Use it

## The Best Code is No Code

The best way to maintain code is to not write it in the first place.

Before adding a feature, ask:
- Do we really need this?
- Can we solve this without code?
- What's the simplest possible version?

**Remember:** Every line of code is a liability:
- Must be read
- Must be understood
- Must be maintained
- Can have bugs
- Creates dependencies

**Write as little as necessary, as clearly as possible.**
