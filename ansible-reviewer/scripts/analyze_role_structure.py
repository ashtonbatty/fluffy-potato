#!/usr/bin/env python3
"""
Analyze Ansible role directory structure for compliance and best practices.
"""
import json
import sys
from pathlib import Path


def analyze_role_structure(role_path="."):
    """Analyze role directory structure."""
    role_path = Path(role_path)

    analysis = {
        "role_name": role_path.name,
        "structure": {},
        "issues": [],
        "recommendations": []
    }

    # Expected role directories
    expected_dirs = {
        "tasks": "Task files (main.yml required)",
        "handlers": "Handler files",
        "templates": "Jinja2 templates",
        "files": "Static files",
        "vars": "Variable files",
        "defaults": "Default variables (main.yml recommended)",
        "meta": "Role metadata (main.yml for Galaxy)",
        "library": "Custom modules",
        "module_utils": "Module utilities",
        "lookup_plugins": "Custom lookup plugins"
    }

    # Check for standard directories
    for dir_name, description in expected_dirs.items():
        dir_path = role_path / dir_name
        if dir_path.exists() and dir_path.is_dir():
            files = list(dir_path.glob("**/*"))
            file_count = len([f for f in files if f.is_file()])
            analysis["structure"][dir_name] = {
                "exists": True,
                "file_count": file_count,
                "description": description
            }
        else:
            analysis["structure"][dir_name] = {
                "exists": False,
                "description": description
            }

    # Check for required files
    tasks_main = role_path / "tasks" / "main.yml"
    if not tasks_main.exists():
        analysis["issues"].append({
            "severity": "error",
            "message": "Missing tasks/main.yml - required entry point for role"
        })

    # Check for README
    readme_files = list(role_path.glob("README*"))
    if not readme_files:
        analysis["recommendations"].append({
            "type": "documentation",
            "message": "Consider adding README.md to document the role"
        })

    # Check for meta/main.yml
    meta_main = role_path / "meta" / "main.yml"
    if not meta_main.exists():
        analysis["recommendations"].append({
            "type": "metadata",
            "message": "Consider adding meta/main.yml for Ansible Galaxy compatibility"
        })

    # Check for defaults/main.yml
    defaults_main = role_path / "defaults" / "main.yml"
    if not defaults_main.exists():
        analysis["recommendations"].append({
            "type": "variables",
            "message": "Consider adding defaults/main.yml to define role defaults"
        })

    # Check for tests
    tests_dir = role_path / "tests"
    molecule_dir = role_path / "molecule"
    if not tests_dir.exists() and not molecule_dir.exists():
        analysis["recommendations"].append({
            "type": "testing",
            "message": "Consider adding tests/ or molecule/ directory for role testing"
        })

    # Summary
    analysis["summary"] = {
        "directories_present": len([d for d in analysis["structure"].values() if d["exists"]]),
        "total_expected": len(expected_dirs),
        "issue_count": len(analysis["issues"]),
        "recommendation_count": len(analysis["recommendations"])
    }

    return analysis


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "."
    result = analyze_role_structure(path)
    print(json.dumps(result, indent=2))
