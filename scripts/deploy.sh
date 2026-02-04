#!/bin/bash
set -e

# ==============================================================================
# Script Name: deploy.sh
# Description: Deploys the service using Podman Quadlet
# ==============================================================================

IS_ROOT=0
if [ "$(id -u)" -eq 0 ]; then
    IS_ROOT=1
fi

# Define paths and commands based on user
if [ "$IS_ROOT" -eq 1 ]; then
    SYSTEMD_DIR="/etc/containers/systemd"
    SYSTEMCTL_CMD="systemctl"
    echo "ℹ️  Running as ROOT. Using system-wide Quadlet dir: $SYSTEMD_DIR"
else
    SYSTEMD_DIR="$HOME/.config/containers/systemd"
    SYSTEMCTL_CMD="systemctl --user"
    echo "ℹ️  Running as USER. Using user-scope Quadlet dir: $SYSTEMD_DIR"
fi

# Load config
if [ -f config.env ]; then
    export $(grep -v '^#' config.env | xargs)
fi

BASE_PORT=${BASE_PORT:-10000}
MEMORY_LIMIT=${MEMORY_LIMIT:-256M}

# Ensure config exists
if [ ! -f singbox.json ]; then
    echo "⚠️ singbox.json not found. Running generator..."
    python3 scripts/gen_config.py
fi

# Create Quadlet directory
mkdir -p "$SYSTEMD_DIR"

# Generate .container file
echo ">>> Generating Quadlet file..."
cat > "$SYSTEMD_DIR/remote-proxy.container" <<EOF
[Unit]
Description=Remote Proxy Service (Sing-box)
After=network-online.target

[Container]
Image=ghcr.io/sagernet/sing-box:latest
ContainerName=remote-proxy
Volume=$(pwd)/singbox.json:/etc/sing-box/config.json:Z
# Expose ports (Base to Base+4)
PublishPort=${BASE_PORT}:${BASE_PORT}
PublishPort=$((${BASE_PORT}+1)):$((${BASE_PORT}+1))
PublishPort=$((${BASE_PORT}+2)):$((${BASE_PORT}+2))
PublishPort=$((${BASE_PORT}+3)):$((${BASE_PORT}+3))
PublishPort=$((${BASE_PORT}+4)):$((${BASE_PORT}+4))
# Resources
Memory=${MEMORY_LIMIT}
# Command
Exec=run -c /etc/sing-box/config.json

[Service]
Restart=always
TimeoutStartSec=900
EOF

# Reload Systemd
echo ">>> Reloading Systemd..."
$SYSTEMCTL_CMD daemon-reload

# Start Service
echo ">>> Starting Service..."
$SYSTEMCTL_CMD enable --now remote-proxy

# Check status
sleep 2
$SYSTEMCTL_CMD status remote-proxy --no-pager

echo "✅ Deployment initiated. Check logs with: journalctl -u remote-proxy -f"
if [ "$IS_ROOT" -eq 0 ]; then
    echo "   (User mode logs: journalctl --user -u remote-proxy -f)"
fi
