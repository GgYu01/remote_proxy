#!/bin/bash
set -e
set -o pipefail

# ==============================================================================
# Script Name: setup_env.sh
# Description: Prepares the environment (Update, Podman, Swap)
# ==============================================================================

# Load config if exists
if [ -f config.env ]; then
    export $(grep -v '^#' config.env | xargs)
fi

SWAP_SIZE=${SWAP_SIZE_GB:-2}

echo ">>> [1/3] Updating System Packages..."
# Check for apt (Debian/Ubuntu)
if command -v apt-get &> /dev/null; then
    sudo apt-get update -q
    sudo apt-get upgrade -yq
    sudo apt-get install -yq curl jq python3 podman uidmap slirp4netns systemd-container
elif command -v yum &> /dev/null; then
    sudo yum update -y
    sudo yum install -y curl jq python3 podman
else
    echo "⚠️  Unsupported package manager. Please ensure Podman is installed manually."
fi

echo ">>> [2/3] Configuring Swap..."
chmod +x scripts/manage_swap.sh
sudo ./scripts/manage_swap.sh --size "$SWAP_SIZE"

echo ">>> [3/3] Verifying Podman..."
podman info > /dev/null
echo "✅ Environment Setup Complete."
