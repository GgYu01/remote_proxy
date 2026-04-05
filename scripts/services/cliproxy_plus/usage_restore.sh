#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../../lib/common.sh"

remote_proxy_load_env_file "$(remote_proxy_cliproxy_env_file)"

CLIPROXY_PORT="${CLIPROXY_PORT:-8317}"
CLIPROXY_MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_KEY:-}"
USAGE_FILE="$(remote_proxy_cliproxy_service_root)/usage/latest.json"
RESTORE_ATTEMPTS="${CLIPROXY_RESTORE_ATTEMPTS:-10}"
RESTORE_SLEEP_SECONDS="${CLIPROXY_RESTORE_SLEEP_SECONDS:-2}"

if [ ! -f "$USAGE_FILE" ]; then
    echo "[INFO] no usage backup found at $USAGE_FILE"
    exit 0
fi

if [ -z "$CLIPROXY_MANAGEMENT_KEY" ]; then
    echo "ERROR: CLIPROXY_MANAGEMENT_KEY is required for usage restore" >&2
    exit 1
fi

for ((attempt=1; attempt<=RESTORE_ATTEMPTS; attempt++)); do
    if curl -fsS \
        -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
        -H "Content-Type: application/json" \
        --data-binary "@${USAGE_FILE}" \
        "http://127.0.0.1:${CLIPROXY_PORT}/v0/management/usage/import" >/dev/null; then
        echo "[OK] usage restore posted from $USAGE_FILE"
        exit 0
    fi
    if [ "$attempt" -lt "$RESTORE_ATTEMPTS" ]; then
        sleep "$RESTORE_SLEEP_SECONDS"
    fi
done

echo "ERROR: usage restore failed after ${RESTORE_ATTEMPTS} attempts" >&2
exit 1
