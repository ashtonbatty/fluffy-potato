# TODO: Code Review Action Items

**Generated**: 2025-12-24
**Source**: CODE_REVIEW.md
**Total estimated effort**: 9.5-13.5 hours

---

## Priority 1: Critical Issues (2 hours) 🔴

### 1.1 DELETE unused vars files
- [ ] Delete `vars/workflow_sequences.yml` (completely unused)
- [ ] Decide fate of `vars/services.yml`: DELETE or implement dynamic workflows
- [ ] If deleting services.yml, update `docs/architecture.md` with service list documentation
- [ ] If keeping services.yml, implement dynamic workflow generation (see Priority 3)

**Files**:
- `vars/workflow_sequences.yml`
- `vars/services.yml`

**Estimated time**: 30 minutes
**Impact**: HIGH - Removes confusion, eliminates dead code

---

### 1.2 FIX: Add become escalation to systemd service tasks
- [ ] Edit `roles/appname/tasks/start_service.yml`
  - Add become block to systemd task (lines 4-9)
  - Pattern: `become: "{{ appname_service_become }}"`, etc.
- [ ] Edit `roles/appname/tasks/stop_service.yml`
  - Add become block to systemd task (lines 4-7)
- [ ] Edit `roles/appname/tasks/status_service.yml`
  - Add become block to systemd task (lines 2-6)
- [ ] Test with a systemd service to verify privilege escalation works
- [ ] Update CLAUDE.md with systemd privilege escalation notes

**Files**:
- `roles/appname/tasks/start_service.yml`
- `roles/appname/tasks/stop_service.yml`
- `roles/appname/tasks/status_service.yml`

**Code to add to each systemd task**:
```yaml
become: "{{ appname_service_become }}"
become_user: "{{ appname_service_become_user }}"
become_flags: "{{ appname_service_become_flags }}"
```

**Estimated time**: 15 minutes
**Impact**: HIGH - Fixes functional bug preventing systemd operations

---

### 1.3 DOCUMENT: Add inline comments to defaults/main.yml
- [ ] Add purpose comments for each variable
- [ ] Document which variables are required vs optional
- [ ] Explain interdependencies (e.g., process_identifier only used with scripts)
- [ ] Add format/range expectations (e.g., timeouts in seconds)
- [ ] Group related variables with section headers

**File**:
- `roles/appname/defaults/main.yml`

**Example format**:
```yaml
# ========================================
# SERVICE CONFIGURATION
# ========================================

# Name of the service (used in logs, reports, and systemd operations)
appname_service_name: "myservice"

# Script-based service control (OPTIONAL)
# Define this variable to use custom control scripts instead of systemd
# If undefined, role will use Ansible's systemd module
# Format: Absolute path to executable script
# appname_service_script: "/scripts/{{ appname_service_name }}.sh"

# Process identification for force-kill fallback (REQUIRED for script-based services)
# Used by pkill when graceful stop fails
# MUST be at least 5 characters to prevent accidental kills
# Common patterns: "COMPONENT=foo", "APP_NAME=bar", "python myapp.py"
# Default uses service name as component identifier
appname_process_identifier: "COMPONENT={{ appname_service_name }}"
```

**Estimated time**: 1 hour
**Impact**: HIGH - Significantly improves maintainability and onboarding

---

## Priority 2: Quick Wins (1.5 hours) 🟡

### 2.1 STANDARDIZE: Timestamp generation method
- [ ] Find all instances of `lookup('pipe', 'date ...')`
- [ ] Replace with `ansible_date_time.iso8601`
- [ ] Verify workflows still work correctly
- [ ] Update CLAUDE.md with standardized approach

**Files to update**:
- `playbooks/appname_stop.yml:69, 85, 119`
- `playbooks/appname_start.yml:88`
- `playbooks/appname_status.yml:88`
- `roles/appname/tasks/stop.yml:96`
- `roles/appname/tasks/execute_service_with_tracking.yml:9, 28, 44, 50`

**Search pattern**: `lookup('pipe', 'date`

**Replace with**: `ansible_date_time.iso8601`

**Note**: May need to gather_facts: true in plays that use this

**Estimated time**: 20 minutes
**Impact**: MEDIUM - Improves performance, removes shell dependencies

---

### 2.2 REFACTOR: Extract workflow finalization to common playbook
- [ ] Create directory: `playbooks/common/`
- [ ] Create file: `playbooks/common/finalize_workflow.yml`
- [ ] Move workflow completion logic from all 3 playbooks
- [ ] Update `playbooks/appname_start.yml` to import common finalization
- [ ] Update `playbooks/appname_stop.yml` to import common finalization
- [ ] Update `playbooks/appname_status.yml` to import common finalization
- [ ] Test all three workflows
- [ ] Update documentation

**New file**: `playbooks/common/finalize_workflow.yml`

**Content**:
```yaml
---
# Finalize workflow tracking and send comprehensive report
- name: "Complete workflow and send report"
  hosts: all_services
  gather_facts: false
  tasks:
    - name: "Calculate final workflow status"
      ansible.builtin.set_fact:
        final_status: "{{ 'failed' if hostvars['localhost']['workflow_metadata']['workflow_status'] == 'failed' else 'success' }}"
      delegate_to: localhost
      delegate_facts: true
      run_once: true

    - name: "Mark workflow as complete"
      ansible.builtin.set_fact:
        workflow_metadata: "{{ hostvars['localhost']['workflow_metadata'] | combine(final_metadata) }}"
      vars:
        final_metadata:
          workflow_end_time: "{{ ansible_date_time.iso8601 }}"
          workflow_status: "{{ final_status }}"
      delegate_to: localhost
      delegate_facts: true
      run_once: true

    - name: "Send comprehensive workflow report"
      ansible.builtin.include_tasks:
        file: ../../roles/appname/tasks/send_workflow_report.yml
      run_once: true
```

**Usage in workflow playbooks** (replace existing completion blocks):
```yaml
- name: "Finalize workflow"
  ansible.builtin.import_playbook: common/finalize_workflow.yml
```

**Estimated time**: 30 minutes
**Impact**: MEDIUM - Reduces duplication by ~75 lines

---

### 2.3 IMPROVE: Add section headers to complex task files
- [ ] Add section headers to `roles/appname/tasks/stop.yml`
- [ ] Add header documentation to `roles/appname/tasks/execute_service_with_tracking.yml`
- [ ] Add section comments to `roles/appname/templates/workflow_report.j2`

**Files**:
- `roles/appname/tasks/stop.yml`
- `roles/appname/tasks/execute_service_with_tracking.yml`
- `roles/appname/templates/workflow_report.j2`

**Example for stop.yml**:
```yaml
---
# ========================================
# IDEMPOTENCY CHECK
# ========================================
# Check if service is already stopped to avoid unnecessary operations

- name: "Check if service is already stopped for {{ appname_service_name }}"
  # ... existing task

# ========================================
# GRACEFUL STOP WITH FORCE-KILL FALLBACK
# ========================================
# Attempt graceful shutdown first, fall back to pkill if it fails
# Uses block-rescue pattern for error handling

- name: "Stop service with block-rescue pattern for {{ appname_service_name }}"
  when: appname_stopped_check_string not in appname_pre_stop_check.stdout
  block:
    # ... existing block tasks
  rescue:
    # ========================================
    # FORCE KILL VALIDATION AND EXECUTION
    # ========================================
    # Validate force kill is allowed and process identifier is safe
    # Then execute pkill and verify service is stopped

    # ... existing rescue tasks
```

**Example header for execute_service_with_tracking.yml**:
```yaml
---
# ========================================
# SERVICE EXECUTION WITH WORKFLOW TRACKING
# ========================================
# Reusable task for executing service operations with comprehensive workflow tracking
#
# This task implements the workflow tracking pattern:
# 1. Record task start time on localhost (delegated fact)
# 2. Execute service operation via appname role
# 3. Record success/failure in workflow_tasks array
# 4. Update workflow_metadata status on failure
# 5. Re-raise failures for proper error propagation
#
# Required variables:
#   - service_item: dict with 'name' key
#   - service_action: action to perform (start/stop/status)
#
# Workflow tracking variables (maintained on localhost):
#   - workflow_tasks: Array of task execution records
#   - workflow_metadata: Dict with workflow status and details
#
# Why facts are delegated to localhost:
#   - Workflow state must be shared across all plays/hosts
#   - Localhost serves as centralized tracking coordinator
#   - run_once ensures facts are set only once per workflow
```

**Estimated time**: 40 minutes
**Impact**: MEDIUM - Improves code comprehension for contributors

---

## Priority 3: Refactoring (6-10 hours) 🟢

### 3.1 REFACTOR: Implement dynamic workflow generation
- [ ] Design dynamic workflow architecture
- [ ] Update `vars/services.yml` with complete service definitions
- [ ] Create proof-of-concept for start workflow
- [ ] Test POC thoroughly
- [ ] Implement for stop workflow (with file monitoring)
- [ ] Implement for status workflow
- [ ] Update orchestrate.yml to use dynamic workflows
- [ ] Delete old hardcoded workflow playbooks
- [ ] Update all documentation
- [ ] Update CLAUDE.md with new architecture

**Benefits**:
- Reduce playbook code by ~70% (~240 lines)
- Single source of truth for service ordering
- Much easier to add new services (just edit vars/services.yml)

**Approach**:
```yaml
# Option A: Loop with dynamic plays (complex but flexible)
- name: "Execute service operations"
  hosts: "{{ service_item.value.group }}"
  vars_files:
    - "../{{ service_item.value.vars_file }}"
  tasks:
    - include_role:
        name: appname
  loop: "{{ services | dict2items | sort(attribute='value.order') }}"
  loop_control:
    loop_var: service_item

# Option B: Jinja2 template generation (easier to understand)
# Generate workflow playbooks from templates at runtime
```

**Files affected**:
- `vars/services.yml` (enhance or create)
- `playbooks/appname_start.yml` (delete or rewrite)
- `playbooks/appname_stop.yml` (delete or rewrite)
- `playbooks/appname_status.yml` (delete or rewrite)
- `orchestrate.yml` (update imports)

**Testing requirements**:
- Test with all three workflows
- Test with service failures
- Test with file monitoring
- Test with force-kill scenarios
- Verify workflow reporting works

**Estimated time**: 6-8 hours
**Impact**: HIGH - Major architectural improvement

---

### 3.2 REFACTOR: Consolidate service variable files
- [ ] Enhance `vars/services.yml` with all service definitions
- [ ] Delete `vars/foo.yml`
- [ ] Delete `vars/bar.yml`
- [ ] Delete `vars/elephant.yml`
- [ ] Update playbooks to use dict lookup from services.yml
- [ ] Update documentation

**Dependencies**: Should be done as part of 3.1 (dynamic workflow generation)

**New vars/services.yml structure**:
```yaml
---
services:
  foo:
    appname_service_name: "foo"
    appname_service_script: "/scripts/foo.sh"
    appname_process_identifier: "COMPONENT=foo"
    inventory_group: "foo_servers"
    order: 1
  bar:
    appname_service_name: "bar"
    appname_service_script: "/scripts/bar.sh"
    appname_process_identifier: "COMPONENT=bar"
    inventory_group: "bar_servers"
    order: 2
  elephant:
    appname_service_name: "elephant"
    appname_service_script: "/scripts/elephant.sh"
    appname_process_identifier: "COMPONENT=elephant"
    inventory_group: "elephant_servers"
    order: 3
```

**Estimated time**: 1 hour (if done with 3.1)
**Impact**: MEDIUM - Simplifies service management

---

### 3.3 FIX: Configure ansible-lint properly
- [ ] Run `ansible-lint` to see all current warnings
- [ ] Review `run-once` warnings specifically
- [ ] Decide: refactor code or disable rule
- [ ] Create or update `.ansible-lint` configuration
- [ ] Remove all `# noqa: run-once` comments
- [ ] Re-run ansible-lint to verify
- [ ] Update CI/CD pipeline if needed

**Recommended approach**: Add skip_list since run_once is legitimate

**Create/update**: `.ansible-lint`
```yaml
---
# Ansible Lint configuration
# See: https://ansible-lint.readthedocs.io/

skip_list:
  - run-once[task]  # Legitimate use in workflow tracking - facts must be set once on localhost

# Enable specific rules
enable_list:
  - yaml[line-length]
  - yaml[trailing-spaces]

# Configure rules
rules:
  line-length:
    max: 160
```

**Estimated time**: 30 minutes
**Impact**: LOW - Improves code cleanliness

---

### 3.4 ENHANCE: Expand Molecule test coverage
- [ ] Review current Molecule tests
- [ ] Add test for force-kill scenario
- [ ] Add test for non-standard return codes
- [ ] Add test for file monitoring
- [ ] Add test for systemd-based services
- [ ] Add test for workflow reporting
- [ ] Add test for become escalation
- [ ] Document test scenarios
- [ ] Add tests to CI/CD pipeline

**Directory**: `roles/appname/molecule/default/`

**Test scenarios to add**:
1. Force-kill when graceful stop fails
2. Script with non-zero success return code
3. File monitoring timeout
4. Systemd service operations
5. Email notification generation
6. Workflow failure handling

**Estimated time**: 4-6 hours
**Impact**: MEDIUM - Improves confidence in changes

---

## Additional Improvements (Optional)

### Extract force-kill validation
- [ ] Create `roles/appname/tasks/validate_force_kill.yml`
- [ ] Move validation logic from stop.yml rescue block
- [ ] Update stop.yml to include new validation file
- [ ] Test force-kill scenarios

**Estimated time**: 30 minutes
**Impact**: LOW - Improves modularity

---

### Simplify "skip if failed" pattern
- [ ] Refactor workflow playbooks to use block-rescue at play level
- [ ] Remove individual "skip if previous task failed" checks
- [ ] Test error propagation
- [ ] Update documentation

**Estimated time**: 1 hour
**Impact**: LOW - Simplifies code slightly

---

### Standardize variable checks
- [ ] Define all feature flags explicitly in defaults/main.yml
- [ ] Remove `| default(...)` filters from task files
- [ ] Test with all feature flags enabled/disabled

**Estimated time**: 20 minutes
**Impact**: LOW - Minor code cleanup

---

## Testing Checklist

After completing changes, verify:

- [ ] All three workflows (start/stop/status) execute successfully
- [ ] Force-kill fallback works correctly
- [ ] File monitoring functions as expected
- [ ] Email reports are generated properly
- [ ] Systemd-based services work (if implemented)
- [ ] Script-based services work
- [ ] Return code handling works for non-zero codes
- [ ] Workflow tracking captures all events
- [ ] ansible-lint passes with no warnings
- [ ] yamllint passes
- [ ] All playbooks pass syntax check
- [ ] Molecule tests pass (if expanded)
- [ ] Documentation is up to date

---

## Completion Tracking

### Priority 1 (Critical)
- [ ] 1.1 Delete unused vars files (30 min)
- [ ] 1.2 Add become escalation to systemd (15 min)
- [ ] 1.3 Document defaults/main.yml (1 hour)

**Total P1**: 0/3 complete | 1h 45m remaining

### Priority 2 (Quick Wins)
- [ ] 2.1 Standardize timestamps (20 min)
- [ ] 2.2 Extract workflow finalization (30 min)
- [ ] 2.3 Add section headers (40 min)

**Total P2**: 0/3 complete | 1h 30m remaining

### Priority 3 (Refactoring)
- [ ] 3.1 Dynamic workflow generation (6-8 hours)
- [ ] 3.2 Consolidate service vars (1 hour)
- [ ] 3.3 Configure ansible-lint (30 min)
- [ ] 3.4 Expand test coverage (4-6 hours)

**Total P3**: 0/4 complete | 11h 30m - 15h 30m remaining

---

## Notes

- Priority 1 tasks should be completed before any new features
- Priority 2 tasks provide immediate value with minimal risk
- Priority 3 tasks are longer-term improvements, evaluate ROI
- Each completed task should be committed separately
- Update CLAUDE.md as architectural changes are made
- Run full test suite after each priority level completion

---

**End of TODO**
