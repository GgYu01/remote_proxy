# Known Host Baselines

## Snapshot Date

2026-03-30

## dedirock

- OS: Debian 13
- Service: `remote-proxy.service` active
- Runtime: fallback systemd service running Podman
- Effective memory: `256M`
- Deprecated compatibility flags: present
- Verification: SOCKS5 + HTTP local verification succeeded
- Status: best current reference host

## akilecloud

- OS: Debian 13
- Service: `remote-proxy.service` active
- Runtime: fallback systemd service running Podman
- Effective memory: `8M` in generated unit observed on host
- Deprecated compatibility flags: absent in observed unit
- Git state: detached / drifted from current repo baseline
- Verification: local verification succeeds, but the host should not be treated as the golden baseline
- Status: high-priority reconciliation target

## Ubuntu.online

- OS: Ubuntu 24.04
- Deployment model: existing `/mnt/hdo/infra-core` compose estate
- Observed proxy container: `infra_vless_sidecar`
- Status: integrate through `infra-core` docs, not the standalone Podman installer
