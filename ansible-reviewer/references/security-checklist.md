# Ansible Security Checklist

## Input Validation

### Path Traversal Prevention
- [ ] Service actions validated against whitelists
- [ ] File paths sanitized before use
- [ ] User inputs not directly passed to shell commands
- [ ] Dynamic includes use validated paths only

**Example - Good:**
```yaml
- name: Validate action
  assert:
    that:
      - service_action in ['start', 'stop', 'restart']
```

**Example - Bad:**
```yaml
- include_tasks: "{{ user_action }}.yml"  # No validation!
```

### Command Injection
- [ ] Variables properly quoted in shell commands
- [ ] Use `command` module over `shell` when possible
- [ ] Use `quote` filter for user-provided values
- [ ] Avoid `raw` module unless absolutely necessary

**Example - Good:**
```yaml
- command: pkill -f {{ process_name | quote }}
```

**Example - Bad:**
```yaml
- shell: pkill -f {{ process_name }}  # Injection risk!
```

## Privilege Escalation

### Become Usage
- [ ] `become` used only when necessary
- [ ] Specific `become_user` instead of assuming root
- [ ] Explicit `become` in tasks, not global
- [ ] `become_flags` documented if customized

**Review questions:**
- Why does this task need elevated privileges?
- Could it run with less privilege?
- Is the become_user appropriate?

### Secrets Management
- [ ] No hardcoded credentials in playbooks
- [ ] Ansible Vault used for sensitive data
- [ ] Secrets not logged in task output
- [ ] `no_log: true` on sensitive tasks

**Example - Good:**
```yaml
- name: Set password
  user:
    name: myuser
    password: "{{ vault_password }}"
  no_log: true
```

## File Operations

### File Permissions
- [ ] Explicit `mode` specified for sensitive files
- [ ] Owner and group explicitly set
- [ ] No world-writable files created
- [ ] Validate source files before copying

**Example - Good:**
```yaml
- copy:
    src: secret.key
    dest: /etc/app/secret.key
    mode: '0600'
    owner: appuser
    group: appuser
```

### Template Security
- [ ] Templates sanitize user input
- [ ] No sensitive data in template comments
- [ ] Template output permissions restricted
- [ ] Jinja2 autoescaping for HTML/XML

## Network Security

### Connection Settings
- [ ] SSL/TLS certificate validation enabled
- [ ] `validate_certs: true` for HTTPS
- [ ] No plaintext credentials in URLs
- [ ] Connection timeouts configured

### Firewall Rules
- [ ] Minimal necessary ports opened
- [ ] Source IP restrictions where possible
- [ ] Rules reviewed for necessity
- [ ] Default-deny policies preferred

## Data Exposure

### Logging
- [ ] Sensitive variables use `no_log: true`
- [ ] Debug output reviewed for secrets
- [ ] Command output doesn't leak credentials
- [ ] Register variables sanitized before display

**Common pitfalls:**
```yaml
# Bad - Password visible in logs
- command: mysql -u root -p{{ db_password }}

# Good - Hidden from logs
- command: mysql --defaults-file=/tmp/my.cnf
  no_log: true
```

### Variable Scope
- [ ] Secrets not in `vars_files` committed to git
- [ ] Use `set_fact` with `no_log` for computed secrets
- [ ] Group_vars/host_vars secured properly
- [ ] Extra vars validated before use

## Process Kill Safety

When using `pkill` or similar:

- [ ] Process identifier >= 5 characters
- [ ] Pattern tested with `pgrep` first
- [ ] Identifier specific enough (not just "python")
- [ ] Force kill explicitly opted-in
- [ ] Proper quoting of process identifiers

**Example - Good:**
```yaml
- name: Validate identifier
  assert:
    that:
      - process_id | length >= 5
      - allow_force_kill | bool
```

## CVE and Updates

- [ ] Ansible version supports security features needed
- [ ] Modules up-to-date (no deprecated modules)
- [ ] Collections from trusted sources
- [ ] Dependencies vetted for vulnerabilities

## Review Questions

For each task with elevated privileges:
1. **Why**: Why is this privilege needed?
2. **What**: What is the minimal privilege required?
3. **When**: Could this run with less privilege?
4. **Who**: Is the become_user appropriate?
5. **How**: Are the operations properly validated?

For each external input:
1. Is it validated before use?
2. Is it properly quoted/escaped?
3. Could it be used for injection?
4. Is there a safer alternative?

For each secret/credential:
1. Is it in Vault?
2. Is it logged anywhere?
3. Who has access?
4. Is the file permission appropriate?
