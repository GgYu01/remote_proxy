# Dual Service CLIProxyAPIPlus Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Upgrade `remote_proxy` into a dual-service deployment baseline that can install and operate both `sing-box` and `CLIProxyAPIPlus`, with Podman/systemd deployment, version switching, usage backup/restore, and operator-grade documentation.

**Architecture:** Keep one repository and one shared control layer, but split service-specific behavior into `singbox` and `cliproxy_plus` modules. Persist all `CLIProxyAPIPlus` state on the host, and treat usage export/import as a required lifecycle step for update and version-switch operations.

**Tech Stack:** Bash, Python 3, Podman, systemd/Quadlet, Markdown docs, `unittest`, mocked shell integration tests, Debian 12 VPS validation.

---

### Task 1: Capture the approved design in repo docs

**Files:**
- Create: `docs/plans/2026-04-05-dual-service-cliproxy-plus-design.md`
- Create: `docs/plans/2026-04-05-dual-service-cliproxy-plus.md`

**Step 1: Write the documentation artifacts**

Write the approved design and implementation plan into `docs/plans/`.

**Step 2: Verify files exist**

Run: `python -c "from pathlib import Path; import sys; sys.exit(0 if Path('docs/plans/2026-04-05-dual-service-cliproxy-plus-design.md').exists() and Path('docs/plans/2026-04-05-dual-service-cliproxy-plus.md').exists() else 1)"`

Expected: exit code `0`.

### Task 2: Add failing docs tests for the new dual-service behavior

**Files:**
- Modify: `tests/test_docs_consistency.py`

**Step 1: Write the failing test**

Add tests that assert:

- `README.md` mentions `cliproxy-plus` support.
- `README.md` documents Podman/systemd service inspection commands.
- `README.md` documents `CLIProxyAPIPlus` port roles and local call examples.
- `README.md` or deploy docs mention version update / version switch flows.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_docs_consistency -v`

Expected: FAIL because current docs only describe `sing-box`.

**Step 3: Do not change production docs yet**

Keep the failure as the red phase baseline.

### Task 3: Add failing tests for `cliproxy-plus` config generation

**Files:**
- Create: `tests/test_cliproxy_plus_config.py`
- Create: `scripts/services/cliproxy_plus/` (directory only after test is written)

**Step 1: Write the failing test**

Add tests around a new config generator that assert:

- generated YAML uses HTTP (`tls.enable: false`);
- management is local-only by default;
- auth-dir points to the mounted state path;
- usage statistics are enabled by config when requested;
- pprof defaults remain local-only or disabled.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_cliproxy_plus_config -v`

Expected: FAIL because generator/module does not exist yet.

### Task 4: Add failing tests for `cliproxy-plus` deploy rendering

**Files:**
- Create: `tests/test_cliproxy_plus_deploy.py`

**Step 1: Write the failing test**

Add mocked integration tests that assert generated service definitions:

- use a pinned image tag from env;
- mount host `config.yaml`, `auths`, `logs`, and `usage` state paths;
- apply configured memory limits;
- use the correct service name `cliproxy-plus`;
- expose only approved ports by default.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_cliproxy_plus_deploy -v`

Expected: FAIL because no cliproxy deployment scripts exist yet.

### Task 5: Add failing tests for usage backup and restore

**Files:**
- Create: `tests/test_cliproxy_plus_usage_lifecycle.py`

**Step 1: Write the failing test**

Add tests for a lifecycle helper that:

- exports usage to `state/cliproxy-plus/usage/latest.json` before update;
- imports usage after successful restart;
- blocks upgrade when export fails, unless explicitly forced;
- uses `Authorization: Bearer <management-key>` against localhost management endpoints.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_cliproxy_plus_usage_lifecycle -v`

Expected: FAIL because lifecycle helpers do not exist yet.

### Task 6: Add failing tests for version switch workflow

**Files:**
- Create: `tests/test_service_entrypoint.py`

**Step 1: Write the failing test**

Add tests for a new top-level service control entrypoint that assert:

- `service.sh cliproxy-plus install` dispatches the correct scripts;
- `service.sh cliproxy-plus verify` dispatches verification;
- `service.sh cliproxy-plus update` performs export -> pull -> deploy -> import -> verify;
- `service.sh cliproxy-plus switch-version <tag>` persists the new tag and runs the same guarded lifecycle.

**Step 2: Run test to verify it fails**

Run: `python -m unittest tests.test_service_entrypoint -v`

Expected: FAIL because unified service entrypoint does not exist yet.

### Task 7: Implement minimal shared control layer

**Files:**
- Create: `scripts/lib/common.sh`
- Create: `scripts/lib/systemd.sh`
- Create: `scripts/lib/podman.sh`
- Create: `scripts/service.sh`
- Modify: `install.sh`

**Step 1: Write the minimal implementation**

Implement a shared control layer that:

- resolves repository root and state/config paths;
- loads service-specific env files;
- exposes a single `service.sh` dispatcher;
- keeps existing `sing-box` install path working.

**Step 2: Run focused tests**

Run: `python -m unittest tests.test_service_entrypoint -v`

Expected: PASS for the dispatch behavior added so far.

### Task 8: Implement `cliproxy-plus` config generation

**Files:**
- Create: `config/cliproxy-plus.env.example`
- Create: `scripts/services/cliproxy_plus/gen_config.py`

**Step 1: Write the minimal implementation**

Generate `state/cliproxy-plus/config.yaml` from env with:

- HTTP mode only;
- local-only management by default;
- configured management key;
- explicit auth/logging/usage settings;
- operator-facing comments where useful.

**Step 2: Run focused tests**

Run: `python -m unittest tests.test_cliproxy_plus_config -v`

Expected: PASS.

### Task 9: Implement `cliproxy-plus` deployment

**Files:**
- Create: `scripts/services/cliproxy_plus/deploy.sh`
- Create: `scripts/services/cliproxy_plus/install.sh`

**Step 1: Write the minimal implementation**

Implement Podman Quadlet generation with fallback systemd unit for `cliproxy-plus`.

**Step 2: Run focused tests**

Run: `python -m unittest tests.test_cliproxy_plus_deploy -v`

Expected: PASS.

### Task 10: Implement usage export/import lifecycle helpers

**Files:**
- Create: `scripts/services/cliproxy_plus/usage_backup.sh`
- Create: `scripts/services/cliproxy_plus/usage_restore.sh`

**Step 1: Write the minimal implementation**

Implement local management API calls to export/import usage with safe failure handling.

**Step 2: Run focused tests**

Run: `python -m unittest tests.test_cliproxy_plus_usage_lifecycle -v`

Expected: PASS.

### Task 11: Implement `cliproxy-plus` verify and version-switch flows

**Files:**
- Create: `scripts/services/cliproxy_plus/verify.sh`
- Create: `scripts/services/cliproxy_plus/switch_version.sh`
- Modify: `scripts/service.sh`

**Step 1: Write the minimal implementation**

Implement:

- health verification against localhost;
- management API verification;
- version detection;
- export/pull/redeploy/import/verify workflow.

**Step 2: Run focused tests**

Run: `python -m unittest tests.test_service_entrypoint tests.test_cliproxy_plus_usage_lifecycle -v`

Expected: PASS.

### Task 12: Reconcile `sing-box` entrypoints with the shared control layer

**Files:**
- Modify: `install.sh`
- Modify: `scripts/deploy.sh`
- Modify: `scripts/verify.sh`
- Modify: `README.md`

**Step 1: Write the minimal implementation**

Preserve current `sing-box` workflows while routing them through the new shared control conventions where appropriate.

**Step 2: Run regression tests**

Run: `python -m unittest tests.test_deploy_script tests.test_verify_script tests.test_gen_keys -v`

Expected: PASS.

### Task 13: Update README and deploy docs to satisfy operator requirements

**Files:**
- Modify: `README.md`
- Modify: `docs/deploy/standalone-vps.md`
- Create: `docs/deploy/cliproxy-plus-standalone-vps.md`

**Step 1: Write the minimal documentation**

Document:

- supported services;
- Podman/systemd inspection commands;
- `CLIProxyAPIPlus` default ports and their roles;
- local invocation examples;
- install / verify / update / switch-version commands.

**Step 2: Run docs tests**

Run: `python -m unittest tests.test_docs_consistency -v`

Expected: PASS.

### Task 14: Run local verification suite

**Files:**
- No new files; verification only

**Step 1: Run targeted unit and integration tests**

Run: `python -m unittest tests.test_docs_consistency tests.test_gen_keys tests.test_verify_script tests.test_deploy_script tests.test_cliproxy_plus_config tests.test_cliproxy_plus_deploy tests.test_cliproxy_plus_usage_lifecycle tests.test_service_entrypoint -v`

Expected: PASS.

**Step 2: Run repository audit**

Run: `python scripts/audit_project.py`

Expected: PASS.

**Step 3: Run simulated install**

Run: `"C:/Program Files/Git/bin/bash.exe" tests/simulate_install.sh`

Expected: PASS or explicit follow-up gap isolated to simulation coverage that will be fixed before remote deploy.

### Task 15: Deploy and verify on `vmrack`

**Files:**
- Modify as needed based on deployment gaps discovered

**Step 1: Prepare the host**

Install Podman and required tools on `38.65.93.94`.

**Step 2: Upload repo and configuration**

Provision the repository under `/root/remote_proxy`.

**Step 3: Install `cliproxy-plus`**

Run the repository’s install path.

**Step 4: Verify service**

Run service verification and direct localhost API checks.

**Step 5: Prove update / switch-version workflow**

Perform at least one real version switch and verify:

- service returns healthy responses;
- auth state persists;
- usage export/import path executes successfully.

### Task 16: Final repo and host review

**Files:**
- Modify only if issues are found

**Step 1: Review diff and docs**

Confirm there is no hidden regression in `sing-box` behavior, no stale README statements, and no unsafe secrets in tracked files.

**Step 2: Re-run the final verification commands**

Run the full local verification suite again and rerun remote verify commands.

Expected: PASS with fresh evidence.

## Execution Note

Plan complete and saved to `docs/plans/2026-04-05-dual-service-cliproxy-plus.md`.
The user already chose to continue in this session, so execution proceeds here with TDD and fresh verification evidence at each completion point.
