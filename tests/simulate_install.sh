#!/bin/bash
# ==============================================================================
# Script Name: simulate_install.sh
# Description: Mocks system commands to verify install.sh logic without root/vps
# ==============================================================================

TEST_DIR=$(mktemp -d)
PROJECT_DIR=$(pwd)
LOG_FILE="$PROJECT_DIR/tests/simulation.log"

# Setup Mock Environment
export PATH="$TEST_DIR:$PATH"
export HOME="$TEST_DIR/home"
mkdir -p "$HOME/.config/containers/systemd"

# Mock Functions
create_mock() {
    echo "#!/bin/bash" > "$TEST_DIR/$1"
    # Use double quotes for the inner echo so \$@ expands when the mock runs
    echo "echo \"[MOCK] Executing $1 \$@\" >> \"$LOG_FILE\"" >> "$TEST_DIR/$1"
    chmod +x "$TEST_DIR/$1"
}

# Create Mocks
create_mock "sudo"
create_mock "apt-get"
create_mock "yum"
create_mock "systemctl"
create_mock "swapon"
create_mock "swapoff"
create_mock "mkswap"
create_mock "fallocate"

# Specialized Podman Mock
echo "#!/bin/bash" > "$TEST_DIR/podman"
echo 'echo "[MOCK] Executing podman $@" >> "'"$LOG_FILE"'"' >> "$TEST_DIR/podman"
echo 'if [[ "$@" == *"generate reality-keypair"* ]]; then' >> "$TEST_DIR/podman"
echo '  echo "PrivateKey: mock_private_key_12345"' >> "$TEST_DIR/podman"
echo '  echo "PublicKey: mock_public_key_67890"' >> "$TEST_DIR/podman"
echo 'else' >> "$TEST_DIR/podman"
echo '  echo "Podman mock output"' >> "$TEST_DIR/podman"
echo 'fi' >> "$TEST_DIR/podman"
chmod +x "$TEST_DIR/podman"

# We do NOT mock python3 because we want to verify the actual python script logic

echo ">>> Starting Simulation..." > "$LOG_FILE"

# Prepare config
cp config.env.example config.env

# RUN INSTALL
# We use 'bash' to run it, assuming we are in project root
echo ">>> Running install.sh..."
# We need to trick setup_env.sh into thinking apt exists (it does via mock)
# But setup_env.sh checks `command -v apt-get`. Since we updated PATH, it should find it.

# Run install.sh and capture output
./install.sh >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

echo ">>> Simulation Finished with Exit Code: $EXIT_CODE"

# Assertions
FAILED=0

# 1. Check Exit Code
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ install.sh exited successfully."
else
    echo "❌ install.sh failed."
    FAILED=1
fi

# 2. Check Config Generation
if [ -f "singbox.json" ]; then
    echo "✅ singbox.json generated."
else
    echo "❌ singbox.json NOT generated."
    FAILED=1
fi

# 3. Check Quadlet File Generation
CONTAINER_FILE="$HOME/.config/containers/systemd/remote-proxy.container"
if [ -f "$CONTAINER_FILE" ]; then
    echo "✅ Quadlet .container file generated at correct path."
else
    echo "❌ Quadlet file missing: $CONTAINER_FILE"
    FAILED=1
fi

# 4. Check Mock Calls (grep log)
if grep -q "manage_swap.sh" "$LOG_FILE"; then
    echo "✅ manage_swap.sh called."
else
    echo "❌ manage_swap.sh NOT called."
    FAILED=1
fi

if grep -q "systemctl --user enable --now remote-proxy" "$LOG_FILE"; then
    echo "✅ Service enabled via systemctl."
else
    echo "❌ Service NOT enabled."
    FAILED=1
fi

# Cleanup
rm -rf "$TEST_DIR"
rm -f singbox.json config.env
echo "------------------------------------------------"
if [ $FAILED -eq 0 ]; then
    echo "🎉 STRICT CHECK PASSED: Logic Verified."
    exit 0
else
    echo "💀 STRICT CHECK FAILED: See $LOG_FILE for details."
    cat "$LOG_FILE"
    exit 1
fi
