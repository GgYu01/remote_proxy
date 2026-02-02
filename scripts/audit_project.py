#!/usr/bin/env python3
import os
import sys
import subprocess

# ==============================================================================
# Script Name: audit_project.py
# Description: Strict self-audit to ensure project integrity before delivery.
# ==============================================================================

REQUIRED_FILES = [
    "install.sh",
    "config.env.example",
    "scripts/setup_env.sh",
    "scripts/manage_swap.sh",
    "scripts/gen_config.py",
    "scripts/deploy.sh",
    "scripts/verify.sh",
    "docs/REQUIREMENTS_POOL.md",
    "docs/DESIGN_ARCHITECTURE.md",
    "docs/HANDOVER_MANUAL.md",
    "docs/DECISION_LOG.md",
    "README.md",
    "PLAN.md"
]

def log_pass(msg):
    print(f"[PASS] {msg}")

def log_fail(msg):
    print(f"[FAIL] {msg}")
    return False

def check_files_exist():
    all_pass = True
    for f in REQUIRED_FILES:
        if os.path.exists(f):
            log_pass(f"File exists: {f}")
        else:
            log_fail(f"Missing file: {f}")
            all_pass = False
    return all_pass

def check_scripts_executable():
    all_pass = True
    scripts = [f for f in REQUIRED_FILES if f.endswith('.sh')]
    for s in scripts:
        if os.access(s, os.X_OK):
            log_pass(f"Executable: {s}")
        else:
            # Try to chmod it
            try:
                os.chmod(s, 0o755)
                log_pass(f"Fixed permissions: {s}")
            except Exception as e:
                log_fail(f"Not executable and failed to fix: {s} ({e})")
                all_pass = False
    return all_pass

def check_syntax():
    all_pass = True
    # Bash syntax
    bash_scripts = [f for f in REQUIRED_FILES if f.endswith('.sh')]
    for s in bash_scripts:
        try:
            subprocess.run(['bash', '-n', s], check=True, capture_output=True)
            log_pass(f"Bash syntax OK: {s}")
        except subprocess.CalledProcessError as e:
            log_fail(f"Bash syntax error in {s}: {e.stderr.decode()}")
            all_pass = False
        except FileNotFoundError:
            log_fail("bash command not found")
            all_pass = False

    # Python syntax
    py_scripts = [f for f in REQUIRED_FILES if f.endswith('.py')]
    for s in py_scripts:
        try:
            import py_compile
            py_compile.compile(s, doraise=True)
            log_pass(f"Python syntax OK: {s}")
        except Exception as e:
            log_fail(f"Python syntax error in {s}: {e}")
            all_pass = False
    return all_pass

def main():
    print(">>> Starting Strict Project Audit...")
    
    checks = [
        ("File Integrity", check_files_exist),
        ("Permissions", check_scripts_executable),
        ("Syntax Validation", check_syntax)
    ]
    
    overall_status = True
    for name, func in checks:
        print(f"\n--- {name} ---")
        if not func():
            overall_status = False
    
    print("\n========================================")
    if overall_status:
        print("AUDIT PASSED. Project is ready for delivery.")
        sys.exit(0)
    else:
        print("AUDIT FAILED. Please fix issues above.")
        sys.exit(1)

if __name__ == '__main__':
    main()
