#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/../../lib/common.sh"

TARGET_TAG="${1:-}"
if [ -z "$TARGET_TAG" ]; then
    echo "ERROR: target tag is required" >&2
    exit 1
fi

ENV_FILE="$(remote_proxy_cliproxy_env_file)"
remote_proxy_load_env_file "$ENV_FILE"

mkdir -p "$(dirname "$ENV_FILE")"

if [ -f "$ENV_FILE" ] && grep -q '^CLIPROXY_IMAGE=' "$ENV_FILE"; then
    python3 - "$ENV_FILE" "$TARGET_TAG" <<'PY'
from pathlib import Path
import sys

env_path = Path(sys.argv[1])
target = sys.argv[2]
lines = env_path.read_text(encoding="utf-8").splitlines()
updated = []
replaced = False
for line in lines:
    if line.startswith("CLIPROXY_IMAGE="):
        updated.append(f"CLIPROXY_IMAGE={target}")
        replaced = True
    else:
        updated.append(line)
if not replaced:
    updated.append(f"CLIPROXY_IMAGE={target}")
env_path.write_text("\n".join(updated) + "\n", encoding="utf-8", newline="\n")
PY
else
    printf 'CLIPROXY_IMAGE=%s\n' "$TARGET_TAG" >> "$ENV_FILE"
fi

"$SCRIPT_DIR/usage_backup.sh"
"$SCRIPT_DIR/deploy.sh"
"$SCRIPT_DIR/usage_restore.sh"
"$SCRIPT_DIR/verify.sh"
