# Infra-Core / Ubuntu.online Integration

## Scope

Use this guide when the host already runs the `/mnt/hdo/infra-core` Docker Compose estate.

This is a documented integration path, not a direct `install.sh` target.

## Observed Layout

On the current `Ubuntu.online` host, the proxy-related estate includes:

- `/mnt/hdo/infra-core/services/proxied/vless-sidecar/docker-compose.yml`
- `/mnt/hdo/infra-core/services/proxied/vless-sidecar/README.md`
- `/mnt/hdo/infra-core/docs/PROXY_GUIDE.md`
- a running container named `infra_vless_sidecar`

That means the host already has a compose-oriented proxy topology.

## Recommended Integration Strategy

1. Keep `remote_proxy` as the source of proxy design, secret rules, and client guidance.
2. Keep `infra-core` as the owner of Compose wiring, shared networks, and sidecar lifecycle.
3. Port only the relevant sing-box config model and documentation into the sidecar deployment path.
4. Do not overwrite `infra-core` service definitions with the standalone Podman installer.

## Integration Checklist

1. Inspect `services/proxied/vless-sidecar/docker-compose.yml`.
2. Inspect `services/proxied/vless-sidecar/README.md`.
3. Compare its image tag, mounted config, and exposed ports with this repo's standalone baseline.
4. Align secret names and client-facing connection outputs.
5. Update `infra-core` docs only after the standalone baseline is stable.

## Expected Deliverables For Infra-Core

- a compose-side example aligned to the standalone sing-box config;
- secret mapping guidance;
- restart / verification commands specific to Docker Compose;
- client import instructions matching Android / Windows / Linux docs from this repo.

## Do Not

- do not run `./install.sh` inside `/mnt/hdo/infra-core`;
- do not assume Podman Quadlet behavior inside the Compose estate;
- do not mix public README secrets with infra-core runtime secrets.
