# Android Client Guide

## Recommended Clients

- `sing-box` Android
- `v2rayNG` when you only need VLESS / Trojan / Shadowsocks import support

## Preferred Import Path

For the current repo baseline, VLESS + Reality is the preferred client path.

Use `./scripts/show_info.sh` on the VPS to print the generated share link after deployment.

## Android Checklist

1. Import the VLESS Reality share link.
2. Confirm the server address is the VPS public IP.
3. Confirm the port is `BASE_PORT + 3`.
4. Confirm `pbk`, `sid`, and `sni` are present.
5. Enable route mode as needed for full-device proxying.

## Verification

- Open a browser through the profile.
- Confirm the observed egress IP is the VPS IP.
- Confirm destination sites work without TLS certificate warnings.

## Security Notes

- Rotate the UUID if you believe the link was leaked.
- Rotate Reality keys only when you are ready to update every client.
