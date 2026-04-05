#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

python3 "$SCRIPT_DIR/gen_config.py"
"$SCRIPT_DIR/deploy.sh"
"$SCRIPT_DIR/verify.sh"
