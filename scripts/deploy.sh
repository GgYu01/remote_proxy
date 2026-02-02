#!/bin/bash
set -e

# ==============================================================================
# Script Name: deploy.sh
# Description: Deploys the service using Podman Quadlet
# ==============================================================================

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
SYSTEMD_DIR="$HOME/.config/containers/systemd"
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
systemctl --user daemon-reload

# Start Service
echo ">>> Starting Service..."
systemctl --user enable --now remote-proxy

# Check status
sleep 2
systemctl --user status remote-proxy --no-pager

echo "✅ Deployment initiated. Check logs with: journalctl --user -u remote-proxy -f"
