#!/bin/bash
set -euo pipefail

# ==============================================================================
# Script Name: setup_env.sh
# Description: Prepares the environment (Update, Podman, Swap)
# ==============================================================================

# Load config if exists
if [ -f config.env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./config.env
    set +a
elif [ -f config/cliproxy-plus.env ]; then
    set -a
    # shellcheck disable=SC1091
    . ./config/cliproxy-plus.env
    set +a
fi

SWAP_SIZE=${SWAP_SIZE_GB:-2}
ALLOW_FULL_UPGRADE=${SETUP_ENV_ALLOW_FULL_UPGRADE:-false}
if [ "$(id -u)" -eq 0 ]; then
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

echo ">>> [1/3] Updating System Packages..."
# Check for apt (Debian/Ubuntu)
if command -v apt-get &> /dev/null; then
    ${SUDO_CMD} apt-get update -q
    if [ "$ALLOW_FULL_UPGRADE" = "true" ]; then
        ${SUDO_CMD} apt-get upgrade -yq
    else
        echo ">>> Skipping full apt-get upgrade (SETUP_ENV_ALLOW_FULL_UPGRADE=false)"
    fi
    ${SUDO_CMD} apt-get install -yq curl jq python3 podman uidmap slirp4netns systemd-container
elif command -v yum &> /dev/null; then
    if [ "$ALLOW_FULL_UPGRADE" = "true" ]; then
        ${SUDO_CMD} yum update -y
    else
        echo ">>> Skipping full yum update (SETUP_ENV_ALLOW_FULL_UPGRADE=false)"
    fi
    ${SUDO_CMD} yum install -y curl jq python3 podman
else
    echo "⚠️  Unsupported package manager. Please ensure Podman is installed manually."
fi

echo ">>> [2/3] Configuring Swap..."
chmod +x scripts/manage_swap.sh
${SUDO_CMD} ./scripts/manage_swap.sh --size "$SWAP_SIZE"

echo ">>> [3/3] Verifying Podman..."
podman info > /dev/null
echo "✅ Environment Setup Complete."
