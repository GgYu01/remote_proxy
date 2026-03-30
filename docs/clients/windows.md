# Windows Client Guide

## Recommended Clients

- `sing-box for Windows`
- `Clash Meta` compatible clients only if you intentionally maintain a converted config

## Preferred Path

Use the generated VLESS + Reality link when possible.

## Windows Checklist

1. Import the VLESS link from `./scripts/show_info.sh`.
2. Confirm the server points to the VPS public IP.
3. Confirm `sni`, `pbk`, and `sid` match the rendered config.
4. Decide whether you want browser-only usage or system-wide tunnel mode.

## Fallback Paths

- SOCKS5: `BASE_PORT`
- HTTP: `BASE_PORT + 1`

Use those only for debugging or clients that do not support Reality.

## Verification

- Check browser egress IP.
- Check one CLI tool through the proxy if you need developer tooling coverage.
