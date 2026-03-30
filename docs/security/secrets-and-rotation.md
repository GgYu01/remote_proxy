# Secrets and Rotation

## Secret Types

The standalone baseline uses these mutable secrets:

- `PROXY_PASS`
- `SS_PASSWORD`
- `VLESS_UUID`
- `REALITY_PRIVATE_KEY`
- `REALITY_PUBLIC_KEY`
- `REALITY_SHORT_ID`

## Public Repo Rules

- Public docs may describe these fields.
- Public docs may show placeholder values.
- Public docs must not contain live values from real hosts.

## Rotation Rules

### Low-disruption rotation

Rotate first:

- `PROXY_PASS`
- `SS_PASSWORD`

These affect HTTP / SOCKS / Shadowsocks / Trojan auth paths.

### Medium-disruption rotation

Rotate:

- `VLESS_UUID`

Clients using VLESS must be updated.

### High-disruption rotation

Rotate:

- Reality keypair

Every Reality client must be updated after this change.

## Rotation Procedure

1. edit `config.env`;
2. regenerate `singbox.json`;
3. redeploy the service;
4. re-run verification;
5. update client profiles;
6. revoke and remove stale exported share links.
