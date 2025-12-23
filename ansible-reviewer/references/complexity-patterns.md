# Recognizing and Reducing Cognitive Complexity in Ansible

## What is Cognitive Complexity?

Cognitive complexity measures how difficult code is to understand. In Ansible, high cognitive complexity makes playbooks hard to:
- Debug when things go wrong
- Modify when requirements change
- Review for correctness
- Onboard new team members

## Complexity Indicators

### 1. Nested Conditionals

**High Complexity:**
```yaml
- name: Complex conditional logic
  ansible.builtin.command: /scripts/action.sh
  when: >
    (environment == 'prod' and
     ((region == 'us-east' and instance_type == 'large') or
      (region == 'us-west' and instance_type in ['large', 'xlarge']))) or
    (environment == 'staging' and
     force_deploy | default(false))
```

**Cognitive load**: Reader must hold multiple conditions in mind, trace boolean logic, understand precedence.

**Reduced Complexity:**
```yaml
- name: Determine if deployment allowed
  ansible.builtin.set_fact:
    deploy_allowed: >-
      {{
        (environment == 'prod' and is_production_region) or
        (environment == 'staging' and force_deploy | default(false))
      }}

- name: Check production region requirements
  ansible.builtin.set_fact:
    is_production_region: >-
      {{
        (region == 'us-east' and instance_type == 'large') or
        (region == 'us-west' and instance_type in ['large', 'xlarge'])
      }}

- name: Execute deployment
  ansible.builtin.command: /scripts/action.sh
  when: deploy_allowed
```

**Benefits**: Named intermediate values, linear flow, testable conditions.

### 2. Complex Failed_when Logic

**High Complexity:**
```yaml
- name: Run operation
  ansible.builtin.command: /scripts/operation.sh
  register: result
  failed_when: >
    (check_rc and
      ((expect_zero_rc and result.rc != 0) or
       (not expect_zero_rc and result.rc == 0))) or
    (check_output and
      ((expect_pattern in result.stdout and invert_check) or
       (expect_pattern not in result.stdout and not invert_check)))
```

**Cognitive load**: Double negatives, multiple boolean operations, complex state.

**Reduced Complexity - Option 1: Extract to Variables:**
```yaml
- name: Run operation
  ansible.builtin.command: /scripts/operation.sh
  register: result
  failed_when: false  # Check manually below

- name: Check return code
  ansible.builtin.assert:
    that:
      - not (check_rc and expect_zero_rc and result.rc != 0)
      - not (check_rc and not expect_zero_rc and result.rc == 0)
    fail_msg: "Return code check failed"
  when: check_rc

- name: Check output pattern
  ansible.builtin.assert:
    that:
      - not (expect_pattern in result.stdout and invert_check)
      - not (expect_pattern not in result.stdout and not invert_check)
    fail_msg: "Output pattern check failed"
  when: check_output
```

**Reduced Complexity - Option 2: Comment the Logic:**
```yaml
- name: Run operation
  ansible.builtin.command: /scripts/operation.sh
  register: result
  failed_when: >
    # Fail if: RC checking enabled AND
    #   (expecting 0 but got non-zero OR expecting non-zero but got 0)
    (check_rc and
      ((expect_zero_rc and result.rc != 0) or
       (not expect_zero_rc and result.rc == 0)))
    # OR: Output checking enabled AND
    #   (found pattern but should invert OR didn't find but should have)
    or (check_output and
      ((expect_pattern in result.stdout and invert_check) or
       (expect_pattern not in result.stdout and not invert_check)))
```

### 3. Dense Loop Logic

**High Complexity:**
```yaml
- name: Process complex items
  ansible.builtin.template:
    src: "{{ item.template | default('default.j2') }}"
    dest: "{{ item.dest }}"
    mode: "{{ item.mode | default('0644') }}"
  loop: "{{ configs | selectattr('enabled', 'defined') | selectattr('enabled') | list }}"
  when: >
    item.environment == ansible_environment and
    (item.required | default(false) or optional_configs | default(true))
  loop_control:
    label: "{{ item.name }}"
```

**Cognitive load**: Nested defaults, filter chains, complex when clause, must trace data structure.

**Reduced Complexity:**
```yaml
- name: Filter enabled configs for current environment
  ansible.builtin.set_fact:
    active_configs: >-
      {{
        configs
        | selectattr('enabled', 'defined')
        | selectattr('enabled')
        | selectattr('environment', 'equalto', ansible_environment)
        | list
      }}

- name: Deploy configuration files
  ansible.builtin.template:
    src: "{{ item.template | default('default.j2') }}"
    dest: "{{ item.dest }}"
    mode: "{{ item.mode | default('0644') }}"
  loop: "{{ active_configs }}"
  when: item.required | default(false) or optional_configs | default(true)
  loop_control:
    label: "{{ item.name }}"
```

### 4. Variable Name Ambiguity

**High Complexity:**
```yaml
- name: Process data
  ansible.builtin.set_fact:
    result: "{{ result | default([]) + [item] }}"
  loop: "{{ items }}"

- name: Filter results
  ansible.builtin.set_fact:
    result: "{{ result | selectattr('valid') | list }}"

- name: Transform results
  ansible.builtin.set_fact:
    result: "{{ result | map(attribute='name') | list }}"
```

**Cognitive load**: `result` changes meaning three times, hard to track state.

**Reduced Complexity:**
```yaml
- name: Collect raw items
  ansible.builtin.set_fact:
    raw_items: "{{ items }}"

- name: Filter valid items
  ansible.builtin.set_fact:
    valid_items: "{{ raw_items | selectattr('valid') | list }}"

- name: Extract item names
  ansible.builtin.set_fact:
    item_names: "{{ valid_items | map(attribute='name') | list }}"
```

**Benefits**: Each variable has one clear meaning, data flow is obvious.

### 5. Magic Numbers and Unexplained Values

**High Complexity:**
```yaml
- name: Wait for service
  ansible.builtin.wait_for:
    port: 8080
    delay: 5
    timeout: 300

- name: Retry failed operations
  ansible.builtin.command: /scripts/operation.sh
  register: result
  retries: 3
  delay: 10
  until: result.rc == 0 or result.rc == 2
```

**Cognitive load**: Why these specific values? What does RC 2 mean?

**Reduced Complexity:**
```yaml
# Define meaningful constants
- name: Set timing constants
  ansible.builtin.set_fact:
    service_startup_delay: 5  # Allow service initialization
    service_startup_timeout: 300  # 5 minutes for full startup
    operation_retry_count: 3  # Tolerate transient failures
    operation_retry_delay: 10  # Wait between retries
    # Return codes: 0=success, 2=non-fatal warning, 1,3+=error

- name: Wait for service startup
  ansible.builtin.wait_for:
    port: 8080
    delay: "{{ service_startup_delay }}"
    timeout: "{{ service_startup_timeout }}"

- name: Retry failed operations
  ansible.builtin.command: /scripts/operation.sh
  register: result
  retries: "{{ operation_retry_count }}"
  delay: "{{ operation_retry_delay }}"
  until: result.rc == 0 or result.rc == 2  # Success or warning
```

## Complexity Metrics

### Cyclomatic Complexity
Count decision points:
- Each `when` condition: +1
- Each `or` in when: +1
- Each `and` in when: +1
- Each `failed_when` branch: +1
- Each loop with condition: +2

**Target**: Keep individual tasks under 5 decision points.

### Nesting Depth
Count levels of indentation/nesting:
- Block inside block
- Conditional inside loop
- Include inside include

**Target**: Max 3 levels deep.

### Variable Lifespan
How long is a variable "live" before its last use?

**High complexity**: Variable set in task 1, used in task 50.
**Low complexity**: Variable set in task 1, used in task 2-3.

## Simplification Strategies

### Strategy 1: Extract Named Conditions
```yaml
# Before
when: >
  (var1 == 'foo' and var2 > 10) or
  (var1 == 'bar' and var3 | length > 0)

# After
- set_fact:
    is_foo_condition: "{{ var1 == 'foo' and var2 > 10 }}"
    is_bar_condition: "{{ var1 == 'bar' and var3 | length > 0 }}"

when: is_foo_condition or is_bar_condition
```

### Strategy 2: Split Complex Tasks
```yaml
# Before - one task does too much
- name: Configure and start service
  block:
    - name: Generate config
      template: ...
    - name: Validate config
      command: ...
    - name: Backup old config
      copy: ...
    - name: Start service
      systemd: ...
  when: complex_condition

# After - split into logical units
- name: Prepare configuration
  include_tasks: prepare_config.yml
  when: needs_config_update

- name: Start service
  ansible.builtin.systemd:
    name: myservice
    state: started
  when: service_should_start
```

### Strategy 3: Use Descriptive Task Names
```yaml
# Before
- name: Run command
  command: /scripts/check.sh

# After
- name: "Verify {{ service_name }} configuration is valid"
  command: /scripts/check.sh
```

### Strategy 4: Linearize Nested Logic
```yaml
# Before
- block:
    - block:
        - command: step1
        - command: step2
      when: condition1
    - command: step3
  when: condition2

# After
- command: step1
  when: condition1 and condition2

- command: step2
  when: condition1 and condition2

- command: step3
  when: condition2
```

## Review Questions

When reviewing for complexity:

1. **Can I understand this task without scrolling?**
   - If no: Break it down

2. **Do I need to trace variable state mentally?**
   - If yes: Add intermediate variables with clear names

3. **Are there magic numbers or unexplained values?**
   - If yes: Extract to named variables with comments

4. **Would a new team member understand this?**
   - If no: Simplify or add detailed comments

5. **Does the task name accurately describe what happens?**
   - If no: Improve naming or split task

6. **Are there nested conditionals (when inside when)?**
   - If yes: Flatten with explicit variables

7. **Does logic use double negatives?**
   - If yes: Rewrite positively

8. **Are there more than 3 boolean operations in one condition?**
   - If yes: Extract sub-conditions

## Complexity Budget

Aim for:
- **Per task**: < 5 decision points
- **Per file**: < 15 decision points total
- **Nesting depth**: ≤ 3 levels
- **Variable lifespan**: ≤ 10 tasks
- **Line length**: ≤ 120 characters
- **Task file length**: ≤ 200 lines (split if longer)

These are guidelines, not hard rules. Occasionally exceeding them is fine with justification.
