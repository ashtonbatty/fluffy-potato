---
name: ansible-reviewer
description: >
  Comprehensive code review for Ansible projects including playbooks, roles, and collections.
  Use when reviewing Ansible code for: (1) Pull requests or code changes, (2) Best practices
  compliance, (3) Security vulnerabilities, (4) Code quality and readability, (5) Complexity
  and maintainability issues, (6) Performance concerns, or (7) When the user asks to review
  Ansible code or mentions ansible-lint, role structure, or playbook quality.
---

# Ansible Reviewer

Specialized code review skill for Ansible projects covering architecture, security, quality, best practices, readability, complexity, and simplicity.

## Review Workflow

### 1. Initial Analysis

**Determine project scope:**
- Single playbook, role, or full project?
- Check for `.ansible-lint`, `ansible.cfg`, role structure
- Identify entry points (site.yml, main.yml, etc.)

**Run automated checks:**
```bash
python scripts/run_ansible_lint.py [path]
```

For roles, also run:
```bash
python scripts/analyze_role_structure.py [role-path]
```

### 2. Structured Review

Review code across these dimensions:

#### A. Architecture & Design
- **DRY Principle**: Code reuse via roles, includes
- **Idempotency**: Tasks safe to run repeatedly
- **Task Organization**: Logical file structure
- **Separation of Concerns**: Clear role/playbook boundaries

**Red flags:**
- Monolithic main.yml files (>200 lines)
- Duplicated task sequences
- Mixed concerns (app install + monitoring in one role)

#### B. Security Controls
**Critical - Always review. Reference: [security-checklist.md](references/security-checklist.md)**

Quick checks:
- Input validation for user-provided values
- Secrets management (Vault usage, no_log)
- Privilege escalation (become only when needed)
- Command injection prevention (proper quoting)
- File permissions (explicit mode/owner for sensitive files)

#### C. Code Quality
**Reference: [best-practices.md](references/best-practices.md)**

- Module usage (FQCN, prefer specific modules over shell)
- Task attributes (proper failed_when, changed_when)
- Variable naming (role prefixes, clear names)
- Error handling (block-rescue patterns)

#### D. Common Antipatterns
**Reference: [common-antipatterns.md](references/common-antipatterns.md)**

Check for:
- Shell/command abuse instead of dedicated modules
- Missing changed_when on commands
- No variable prefixes (namespace pollution)
- Hardcoded values
- Global become
- Ignore_errors without justification

#### E. Readability & Cognitive Complexity
**Reference: [complexity-patterns.md](references/complexity-patterns.md)**

Evaluate:
- **Task names**: Descriptive, include context
- **Nested conditionals**: Deep when/failed_when logic
- **Complex expressions**: Boolean operations in conditions
- **Variable clarity**: Named intermediate values
- **Magic numbers**: Unexplained values

**Metrics:**
- Decision points per task: Target < 5
- Nesting depth: Target ≤ 3 levels
- File length: Target < 200 lines (split if longer)

**Simplification strategies:**
- Extract named conditions
- Split complex tasks
- Add explanatory comments
- Linearize nested logic

#### F. Simplicity & YAGNI
**Reference: [simplicity-principles.md](references/simplicity-principles.md)**

Look for:
- **Over-abstraction**: Dynamic patterns for < 3 uses
- **Premature optimization**: Complex structure for simple needs
- **Gold plating**: Features "just in case"
- **Unnecessary indirection**: Deep include chains

**Key principles:**
- Don't abstract until 3rd occurrence
- Duplication > wrong abstraction
- Explicit > implicit
- Standard modules > custom solutions

**Review questions:**
- Does this solve a real or hypothetical problem?
- Could this be simpler?
- Would deleting this break anything?
- Is this abstraction justified?

#### G. Performance
- Gather facts usage (disable when not needed)
- Async/poll for long operations
- Serial execution strategy
- Loop efficiency

#### H. Documentation
- Task names and comments
- Variable documentation in defaults
- README for roles
- Examples provided

### 3. Generate Review Report

Structure the review as:

```markdown
# Ansible Code Review: [Project Name]

## Overview
[1-2 sentence summary of project and review scope]

## Automated Checks
- ansible-lint: [Pass/Fail with count]
- Role structure: [Analysis if applicable]

## Strengths
[Positive findings - what's done well]

## Issues by Priority

### High Priority
[Critical issues - security, correctness]

### Medium Priority
[Quality issues - maintainability, performance]

### Low Priority
[Nice-to-haves - documentation, style]

## Complexity Analysis
[Cognitive complexity concerns if any]

## Simplicity Recommendations
[Over-engineering or YAGNI violations if any]

## Specific Recommendations
[Detailed line-by-line feedback with file:line references]

## Summary
[Overall assessment and next steps]
```

### 4. Provide Actionable Feedback

**For each issue:**
- Location: `file.yml:line`
- Problem: Clear description
- Impact: Why it matters
- Solution: Specific fix with code example

**Example:**
```
**Location:** `roles/app/tasks/main.yml:42`

**Problem:** Using shell module for file operations
**Impact:** Not idempotent, fails in check mode
**Solution:**
```yaml
# Current (bad)
- shell: mkdir -p /opt/app

# Recommended
- file:
    path: /opt/app
    state: directory
```

## Reference Materials

This skill includes detailed reference documents:

- **[security-checklist.md](references/security-checklist.md)** - Security review checklist with examples
- **[best-practices.md](references/best-practices.md)** - Ansible coding standards and patterns
- **[common-antipatterns.md](references/common-antipatterns.md)** - What to avoid with examples
- **[complexity-patterns.md](references/complexity-patterns.md)** - Identifying and reducing cognitive complexity
- **[simplicity-principles.md](references/simplicity-principles.md)** - YAGNI and avoiding over-engineering

**When to read references:**
- Security: Always skim for critical issues
- Complexity/Simplicity: When code feels hard to understand
- Antipatterns: When something "smells wrong"
- Best practices: When unsure if approach is idiomatic

## Review Scope Adjustment

**For small changes (< 100 lines):**
- Focus on changed lines + context
- Quick security scan
- Complexity check on modified tasks

**For full projects:**
- Run both scripts
- Review all dimensions
- Prioritize by criticality
- Sample representative files if > 50 files

**For roles:**
- Always check structure
- Focus on tasks/ and defaults/
- Verify handlers are used
- Check meta/main.yml for Galaxy

## Tips for Effective Reviews

1. **Be constructive**: Praise good patterns
2. **Be specific**: Include file:line references
3. **Prioritize**: High/Medium/Low
4. **Provide examples**: Show don't just tell
5. **Consider context**: Production vs learning project
6. **Balance**: Don't nitpick style if security is broken
7. **Focus on impact**: Explain why each issue matters

## Common Review Scenarios

**Scenario: PR Review**
- Run ansible-lint first
- Focus on changed files
- Check for new security issues
- Verify idempotency of changes

**Scenario: Security Audit**
- Read security-checklist.md first
- Check all become usage
- Verify secrets management
- Review input validation
- Check file permissions

**Scenario: Performance Review**
- Look for serial bottlenecks
- Check gather_facts usage
- Review loop efficiency
- Identify async opportunities

**Scenario: Complexity Review**
- Read complexity-patterns.md
- Identify nested conditionals
- Check failed_when logic
- Review variable naming
- Count decision points

**Scenario: Refactoring Review**
- Read simplicity-principles.md
- Look for over-abstraction
- Check for YAGNI violations
- Verify abstractions are justified
- Confirm net reduction in complexity
