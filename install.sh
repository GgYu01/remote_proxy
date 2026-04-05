#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script Name: install.sh
# Description: One-click installation script
# ==============================================================================

echo "🚀 Starting Remote Proxy Installation..."

SERVICE_NAME="${1:-${REMOTE_PROXY_SERVICE:-singbox}}"

case "$SERVICE_NAME" in
    singbox)
        CONFIG_PATH="config.env"
        EXAMPLE_PATH="config.env.example"
        ;;
    cliproxy-plus)
        CONFIG_PATH="config/cliproxy-plus.env"
        EXAMPLE_PATH="config/cliproxy-plus.env.example"
        mkdir -p config
        ;;
    *)
        echo "❌ Unsupported service: $SERVICE_NAME"
        echo "   Supported services: singbox, cliproxy-plus"
        exit 1
        ;;
esac

# 0. Config Check
if [ ! -f "$CONFIG_PATH" ]; then
    echo "ℹ️  $CONFIG_PATH not found. Creating from default..."
    cp "$EXAMPLE_PATH" "$CONFIG_PATH"
    echo "⚠️  Created $CONFIG_PATH. You may want to edit it before proceeding."
    echo "   Press Enter to continue with defaults, or Ctrl+C to stop and edit."
    read -r
fi

# 1. Environment Setup
echo "🔧 Step 1: Setting up Environment..."
chmod +x scripts/*.sh
chmod +x scripts/service.sh scripts/services/cliproxy_plus/*.sh 2>/dev/null || true
./scripts/setup_env.sh

case "$SERVICE_NAME" in
    singbox)
        # 2. Generate Config
        echo "⚙️  Step 2: Generating Configuration..."
        ./scripts/gen_keys.sh
        python3 scripts/gen_config.py

        # 3. Deploy
        echo "🚀 Step 3: Deploying Service..."
        ./scripts/deploy.sh

        # 4. Show Info
        ./scripts/show_info.sh
        ;;
    cliproxy-plus)
        echo "⚙️  Step 2: Generating and Deploying CLIProxyAPIPlus..."
        ./scripts/service.sh cliproxy-plus install
        ;;
esac

echo "🎉 Installation Complete!"
echo "--------------------------------------------------------"
if [ "$(id -u)" -eq 0 ]; then
    if [ "$SERVICE_NAME" = "singbox" ]; then
        echo "Check service status: systemctl status remote-proxy"
        echo "View logs:            journalctl -u remote-proxy -f"
    else
        echo "Check service status: systemctl status cliproxy-plus"
        echo "View logs:            journalctl -u cliproxy-plus -f"
    fi
else
    if [ "$SERVICE_NAME" = "singbox" ]; then
        echo "Check service status: systemctl --user status remote-proxy"
        echo "View logs:            journalctl --user -u remote-proxy -f"
    else
        echo "Check service status: systemctl --user status cliproxy-plus"
        echo "View logs:            journalctl --user -u cliproxy-plus -f"
    fi
fi
echo "========================================================"
