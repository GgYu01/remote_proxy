# Remote Proxy Reliability Design

## Context

`remote_proxy` currently sits in an uncomfortable middle state:

- The repository can produce a running sing-box deployment on some VPS hosts.
- The operational reality has drifted from the repository and its docs.
- The user also has a separate `infra-core` deployment topology on `Ubuntu.online`.

That means the repository is not yet a trustworthy baseline for repeatable multi-host rollout, onboarding, or incident response.

## Problem Statement

We need one repository that can act as the durable source of truth for:

- standalone VPS deployments used as personal remote proxies;
- integration guidance for `infra-core`-style sidecar deployments;
- client usage across Android / Windows / Linux;
- predictable secret handling, upgrades, rollback, and verification.

## Goals

1. Make the repository the authoritative, reviewable deployment baseline.
2. Separate the two supported topologies clearly:
   - `standalone-vps`: Podman + systemd/Quadlet or fallback service.
   - `infra-core-sidecar`: Docker Compose / sidecar style integration guide.
3. Make secret handling explicit, safe, and non-accidental.
4. Make deployment behavior idempotent enough for repeated use on similar VPS hosts.
5. Make verification layered and repeatable, not just "it starts on one machine".
6. Produce documentation that is detailed enough for future self-serve deployment.

## Non-Goals

- This phase will not add every proxy protocol under the sun.
- This phase will not replace `infra-core` with a brand-new orchestrator.
- This phase will not store real production secrets in Git.

## Supported Topologies

### 1. Standalone VPS

This is the repository's primary executable deployment path.

Characteristics:

- single Linux VPS;
- Podman-based runtime;
- systemd-managed lifecycle;
- ports 10000-10004 exposed for SOCKS5 / HTTP / SS / VLESS Reality / Trojan;
- optimized for repeatable rollout on fresh Debian / Ubuntu hosts.

### 2. Infra-Core Sidecar

This is a documented integration path, not a drop-in reuse of `install.sh`.

Characteristics:

- existing `/mnt/hdo/infra-core` tree;
- Docker Compose driven services;
- sidecar or compose fragment around a sing-box container;
- must document how it plugs into the existing infra rather than pretending the standalone installer owns the host.

## Root Causes Identified

### Docs Drift

The current docs describe filenames, commands, and config conventions that no longer match implementation.

### Config Mutability Drift

`config.env` is updated by appending values, which creates duplicate keys and undefined operator expectations.

### Runtime Drift

Different hosts are running materially different generated units and memory settings.

### Verification Gap

Current verification only proves local SOCKS5/HTTP success and leaks credentials in logs.

### Operational Boundary Drift

The repo currently treats standalone VPS and `infra-core` as if they were the same deployment problem.

## Design Decisions

### Decision 1: Keep One Repo, But Split the Deployment Narrative

The repository remains the single home, but its docs and structure must state:

- what is automated by scripts;
- what is manual integration guidance;
- what is standalone only;
- what is `infra-core` only.

### Decision 2: Secrets Are Referenced, Never Published

The public repo will document:

- secret types;
- generation methods;
- where to place them;
- rotation and migration procedures.

The public repo will not contain:

- real passwords;
- real private keys;
- real share links with live credentials.

### Decision 3: Prefer Pinned Runtime Inputs

The deployment path should not silently depend on `latest` behavior where that materially affects reliability.

That includes:

- sing-box image reference;
- compatibility env flags when required;
- explicit memory defaults and lower bounds.

### Decision 4: Verification Is Layered

We will use five validation layers:

- `L0`: static checks for syntax, docs consistency, and generated artifacts.
- `L1`: focused unit/integration tests for config and script behavior.
- `L2`: mocked install/deploy path checks on local development machines.
- `L3`: host acceptance on the three known environments.
- `L4`: fresh-host rollout validation on a new VPS.

## Documentation Architecture

The documentation set will be reorganized into:

- top-level `README.md`: product overview, topology split, fast-start, safety rules.
- `docs/deploy/standalone-vps.md`: authoritative standalone deployment guide.
- `docs/deploy/infra-core-ubuntu-online.md`: `infra-core` integration guide.
- `docs/clients/android.md`
- `docs/clients/windows.md`
- `docs/clients/linux.md`
- `docs/security/secrets-and-rotation.md`
- `docs/ops/troubleshooting.md`
- `docs/ops/host-baselines.md`

## Implementation Scope For This Execution Batch

Batch 1 will focus on:

1. documentation baseline rebuild;
2. config/secret handling hardening;
3. deploy and verify hardening;
4. tests for the new behavior;
5. host-specific operational guidance derived from the current three known environments.

## Acceptance Criteria

The batch is acceptable only if all of the following are true:

- docs no longer claim unsupported or outdated behavior;
- generated config updates are idempotent for managed keys;
- verification output does not print raw credentials;
- deploy path documents or supports compatibility env flags explicitly;
- standalone vs `infra-core` guidance is clearly separated;
- tests cover the new high-risk behavior and are run fresh.

## Risks

- shell behavior differences between Windows host dev environments and Linux deployment targets;
- sing-box release drift;
- user-specific `infra-core` local conventions not fully represented in the public repo;
- partial rollout where one host remains on an old generated unit.

## Rollout Order

1. Fix repository baseline.
2. Update docs and tests.
3. Reconcile `dedirock` and `akilecloud` against the new baseline.
4. Document `Ubuntu.online` sidecar deployment under `infra-core`.
5. Use the new README for future VPS onboarding.
