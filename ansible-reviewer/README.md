# Ansible Reviewer Skill

This directory contains a Claude Code skill for comprehensive Ansible code review.

## Purpose

Provides specialized code review capabilities for Ansible projects, including:
- Best practices compliance checking
- Security vulnerability detection
- Code quality and readability analysis
- Complexity and maintainability assessment
- Performance concern identification

## Contents

- `SKILL.md` - Claude Code skill definition with review workflow and criteria
- `references/` - Reference documentation for security checklists, best practices
- `scripts/` - Python analysis scripts for automated checks:
  - `run_ansible_lint.py` - Wrapper for ansible-lint with custom reporting
  - `analyze_role_structure.py` - Role structure analysis tool

## Usage

This skill is automatically available in Claude Code when working in this repository.
The skill can be invoked for code review tasks or will be suggested when reviewing
Ansible playbooks, roles, or collections.

## Related Files

- `.ansible-lint` - Project-specific ansible-lint configuration
- `.yamllint` - YAML linting rules
- `CODE_REVIEW.md` - Results from previous code reviews
- `TODO.md` - Action items from code reviews
