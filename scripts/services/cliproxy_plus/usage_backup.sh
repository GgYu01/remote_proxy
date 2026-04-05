#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../../lib/common.sh"

remote_proxy_load_env_file "$(remote_proxy_cliproxy_env_file)"

CLIPROXY_PORT="${CLIPROXY_PORT:-8317}"
CLIPROXY_MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_KEY:-}"
STATE_ROOT="$(remote_proxy_cliproxy_service_root)"
USAGE_DIR="$STATE_ROOT/usage"
USAGE_FILE="$USAGE_DIR/latest.json"
TMP_FILE="$USAGE_DIR/latest.json.tmp"

mkdir -p "$USAGE_DIR"

if [ -z "$CLIPROXY_MANAGEMENT_KEY" ]; then
    echo "ERROR: CLIPROXY_MANAGEMENT_KEY is required for usage backup" >&2
    exit 1
fi

curl -fsS \
    -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
    "http://127.0.0.1:${CLIPROXY_PORT}/v0/management/usage/export" > "$TMP_FILE"

mv "$TMP_FILE" "$USAGE_FILE"
echo "[OK] usage backup written to $USAGE_FILE"
