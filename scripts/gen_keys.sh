#!/bin/bash
# ==============================================================================
# Script Name: gen_keys.sh
# Description: Generates X25519 keys for Reality using the sing-box container
# ==============================================================================

# Check if keys already exist in config.env
if grep -q "REALITY_PRIVATE_KEY=" config.env 2>/dev/null && \
   grep -q "REALITY_PRIVATE_KEY=." config.env; then
    echo "ℹ️  Reality keys already present."
    exit 0
fi

echo "🔑 Generating Reality Keypair..."

# Try to use podman/docker to run sing-box generate
CONTAINER_CMD="podman"
if ! command -v podman &> /dev/null; then
    CONTAINER_CMD="docker"
fi

# Run ephemeral container to gen keys
OUTPUT=$($CONTAINER_CMD run --rm ghcr.io/sagernet/sing-box:latest generate reality-keypair)

# Parse output (format: "PrivateKey: ... \n PublicKey: ...")
PRIV_KEY=$(echo "$OUTPUT" | grep "PrivateKey" | awk '{print $2}')
PUB_KEY=$(echo "$OUTPUT" | grep "PublicKey" | awk '{print $2}')
SHORT_ID=$(openssl rand -hex 8)

if [ -z "$PRIV_KEY" ]; then
    echo "❌ Failed to generate keys. Output: $OUTPUT"
    exit 1
fi

echo "✅ Generated Keys."

# Check if VLESS_UUID is set, if not, generate one
CURRENT_UUID=$(grep "^VLESS_UUID=" config.env | cut -d'=' -f2)
if [ -z "$CURRENT_UUID" ]; then
    echo "🔑 Generating new VLESS_UUID..."
    NEW_UUID=$(uuidgen || cat /proc/sys/kernel/random/uuid)
    # We need to replace the empty line or append.
    # Easiest is to append an override at the bottom.
    echo "VLESS_UUID=$NEW_UUID" >> config.env
    echo "   UUID: $NEW_UUID"
else
    echo "ℹ️  VLESS_UUID already set."
fi

# Append Reality keys to config.env
{
    echo ""
    echo "# --- Reality Keys (Auto-Generated) ---"
    echo "REALITY_PRIVATE_KEY=$PRIV_KEY"
    echo "REALITY_PUBLIC_KEY=$PUB_KEY"
    echo "REALITY_SHORT_ID=$SHORT_ID"
} >> config.env

echo "💾 Saved keys to config.env"
