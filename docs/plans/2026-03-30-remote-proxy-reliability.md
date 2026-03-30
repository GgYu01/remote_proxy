# Remote Proxy Reliability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Turn `remote_proxy` into a reliable deployment baseline for standalone VPS rollout and `infra-core` sidecar integration, with durable documentation and safer operational behavior.

**Architecture:** Keep one repository but explicitly split supported deployment topologies. Harden the script path only for standalone VPS. Document `infra-core` as an integration path. Add tests for high-risk behavior before modifying production scripts.

**Tech Stack:** Bash, Python 3, sing-box, Podman, systemd, Markdown documentation.

---

### Task 1: Establish Design and Docs Skeleton

**Files:**
- Create: `docs/plans/2026-03-30-remote-proxy-reliability-design.md`
- Create: `docs/plans/2026-03-30-remote-proxy-reliability.md`
- Create: `docs/deploy/standalone-vps.md`
- Create: `docs/deploy/infra-core-ubuntu-online.md`
- Create: `docs/clients/android.md`
- Create: `docs/clients/windows.md`
- Create: `docs/clients/linux.md`
- Create: `docs/security/secrets-and-rotation.md`
- Create: `docs/ops/troubleshooting.md`
- Create: `docs/ops/host-baselines.md`
- Modify: `README.md`

**Step 1: Write the failing documentation consistency test**

Add a test that asserts the README references the new docs and does not mention outdated command names or `.env` as the primary config filename.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_docs_consistency -v`

Expected: failure because the current docs still reference outdated names and missing files.

**Step 3: Update docs to match the approved topology split**

Write the new docs and rewrite the README as the stable entrypoint.

**Step 4: Re-run test**

Run: `python -m unittest tests.test_docs_consistency -v`

Expected: PASS.

### Task 2: Make Managed Secret/Config Updates Idempotent

**Files:**
- Modify: `scripts/gen_keys.sh`
- Add: `tests/test_gen_keys.py`

**Step 1: Write the failing test**

Add tests that run `scripts/gen_keys.sh` in a temp workspace with mocked `podman` output and assert:

- `VLESS_UUID` is not duplicated on repeated runs;
- `REALITY_PRIVATE_KEY`, `REALITY_PUBLIC_KEY`, `REALITY_SHORT_ID` are replaced or preserved deterministically;
- resulting `config.env` contains a single active assignment per managed key.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_gen_keys -v`

Expected: failure because the current script appends duplicate keys.

**Step 3: Implement minimal idempotent update logic**

Refactor `scripts/gen_keys.sh` to update managed keys in place rather than append blind duplicates.

**Step 4: Re-run test**

Run: `python -m unittest tests.test_gen_keys -v`

Expected: PASS.

### Task 3: Redact Sensitive Data From Verification Output

**Files:**
- Modify: `scripts/verify.sh`
- Add: `tests/test_verify_script.py`

**Step 1: Write the failing test**

Add a test that executes `scripts/verify.sh` in a controlled temp environment with mocked `curl`, `ss`, and config values, then asserts raw credentials are not printed.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_verify_script -v`

Expected: failure because current output includes `user:password@`.

**Step 3: Implement minimal redaction**

Keep functional verification but print sanitized endpoint labels instead of full credential-bearing proxy URLs.

**Step 4: Re-run test**

Run: `python -m unittest tests.test_verify_script -v`

Expected: PASS.

### Task 4: Harden Deploy Configuration Surface

**Files:**
- Modify: `config.env.example`
- Modify: `scripts/deploy.sh`
- Add: `tests/test_deploy_script.py`

**Step 1: Write the failing test**

Add tests that assert generated service definitions:

- honor a pinned sing-box image variable;
- apply a sane minimum memory floor;
- optionally include documented compatibility env flags when enabled.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_deploy_script -v`

Expected: failure because the current script hardcodes `latest` and lacks config-driven compatibility env handling.

**Step 3: Implement the minimal deploy hardening**

Update config surface and deploy generation.

**Step 4: Re-run test**

Run: `python -m unittest tests.test_deploy_script -v`

Expected: PASS.

### Task 5: Refresh Local Verification Entry Points

**Files:**
- Modify: `tests/simulate_install.sh`
- Modify: `scripts/audit_project.py`

**Step 1: Write the failing test**

Add a test or assertion path that proves documentation files and script checks align with the new structure.

**Step 2: Run the check to verify it fails**

Run: `python scripts/audit_project.py`

Expected: failure if required files or references are stale.

**Step 3: Update the verification helpers**

Bring the audit/simulation helpers in line with the new doc tree and script expectations.

**Step 4: Re-run**

Run: `python scripts/audit_project.py`

Expected: PASS.

### Task 6: Full Verification

**Files:**
- Verify only

**Step 1: Run focused unit tests**

Run:

```bash
python -m unittest tests.test_docs_consistency tests.test_gen_keys tests.test_verify_script tests.test_deploy_script -v
```

Expected: all pass.

**Step 2: Run project audit**

Run:

```bash
python scripts/audit_project.py
```

Expected: PASS.

**Step 3: Run simulated install**

Run:

```bash
"C:/Program Files/Git/bin/bash.exe" tests/simulate_install.sh
```

Expected: PASS.

**Step 4: Summarize host follow-up work**

Document the required reconciliation steps for `dedirock`, `akilecloud`, and `Ubuntu.online`.

## Execution Note

The user already approved the design and requested execution in this session, so this implementation plan is being used as the working checklist rather than a handoff artifact only.
