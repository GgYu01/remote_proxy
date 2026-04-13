#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
COMPAT_LIB="$SCRIPT_DIR/../../lib/runtime_compat.sh"
# shellcheck disable=SC1091
. "$COMPAT_LIB"
remote_proxy_runtime_preflight check 3.9
"$REMOTE_PROXY_PYTHON_BIN" "$SCRIPT_DIR/gen_config.py"
"$SCRIPT_DIR/deploy.sh"
"$SCRIPT_DIR/verify.sh"
