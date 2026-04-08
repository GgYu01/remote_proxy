#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../../lib/common.sh"

remote_proxy_load_env_file "$(remote_proxy_cliproxy_env_file)"

CLIPROXY_PORT="${CLIPROXY_PORT:-8317}"
CLIPROXY_MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_KEY:-}"
VERIFY_ATTEMPTS="${CLIPROXY_VERIFY_ATTEMPTS:-10}"
VERIFY_SLEEP_SECONDS="${CLIPROXY_VERIFY_SLEEP_SECONDS:-2}"

if [ -z "$CLIPROXY_MANAGEMENT_KEY" ]; then
    echo "ERROR: CLIPROXY_MANAGEMENT_KEY is required for verification" >&2
    exit 1
fi

for ((attempt=1; attempt<=VERIFY_ATTEMPTS; attempt++)); do
    if curl -fsS \
        -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
        "http://127.0.0.1:${CLIPROXY_PORT}/v0/management/usage" >/dev/null; then
        echo "[OK] cliproxy-plus management verification passed"
        exit 0
    fi
    if [ "$attempt" -lt "$VERIFY_ATTEMPTS" ]; then
        sleep "$VERIFY_SLEEP_SECONDS"
    fi
done

echo "ERROR: cliproxy-plus management verification failed after ${VERIFY_ATTEMPTS} attempts" >&2
exit 1
