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
echo "   Private: $PRIV_KEY"
echo "   Public:  $PUB_KEY"

# Append to config.env
{
    echo ""
    echo "# --- Reality Configuration (Auto-Generated) ---"
    echo "REALITY_PRIVATE_KEY=$PRIV_KEY"
    echo "REALITY_PUBLIC_KEY=$PUB_KEY"
    echo "REALITY_SHORT_ID=$SHORT_ID"
    echo "REALITY_DEST=www.microsoft.com:443"
    echo "REALITY_SERVER_NAMES=www.microsoft.com,microsoft.com"
} >> config.env

echo "💾 Saved to config.env"
