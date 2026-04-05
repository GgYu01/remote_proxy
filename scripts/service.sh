#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"

SERVICE_NAME="${1:-${REMOTE_PROXY_SERVICE:-}}"
COMMAND_NAME="${2:-${REMOTE_PROXY_COMMAND:-}}"
ARG_ONE="${3:-${REMOTE_PROXY_ARG1:-}}"

if [ -z "$SERVICE_NAME" ] || [ -z "$COMMAND_NAME" ]; then
    echo "Usage: scripts/service.sh <service> <command> [arg]" >&2
    exit 1
fi

case "$SERVICE_NAME" in
    cliproxy-plus)
        SERVICE_DIR="$REPO_ROOT/scripts/services/cliproxy_plus"
        ;;
    singbox)
        echo "ERROR: shared singbox service entrypoint is not implemented yet" >&2
        exit 1
        ;;
    *)
        echo "ERROR: unsupported service: $SERVICE_NAME" >&2
        exit 1
        ;;
esac

case "$COMMAND_NAME" in
    install)
        "$SERVICE_DIR/install.sh"
        ;;
    verify)
        "$SERVICE_DIR/verify.sh"
        ;;
    update)
        "$SERVICE_DIR/usage_backup.sh"
        "$SERVICE_DIR/deploy.sh"
        "$SERVICE_DIR/usage_restore.sh"
        "$SERVICE_DIR/verify.sh"
        ;;
    switch-version)
        if [ -z "$ARG_ONE" ]; then
            echo "ERROR: switch-version requires a target image tag" >&2
            exit 1
        fi
        "$SERVICE_DIR/switch_version.sh" "$ARG_ONE"
        ;;
    *)
        echo "ERROR: unsupported command: $COMMAND_NAME" >&2
        exit 1
        ;;
esac
