#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../../lib/common.sh"

remote_proxy_load_env_file "$(remote_proxy_cliproxy_env_file)"
remote_proxy_configure_systemd_scope

STATE_ROOT="$(remote_proxy_cliproxy_service_root)"
CONFIG_PATH="$STATE_ROOT/config.yaml"
AUTHS_PATH="$STATE_ROOT/auths"
LOGS_PATH="$STATE_ROOT/logs"
USAGE_PATH="$STATE_ROOT/usage"

mkdir -p "$STATE_ROOT" "$AUTHS_PATH" "$LOGS_PATH" "$USAGE_PATH" "$REMOTE_PROXY_SYSTEMD_DIR"

if [ ! -f "$CONFIG_PATH" ]; then
    python3 "$SCRIPT_DIR/gen_config.py"
fi

CLIPROXY_IMAGE="${CLIPROXY_IMAGE:-docker.io/eceasy/cli-proxy-api-plus:latest}"
CLIPROXY_PORT="${CLIPROXY_PORT:-8317}"
CLIPROXY_MEMORY_LIMIT="$(remote_proxy_normalize_memory_limit "${CLIPROXY_MEMORY_LIMIT:-128M}" "128M" "128")"
CLIPROXY_NETWORK_MODE="${CLIPROXY_NETWORK_MODE:-host}"

podman pull "$CLIPROXY_IMAGE" >/dev/null

QUADLET_FILE="$REMOTE_PROXY_SYSTEMD_DIR/cliproxy-plus.container"
rm -f "$QUADLET_FILE"

cat > "$QUADLET_FILE" <<EOF
[Unit]
Description=CLIProxyAPIPlus Service
After=network-online.target

[Container]
Image=${CLIPROXY_IMAGE}
ContainerName=cliproxy-plus
Volume=${CONFIG_PATH}:/CLIProxyAPI/config.yaml:Z
Volume=${AUTHS_PATH}:/root/.cli-proxy-api:Z
Volume=${LOGS_PATH}:/CLIProxyAPI/logs:Z
Volume=${USAGE_PATH}:/CLIProxyAPI/usage:Z
Memory=${CLIPROXY_MEMORY_LIMIT}
EOF

if [ "$CLIPROXY_NETWORK_MODE" = "host" ]; then
    cat >> "$QUADLET_FILE" <<EOF
Network=host
EOF
else
    cat >> "$QUADLET_FILE" <<EOF
PublishPort=${CLIPROXY_PORT}:${CLIPROXY_PORT}
EOF
fi

cat >> "$QUADLET_FILE" <<EOF

[Service]
Restart=always
TimeoutStartSec=900
EOF

remote_proxy_systemctl daemon-reload

GENERATED=0
for _ in 1 2 3 4 5; do
    if remote_proxy_systemctl list-unit-files cliproxy-plus.service | grep -q "cliproxy-plus.service"; then
        GENERATED=1
        break
    fi
    sleep 1
done

if [ "$GENERATED" -eq 0 ]; then
    if [ "$REMOTE_PROXY_IS_ROOT" -eq 1 ]; then
        FALLBACK_DIR="/etc/systemd/system"
    else
        FALLBACK_DIR="$HOME/.config/systemd/user"
        mkdir -p "$FALLBACK_DIR"
    fi

    NETWORK_ARGS=""
    if [ "$CLIPROXY_NETWORK_MODE" = "host" ]; then
        NETWORK_ARGS="--network host"
    else
        NETWORK_ARGS="-p ${CLIPROXY_PORT}:${CLIPROXY_PORT}"
    fi

    cat > "$FALLBACK_DIR/cliproxy-plus.service" <<EOF
[Unit]
Description=CLIProxyAPIPlus Service (Fallback)
After=network-online.target

[Service]
Restart=always
ExecStart=$(command -v podman) run --name cliproxy-plus --replace --rm \\
  -v ${CONFIG_PATH}:/CLIProxyAPI/config.yaml:Z \\
  -v ${AUTHS_PATH}:/root/.cli-proxy-api:Z \\
  -v ${LOGS_PATH}:/CLIProxyAPI/logs:Z \\
  -v ${USAGE_PATH}:/CLIProxyAPI/usage:Z \\
  ${NETWORK_ARGS} \\
  --memory ${CLIPROXY_MEMORY_LIMIT} \\
  ${CLIPROXY_IMAGE}
ExecStop=$(command -v podman) stop cliproxy-plus

[Install]
WantedBy=${REMOTE_PROXY_WANTED_BY_TARGET}
EOF

    remote_proxy_systemctl daemon-reload
fi

remote_proxy_systemctl enable cliproxy-plus
if ! remote_proxy_systemctl restart cliproxy-plus; then
    remote_proxy_systemctl start cliproxy-plus
fi
remote_proxy_systemctl status cliproxy-plus --no-pager
