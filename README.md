# Remote Proxy Deployment Baseline

`remote_proxy` is the maintained baseline for running a personal remote proxy on Linux VPS hosts and for documenting how the same capability plugs into an existing `infra-core` environment.

## What This Repository Supports

This repository supports two distinct deployment topologies:

1. `standalone-vps`
   Use this when you have a fresh Debian / Ubuntu VPS and want this repository to own the proxy deployment.

2. `infra-core-sidecar`
   Use this when the proxy runs inside an existing `/mnt/hdo/infra-core` Docker Compose environment such as `Ubuntu.online`.

Do not treat those two modes as interchangeable. The scripts in this repo automate the standalone VPS path. The `infra-core` path is documented as an integration guide.

## Safety Rules

- `config.env` is the active config file. The repo does not use `.env` as the primary standalone config file.
- The values in `config.env.example` are placeholders. Change credentials before exposing ports publicly.
- Do not commit real passwords, private keys, or live share links to Git.
- Pin the sing-box image unless you are intentionally testing an upgrade.

## Quick Start

### Standalone VPS

```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
cp config.env.example config.env
nano config.env
chmod +x install.sh scripts/*.sh
./install.sh
./scripts/verify.sh
./scripts/show_info.sh
```

Authoritative guide:

- [Standalone VPS deployment](docs/deploy/standalone-vps.md)

### Existing `infra-core` Host

For `Ubuntu.online` and similar hosts, do not run `install.sh` blindly inside `/mnt/hdo/infra-core`. Follow the sidecar guide instead:

- [Infra-core / Ubuntu.online integration](docs/deploy/infra-core-ubuntu-online.md)

## Client Setup

- [Android client guide](docs/clients/android.md)
- [Windows client guide](docs/clients/windows.md)
- [Linux client guide](docs/clients/linux.md)

## Secrets, Rotation, and Recovery

- [Secrets and rotation guide](docs/security/secrets-and-rotation.md)

## Operations

- [Troubleshooting guide](docs/ops/troubleshooting.md)
- [Known host baselines](docs/ops/host-baselines.md)

## Script Overview

- `install.sh`: standalone VPS entrypoint.
- `scripts/setup_env.sh`: package install + swap preparation.
- `scripts/gen_keys.sh`: idempotent managed key generation for `config.env`.
- `scripts/gen_config.py`: renders `singbox.json` from `config.env`.
- `scripts/deploy.sh`: generates Quadlet and fallback systemd service definitions.
- `scripts/verify.sh`: validates listeners and local proxy connectivity without printing raw credentials.
- `scripts/show_info.sh`: prints client connection info from current config.

## Current Runtime Model

The default generated config exposes these inbounds on `BASE_PORT` through `BASE_PORT + 4`:

- SOCKS5
- HTTP
- Shadowsocks
- VLESS + Reality
- Trojan

## Documentation Status

The current documentation set is being normalized around:

- one authoritative config filename: `config.env`;
- one automated standalone deployment path;
- one documented `infra-core` integration path;
- explicit client guides for Android / Windows / Linux.

If a legacy document conflicts with these rules, follow the files linked from this README.
