#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script Name: deploy.sh
# Description: Deploys sing-box using Podman Quadlet
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
remote_proxy_runtime_preflight check 3.9 podman systemctl

IS_ROOT=0
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT=1
fi

if [ "$IS_ROOT" -eq 1 ]; then
    SYSTEMD_DIR="/etc/containers/systemd"
    FALLBACK_DIR="/etc/systemd/system"
    SYSTEMCTL_CMD="systemctl"
    WANTED_BY_TARGET="multi-user.target"
    echo "ℹ️  Running as ROOT. Using system-wide Quadlet dir: $SYSTEMD_DIR"
else
    SYSTEMD_DIR="$HOME/.config/containers/systemd"
    FALLBACK_DIR="$HOME/.config/systemd/user"
    SYSTEMCTL_CMD="systemctl --user"
    WANTED_BY_TARGET="default.target"
    echo "ℹ️  Running as USER. Using user-scope Quadlet dir: $SYSTEMD_DIR"
fi

PODMAN_SYSTEM_GENERATOR_BIN=${PODMAN_SYSTEM_GENERATOR_BIN:-/usr/lib/systemd/system-generators/podman-system-generator}

remote_proxy_ensure_singbox_layout
SINGBOX_ENV_FILE="$(remote_proxy_singbox_env_file)"
SINGBOX_RENDERED_CONFIG="$(remote_proxy_singbox_rendered_config_path)"

if [ -f "$SINGBOX_ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1091
    . "$SINGBOX_ENV_FILE"
    set +a
fi

BASE_PORT=${BASE_PORT:-10000}
SING_BOX_IMAGE=${SING_BOX_IMAGE:-ghcr.io/sagernet/sing-box:v1.13.2}
ENABLE_DEPRECATED_SING_BOX_FLAGS=${ENABLE_DEPRECATED_SING_BOX_FLAGS:-true}
SING_BOX_NETWORK_MODE=${SING_BOX_NETWORK_MODE:-host}
SING_BOX_PODMAN_RESOURCE_ARGS="$(remote_proxy_podman_run_resource_args "SING_BOX")"
SING_BOX_QUADLET_RESOURCE_LINES="$(remote_proxy_quadlet_resource_lines "SING_BOX")"
SING_BOX_SYSTEMD_RESOURCE_LINES="$(remote_proxy_systemd_resource_lines "SING_BOX")"

if [ "$SING_BOX_NETWORK_MODE" != "host" ] && [ "$SING_BOX_NETWORK_MODE" != "publish" ]; then
    echo "❌ Unsupported SING_BOX_NETWORK_MODE: $SING_BOX_NETWORK_MODE (expected host or publish)" >&2
    exit 1
fi

echo ">>> Rendering sing-box runtime config: $SINGBOX_RENDERED_CONFIG"
REMOTE_PROXY_SINGBOX_ENV_FILE="$SINGBOX_ENV_FILE" \
REMOTE_PROXY_SINGBOX_RENDERED_CONFIG="$SINGBOX_RENDERED_CONFIG" \
    "$REMOTE_PROXY_PYTHON_BIN" "$SCRIPT_DIR/gen_config.py"

if [ ! -f "$SINGBOX_RENDERED_CONFIG" ]; then
    echo "⚠️ singbox.json not found. Running generator..."
    REMOTE_PROXY_SINGBOX_ENV_FILE="$SINGBOX_ENV_FILE" \
    REMOTE_PROXY_SINGBOX_RENDERED_CONFIG="$SINGBOX_RENDERED_CONFIG" \
        "$REMOTE_PROXY_PYTHON_BIN" "$SCRIPT_DIR/gen_config.py"
fi

QUADLET_ENV_LINES=""
FALLBACK_ENV_LINES=""
if [ "$ENABLE_DEPRECATED_SING_BOX_FLAGS" = "true" ]; then
    QUADLET_ENV_LINES=$(cat <<'EOF'
Environment=ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true
Environment=ENABLE_DEPRECATED_MISSING_DOMAIN_RESOLVER=true
Environment=ENABLE_DEPRECATED_LEGACY_DOMAIN_STRATEGY_OPTIONS=true
EOF
)
    FALLBACK_ENV_LINES=$(cat <<'EOF'
  -e ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true \
  -e ENABLE_DEPRECATED_MISSING_DOMAIN_RESOLVER=true \
  -e ENABLE_DEPRECATED_LEGACY_DOMAIN_STRATEGY_OPTIONS=true \
EOF
)
fi

quadlet_fragment_path() {
    local fragment_path=""

    # shellcheck disable=SC2086
    fragment_path=$($SYSTEMCTL_CMD show --property=FragmentPath --value remote-proxy.service 2>/dev/null || true)
    printf '%s' "$fragment_path" | tr -d '\r'
}

quadlet_service_generated() {
    local fragment_path
    fragment_path="$(quadlet_fragment_path)"

    case "$fragment_path" in
        /run/systemd/generator/*|/run/systemd/generator.late/*|/run/user/*/systemd/generator/*|/run/user/*/systemd/generator.late/*)
            return 0
            ;;
    esac

    return 1
}

wait_for_quadlet_generation() {
    local max_checks=$1
    local i=0

    while [ "$i" -lt "$max_checks" ]; do
        if quadlet_service_generated; then
            echo "✅ Service detected (Quadlet): $(quadlet_fragment_path)"
            return 0
        fi
        i=$((i + 1))
        echo "   Waiting for generator... ($i/$max_checks)"
        sleep 1
    done

    return 1
}

print_quadlet_debug() {
    echo "1. Quadlet File Content:"
    cat "$SYSTEMD_DIR/remote-proxy.container"
    echo "2. Quadlet FragmentPath:"
    echo "$(quadlet_fragment_path)"
    echo "3. Generator Output (dryrun if available):"
    if [ -x "$PODMAN_SYSTEM_GENERATOR_BIN" ]; then
        QUADLET_UNIT_DIRS="$SYSTEMD_DIR" "$PODMAN_SYSTEM_GENERATOR_BIN" --dryrun 2>&1 || true
    else
        echo "podman-system-generator not found"
    fi
    echo "4. Recent generator logs:"
    journalctl -b --no-pager -n 50 2>&1 | grep -E 'quadlet-generator|podman-system-generator' || true
}

quadlet_dryrun_generates_service() {
    if [ ! -x "$PODMAN_SYSTEM_GENERATOR_BIN" ]; then
        return 1
    fi

    QUADLET_UNIT_DIRS="$SYSTEMD_DIR" "$PODMAN_SYSTEM_GENERATOR_BIN" --dryrun 2>&1 | grep -q -- '---remote-proxy.service---'
}

write_fallback_service() {
    if [ "$IS_ROOT" -eq 0 ]; then
        FALLBACK_DIR="$HOME/.config/systemd/user"
        mkdir -p "$FALLBACK_DIR"
    fi

    if [ "$SING_BOX_NETWORK_MODE" = "host" ]; then
        cat > "$FALLBACK_DIR/remote-proxy.service" <<EOF
[Unit]
Description=Remote Proxy Service (Fallback)
After=network-online.target

[Service]
Restart=always
${SING_BOX_SYSTEMD_RESOURCE_LINES}
ExecStart=$(command -v podman) run --name remote-proxy --replace --rm \\
${FALLBACK_ENV_LINES}
  -v ${SINGBOX_RENDERED_CONFIG}:/etc/sing-box/config.json:Z \\
  --network host ${SING_BOX_PODMAN_RESOURCE_ARGS}\\
  ${SING_BOX_IMAGE} run -c /etc/sing-box/config.json
ExecStop=$(command -v podman) stop remote-proxy

[Install]
WantedBy=${WANTED_BY_TARGET}
EOF
    else
        cat > "$FALLBACK_DIR/remote-proxy.service" <<EOF
[Unit]
Description=Remote Proxy Service (Fallback)
After=network-online.target

[Service]
Restart=always
${SING_BOX_SYSTEMD_RESOURCE_LINES}
ExecStart=$(command -v podman) run --name remote-proxy --replace --rm \\
${FALLBACK_ENV_LINES}
  -v ${SINGBOX_RENDERED_CONFIG}:/etc/sing-box/config.json:Z \\
  -p ${BASE_PORT}:${BASE_PORT} \\
  -p $((${BASE_PORT}+1)):$((${BASE_PORT}+1)) \\
  -p $((${BASE_PORT}+2)):$((${BASE_PORT}+2)) \\
  -p $((${BASE_PORT}+3)):$((${BASE_PORT}+3)) \\
  -p $((${BASE_PORT}+4)):$((${BASE_PORT}+4)) ${SING_BOX_PODMAN_RESOURCE_ARGS}\\
  ${SING_BOX_IMAGE} run -c /etc/sing-box/config.json
ExecStop=$(command -v podman) stop remote-proxy

[Install]
WantedBy=${WANTED_BY_TARGET}
EOF
    fi
}

cleanup_stale_hostport_dnat_rules() {
    local ports_csv ports_regex rule delete_cmd

    if [ "$SING_BOX_NETWORK_MODE" != "host" ]; then
        return 0
    fi

    if ! command -v iptables-save >/dev/null 2>&1 || ! command -v iptables >/dev/null 2>&1; then
        return 0
    fi

    ports_csv="${BASE_PORT},$((${BASE_PORT}+1)),$((${BASE_PORT}+2)),$((${BASE_PORT}+3)),$((${BASE_PORT}+4))"
    ports_regex="${BASE_PORT}|$((${BASE_PORT}+1))|$((${BASE_PORT}+2))|$((${BASE_PORT}+3))|$((${BASE_PORT}+4))"

    while IFS= read -r rule; do
        [ -n "$rule" ] || continue
        delete_cmd="$(printf '%s\n' "$rule" | sed 's/^-A /iptables -t nat -D /')"
        if sh -c "$delete_cmd" >/dev/null 2>&1; then
            echo ">>> Removed stale hostport NAT rule: ${rule#-A }"
        fi
    done <<EOF
$(iptables-save -t nat 2>/dev/null \
    | grep -E '^-A CNI-(HOSTPORT-DNAT|DN-[^ ]+) ' \
    | grep -E -- "--dports ${ports_csv}([[:space:]]|$)|--dport (${ports_regex})([[:space:]]|$)" \
    || true)
EOF
}

mkdir -p "$SYSTEMD_DIR"
rm -f "$SYSTEMD_DIR/remote-proxy.container"

echo ">>> Generating Quadlet file at $SYSTEMD_DIR/remote-proxy.container"
cat > "$SYSTEMD_DIR/remote-proxy.container" <<EOF
[Unit]
Description=Remote Proxy Service (Sing-box)
After=network-online.target

[Container]
Image=${SING_BOX_IMAGE}
ContainerName=remote-proxy
Volume=${SINGBOX_RENDERED_CONFIG}:/etc/sing-box/config.json:Z
${QUADLET_ENV_LINES}
${SING_BOX_QUADLET_RESOURCE_LINES}
EOF

if [ "$SING_BOX_NETWORK_MODE" = "host" ]; then
    cat >> "$SYSTEMD_DIR/remote-proxy.container" <<EOF
Network=host
EOF
else
    cat >> "$SYSTEMD_DIR/remote-proxy.container" <<EOF
PublishPort=${BASE_PORT}:${BASE_PORT}
PublishPort=$((${BASE_PORT}+1)):$((${BASE_PORT}+1))
PublishPort=$((${BASE_PORT}+2)):$((${BASE_PORT}+2))
PublishPort=$((${BASE_PORT}+3)):$((${BASE_PORT}+3))
PublishPort=$((${BASE_PORT}+4)):$((${BASE_PORT}+4))
EOF
fi

cat >> "$SYSTEMD_DIR/remote-proxy.container" <<EOF
Exec=run -c /etc/sing-box/config.json

[Service]
Restart=always
TimeoutStartSec=900
${SING_BOX_SYSTEMD_RESOURCE_LINES}

[Install]
WantedBy=${WANTED_BY_TARGET}
EOF

echo ">>> Reloading Systemd..."
$SYSTEMCTL_CMD daemon-reload

if [ -f "$FALLBACK_DIR/remote-proxy.service" ] && quadlet_dryrun_generates_service; then
    echo ">>> Quadlet dry-run succeeded. Removing stale fallback unit at $FALLBACK_DIR/remote-proxy.service"
    rm -f "$FALLBACK_DIR/remote-proxy.service"
    echo ">>> Reloading Systemd after stale fallback cleanup..."
    $SYSTEMCTL_CMD daemon-reload
fi

echo ">>> Verifying Service Generation..."
MAX_CHECKS=5
DEPLOY_MODE="quadlet"
if ! wait_for_quadlet_generation "$MAX_CHECKS"; then
    echo "⚠️  Quadlet generation failed. Falling back to standard Systemd Unit."
    DEPLOY_MODE="fallback"
fi

if [ "$DEPLOY_MODE" = "fallback" ]; then
    write_fallback_service
    echo ">>> Reloading Systemd (Fallback)..."
    $SYSTEMCTL_CMD daemon-reload
fi

cleanup_stale_hostport_dnat_rules

echo ">>> Enabling Service..."
if ! $SYSTEMCTL_CMD enable remote-proxy; then
    if [ "$DEPLOY_MODE" = "quadlet" ]; then
        echo "⚠️  Quadlet enable failed. Falling back to standard Systemd Unit."
        rm -f "$SYSTEMD_DIR/remote-proxy.container"
        write_fallback_service
        echo ">>> Reloading Systemd (Fallback after enable failure)..."
        $SYSTEMCTL_CMD daemon-reload
        if ! $SYSTEMCTL_CMD enable remote-proxy; then
            echo "❌ Failed to enable fallback service. Debugging info:"
            print_quadlet_debug
            exit 1
        fi
        DEPLOY_MODE="fallback"
    else
        echo "❌ Failed to enable service. Debugging info:"
        print_quadlet_debug
        exit 1
    fi
fi

echo ">>> Applying Service Restart..."
if ! $SYSTEMCTL_CMD restart remote-proxy; then
    if ! $SYSTEMCTL_CMD start remote-proxy; then
        echo "❌ Failed to restart/start service. Debugging info:"
        print_quadlet_debug
        exit 1
    fi
fi

sleep 2
$SYSTEMCTL_CMD status remote-proxy --no-pager

echo "✅ Deployment initiated. Check logs with: journalctl -u remote-proxy -f"
if [ "$IS_ROOT" -eq 0 ]; then
    echo "   (User mode logs: journalctl --user -u remote-proxy -f)"
fi
