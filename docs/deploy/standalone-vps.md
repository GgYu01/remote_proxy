# Standalone VPS Deployment

## Scope

Use this guide when:

- the target is a fresh or mostly fresh Debian / Ubuntu VPS;
- you want `remote_proxy` to own the proxy runtime;
- Podman + systemd is acceptable on the host.

## Preflight

1. Confirm the host is Debian 12/13 or Ubuntu 22.04/24.04.
2. Confirm you have root access or a sudo-capable operator account.
3. Decide whether you want the default ports `10000-10004`.
4. Decide whether you need a new UUID / Reality keypair or are migrating an existing one.

## Files and Secrets

- Copy `config.env.example` to `config.env`.
- Fill or review:
  - `PROXY_USER`
  - `PROXY_PASS`
  - `SS_PASSWORD`
  - `BASE_PORT`
  - `SING_BOX_IMAGE`
  - `ENABLE_DEPRECATED_SING_BOX_FLAGS`
  - `MEMORY_LIMIT`
- Leave these empty only when you want the managed generator to fill them:
  - `VLESS_UUID`
  - `REALITY_PRIVATE_KEY`
  - `REALITY_PUBLIC_KEY`
  - `REALITY_SHORT_ID`

## Install Flow

```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
cp config.env.example config.env
nano config.env
chmod +x install.sh scripts/*.sh
./install.sh
```

`install.sh` performs:

1. package installation and swap prep;
2. managed key generation;
3. `singbox.json` generation;
4. Quadlet generation with fallback systemd service generation;
5. local verification and client info output.

## Verification

Run:

```bash
./scripts/verify.sh
```

Expected signals:

- ports `BASE_PORT` through `BASE_PORT + 4` are listening;
- SOCKS5 and HTTP local verification succeed;
- service status is active;
- no raw credentials are printed in verification output.

## Service Inspection

Root deployment:

```bash
systemctl status remote-proxy
journalctl -u remote-proxy -f
systemctl cat remote-proxy
```

Rootless deployment:

```bash
systemctl --user status remote-proxy
journalctl --user -u remote-proxy -f
systemctl --user cat remote-proxy
```

## Upgrade Rules

1. Back up `config.env` and the rendered service/unit definition.
2. Upgrade the repo.
3. Review `SING_BOX_IMAGE` intentionally. Do not drift to `latest` by accident.
4. Re-run:

```bash
python3 scripts/gen_config.py
./scripts/deploy.sh
./scripts/verify.sh
```

## Rollback Rules

If an upgrade breaks runtime:

1. restore prior `config.env`;
2. restore prior pinned image tag;
3. re-run deploy;
4. re-run verify;
5. confirm service/unit content matches the working baseline.

## Firewall and Exposure

- Restrict inbound exposure where possible.
- If HTTP or SOCKS ports are public, assume they will be probed.
- Never leave placeholder credentials on a public host.
- Rotate credentials if logs show unexpected probes.
