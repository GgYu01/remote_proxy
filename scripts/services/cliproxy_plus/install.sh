#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
COMMON_LIB="$SCRIPT_DIR/../../lib/common.sh"
# shellcheck disable=SC1091
. "$COMMON_LIB"

preserve_usage=0
env_file="$(remote_proxy_cliproxy_env_file)"

remote_proxy_runtime_preflight check 3.9
remote_proxy_load_env_file "$env_file"

CLIPROXY_PORT="${CLIPROXY_PORT:-8317}"
CLIPROXY_MANAGEMENT_KEY="${CLIPROXY_MANAGEMENT_KEY:-}"

if [ -n "$CLIPROXY_MANAGEMENT_KEY" ] && curl -fsS \
    -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
    "http://127.0.0.1:${CLIPROXY_PORT}/v0/management/usage/export" >/dev/null 2>&1
then
    "$SCRIPT_DIR/usage_backup.sh"
    preserve_usage=1
else
    echo "[INFO] no existing CLIProxyAPIPlus usage snapshot detected; proceeding without usage backup"
fi

"$REMOTE_PROXY_PYTHON_BIN" "$SCRIPT_DIR/gen_config.py"
"$SCRIPT_DIR/deploy.sh"

if [ "$preserve_usage" -eq 1 ]; then
    "$SCRIPT_DIR/usage_restore.sh"
fi

"$SCRIPT_DIR/verify.sh"
