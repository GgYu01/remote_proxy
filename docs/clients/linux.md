# Linux Client Guide

## Common Client Paths

- `sing-box` CLI or service
- application-level SOCKS5 / HTTP proxy settings
- desktop network proxy settings for browser-first use

## Recommended Path

Prefer VLESS + Reality when the client stack supports it.

For debugging or lightweight CLI use, SOCKS5 and HTTP remain available.

## Linux CLI Examples

Browser or shell tooling via SOCKS5:

```bash
export ALL_PROXY="socks5://USER:PASS@SERVER_IP:BASE_PORT"
curl https://icanhazip.com
```

Browser or shell tooling via HTTP:

```bash
export HTTP_PROXY="http://USER:PASS@SERVER_IP:BASE_PORT_PLUS_1"
export HTTPS_PROXY="$HTTP_PROXY"
curl https://icanhazip.com
```

Replace placeholders with your actual server values. Do not commit live credentials into shell profiles.
