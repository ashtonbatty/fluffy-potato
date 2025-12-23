#!/bin/bash
#
# Rename Ansible Role and Update All References
#
# This script renames an Ansible role and updates all variable prefixes
# and role references throughout the codebase. Useful for adapting this
# framework for different applications.
#
# Usage:
#   ./rename_role.sh OLD_NAME NEW_NAME
#
# Example:
#   ./rename_role.sh appname myapp
#
# What it does:
#   1. Renames roles/OLD_NAME/ to roles/NEW_NAME/
#   2. Replaces all OLD_NAME_ variable prefixes with NEW_NAME_
#   3. Updates all role references in playbooks and documentation
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS: $1${NC}"
}

print_info() {
    echo -e "${YELLOW}INFO: $1${NC}"
}

# Validate arguments
if [ $# -ne 2 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 OLD_NAME NEW_NAME"
    echo "Example: $0 appname myapp"
    exit 1
fi

OLD_NAME="$1"
NEW_NAME="$2"

# Validate that old role exists
if [ ! -d "roles/${OLD_NAME}" ]; then
    print_error "Role 'roles/${OLD_NAME}' does not exist"
    exit 1
fi

# Validate that new role doesn't already exist
if [ -d "roles/${NEW_NAME}" ]; then
    print_error "Role 'roles/${NEW_NAME}' already exists"
    exit 1
fi

# Confirm with user
print_info "This will rename role '${OLD_NAME}' to '${NEW_NAME}'"
print_info "All ${OLD_NAME}_ variables will become ${NEW_NAME}_"
print_info "All role references will be updated"
echo -n "Continue? [y/N] "
read -r confirmation
if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
    print_error "Aborted by user"
    exit 1
fi

echo ""
print_info "Starting rename operation..."
echo ""

# 1. Rename role directory
print_info "Step 1: Renaming role directory roles/${OLD_NAME}/ -> roles/${NEW_NAME}/"
mv "roles/${OLD_NAME}" "roles/${NEW_NAME}"
print_success "Role directory renamed"

# 2. Update variable prefixes in all YAML files
print_info "Step 2: Updating ${OLD_NAME}_ variable prefixes to ${NEW_NAME}_ in all YAML files"
find . -type f \( -name "*.yml" -o -name "*.yaml" \) \
    -not -path "./.git/*" \
    -not -path "./venv/*" \
    -not -path "./.venv/*" \
    -exec sed -i "s/${OLD_NAME}_/${NEW_NAME}_/g" {} +
print_success "Variable prefixes updated in YAML files"

# 3. Update role references in playbooks (roles: list)
print_info "Step 3: Updating role references in playbooks (roles: list)"
find . -type f \( -name "*.yml" -o -name "*.yaml" \) \
    -not -path "./.git/*" \
    -not -path "./venv/*" \
    -not -path "./.venv/*" \
    -exec sed -i "s/- ${OLD_NAME}$/- ${NEW_NAME}/g" {} +
print_success "Role references updated in playbooks"

# 4. Update include_role and import_role name references
print_info "Step 4: Updating include_role/import_role name references"
find . -type f \( -name "*.yml" -o -name "*.yaml" \) \
    -not -path "./.git/*" \
    -not -path "./venv/*" \
    -not -path "./.venv/*" \
    -exec sed -i "s/name: ${OLD_NAME}$/name: ${NEW_NAME}/g" {} +
print_success "Include/import role references updated"

# 5. Update role_name in meta/main.yml (handles YAML indentation)
print_info "Step 5: Updating role_name in meta/main.yml"
if [ -f "roles/${NEW_NAME}/meta/main.yml" ]; then
    sed -i "s/role_name: ${OLD_NAME}/role_name: ${NEW_NAME}/g" "roles/${NEW_NAME}/meta/main.yml"
    print_success "Role name updated in meta/main.yml"
else
    print_info "No meta/main.yml found, skipping"
fi

# 6. Rename workflow playbook files
print_info "Step 6: Renaming workflow playbook files"
if [ -f "playbooks/${OLD_NAME}_start.yml" ]; then
    mv "playbooks/${OLD_NAME}_start.yml" "playbooks/${NEW_NAME}_start.yml"
    print_success "Renamed ${OLD_NAME}_start.yml -> ${NEW_NAME}_start.yml"
fi
if [ -f "playbooks/${OLD_NAME}_stop.yml" ]; then
    mv "playbooks/${OLD_NAME}_stop.yml" "playbooks/${NEW_NAME}_stop.yml"
    print_success "Renamed ${OLD_NAME}_stop.yml -> ${NEW_NAME}_stop.yml"
fi
if [ -f "playbooks/${OLD_NAME}_status.yml" ]; then
    mv "playbooks/${OLD_NAME}_status.yml" "playbooks/${NEW_NAME}_status.yml"
    print_success "Renamed ${OLD_NAME}_status.yml -> ${NEW_NAME}_status.yml"
fi

# 7. Update role references in documentation
print_info "Step 7: Updating role references in documentation"
find . -type f \( -name "*.md" -o -name "CLAUDE.md" \) \
    -not -path "./.git/*" \
    -exec sed -i "s/${OLD_NAME}_/${NEW_NAME}_/g" {} +

find . -type f \( -name "*.md" -o -name "CLAUDE.md" \) \
    -not -path "./.git/*" \
    -exec sed -i "s/roles\/${OLD_NAME}/roles\/${NEW_NAME}/g" {} +

find . -type f \( -name "*.md" -o -name "CLAUDE.md" \) \
    -not -path "./.git/*" \
    -exec sed -i "s/- ${OLD_NAME}$/- ${NEW_NAME}/g" {} +
print_success "Documentation updated"

# 8. Summary
echo ""
print_success "Rename operation completed successfully!"
echo ""
print_info "Summary of changes:"
echo "  - Role directory: roles/${OLD_NAME}/ -> roles/${NEW_NAME}/"
echo "  - Variable prefix: ${OLD_NAME}_ -> ${NEW_NAME}_"
echo "  - Role name in meta.yml: role_name: ${OLD_NAME} -> role_name: ${NEW_NAME}"
echo "  - Include/import role references: name: ${OLD_NAME} -> name: ${NEW_NAME}"
echo "  - Workflow playbooks: ${OLD_NAME}_*.yml -> ${NEW_NAME}_*.yml"
echo "  - Role references updated in all playbooks and documentation"
echo ""
print_info "Next steps:"
echo "  1. Review the changes: git diff"
echo "  2. Test the playbooks: ansible-playbook --syntax-check orchestrate.yml"
echo "  3. Run linter: ansible-lint"
echo "  4. Commit the changes: git add -A && git commit -m 'Rename role ${OLD_NAME} to ${NEW_NAME}'"
echo ""
