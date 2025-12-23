#!/usr/bin/env python3
"""
Run ansible-lint and return structured output for code review.
"""
import subprocess
import json
import sys
from pathlib import Path


def run_ansible_lint(path="."):
    """Run ansible-lint and return results."""
    try:
        result = subprocess.run(
            ["ansible-lint", "--format", "json", path],
            capture_output=True,
            text=True,
            timeout=60
        )

        # ansible-lint returns non-zero on findings, which is expected
        output = {
            "success": True,
            "findings": [],
            "summary": ""
        }

        if result.stdout:
            try:
                lint_output = json.loads(result.stdout)
                output["findings"] = lint_output
            except json.JSONDecodeError:
                # Fallback to text output
                output["findings"] = result.stdout

        if result.stderr:
            output["stderr"] = result.stderr

        # Generate summary
        if isinstance(output["findings"], list):
            output["summary"] = f"Found {len(output['findings'])} ansible-lint findings"
        else:
            output["summary"] = "ansible-lint completed"

        return output

    except FileNotFoundError:
        return {
            "success": False,
            "error": "ansible-lint not found. Install with: pip install ansible-lint"
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": "ansible-lint timed out after 60 seconds"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "."
    result = run_ansible_lint(path)
    print(json.dumps(result, indent=2))
