# Troubleshooting

## First Checks

```bash
systemctl status remote-proxy
systemctl cat remote-proxy
journalctl -u remote-proxy -n 100 --no-pager
ss -tulpn | grep -E '1000[0-4]'
```

## Known Failure Modes

### Service starts on one host and fails on another

Compare:

- pinned image tag;
- generated unit content;
- memory limit;
- compatibility env flags;
- rendered `singbox.json`.

### Ports are not listening

- verify the service is active;
- verify the container actually started;
- inspect journal output for sing-box startup errors.

### HTTP / SOCKS checks fail

- run `./scripts/verify.sh`;
- confirm credentials in `config.env`;
- confirm outbound internet access from the VPS.

### sing-box deprecated config errors

If journal output asks for deprecated compatibility flags, confirm the generated unit contains:

- `ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true`
- `ENABLE_DEPRECATED_MISSING_DOMAIN_RESOLVER=true`
- `ENABLE_DEPRECATED_LEGACY_DOMAIN_STRATEGY_OPTIONS=true`

### Public probes on HTTP port

If you see anonymous probes or malformed TLS on the HTTP port:

- rotate credentials;
- reduce exposure where possible;
- prefer client usage through VLESS + Reality for normal operation.
