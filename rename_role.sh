#!/bin/bash
#
# rename_role.sh - Rename the appname role to your desired name
#
# Usage:
#   ./rename_role.sh <new_role_name>
#
# Example:
#   ./rename_role.sh myapp
#
# This will:
#   - Rename roles/appname/ to roles/myapp/
#   - Replace all instances of 'appname' with 'myapp' in all files
#   - Rename playbooks/appname_*.yml to playbooks/myapp_*.yml
#

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

# Validate arguments
if [ $# -ne 1 ]; then
    print_error "Invalid number of arguments"
    echo "Usage: $0 <new_role_name>"
    echo "Example: $0 myapp"
    exit 1
fi

NEW_NAME="$1"

# Validate new role name is lowercase letters only
if ! [[ "$NEW_NAME" =~ ^[a-z]+$ ]]; then
    print_error "Role name must contain only lowercase letters"
    echo "Got: '$NEW_NAME'"
    echo "Valid examples: myapp, loganalytics, webservice"
    exit 1
fi

# Check that appname role exists
if [ ! -d "roles/appname" ]; then
    print_error "roles/appname/ directory not found"
    echo "Are you running this from the repository root?"
    exit 1
fi

# Check that new role doesn't already exist
if [ -d "roles/${NEW_NAME}" ]; then
    print_error "roles/${NEW_NAME}/ already exists"
    echo "Choose a different name or remove the existing directory"
    exit 1
fi

# Show what will be done
echo ""
echo "This will rename 'appname' to '${NEW_NAME}' throughout the repository:"
echo "  - Rename roles/appname/ → roles/${NEW_NAME}/"
echo "  - Replace 'appname' with '${NEW_NAME}' in all files"
echo "  - Rename playbooks/appname_*.yml → playbooks/${NEW_NAME}_*.yml"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 0
fi

echo ""
print_info "Starting rename operation..."
echo ""

# Step 1: Rename the role directory
print_info "Step 1: Renaming role directory..."
mv "roles/appname" "roles/${NEW_NAME}"
print_success "Renamed roles/appname/ → roles/${NEW_NAME}/"

# Step 2: Replace 'appname' in all text files
print_info "Step 2: Replacing 'appname' with '${NEW_NAME}' in all files..."

# Find all text files (YAML, Markdown, Python, Shell scripts, etc.)
# Exclude .git directory and other non-text directories
find . \( \
    -name "*.yml" -o \
    -name "*.yaml" -o \
    -name "*.md" -o \
    -name "*.py" -o \
    -name "*.sh" -o \
    -name "*.j2" -o \
    -name "*.txt" -o \
    -name "*.cfg" -o \
    -name "*.ini" \
    \) \
    -not -path "./.git/*" \
    -not -path "./venv/*" \
    -not -path "./.venv/*" \
    -type f \
    -exec sed -i "s/appname/${NEW_NAME}/g" {} +

print_success "Replaced 'appname' with '${NEW_NAME}' in all text files"

# Step 3: Rename workflow playbooks
print_info "Step 3: Renaming workflow playbooks..."

RENAMED_COUNT=0

if [ -f "playbooks/appname_start.yml" ]; then
    mv "playbooks/appname_start.yml" "playbooks/${NEW_NAME}_start.yml"
    print_success "Renamed appname_start.yml → ${NEW_NAME}_start.yml"
    RENAMED_COUNT=$((RENAMED_COUNT + 1))
fi

if [ -f "playbooks/appname_stop.yml" ]; then
    mv "playbooks/appname_stop.yml" "playbooks/${NEW_NAME}_stop.yml"
    print_success "Renamed appname_stop.yml → ${NEW_NAME}_stop.yml"
    RENAMED_COUNT=$((RENAMED_COUNT + 1))
fi

if [ -f "playbooks/appname_status.yml" ]; then
    mv "playbooks/appname_status.yml" "playbooks/${NEW_NAME}_status.yml"
    print_success "Renamed appname_status.yml → ${NEW_NAME}_status.yml"
    RENAMED_COUNT=$((RENAMED_COUNT + 1))
fi

if [ $RENAMED_COUNT -eq 0 ]; then
    echo "  (No playbooks found to rename)"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_success "Rename complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Role 'appname' has been renamed to '${NEW_NAME}'"
echo ""
echo "Next steps:"
echo "  1. Review changes:        git diff"
echo "  2. Test syntax:           ansible-playbook --syntax-check orchestrate.yml"
echo "  3. Run linter:            ansible-lint"
echo "  4. Commit changes:        git add -A && git commit -m 'Rename role to ${NEW_NAME}'"
echo ""
print_info "Remember to update your inventory group_vars files with your actual service configurations"
echo ""
