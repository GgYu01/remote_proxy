#!/bin/bash
set -euo pipefail

remote_proxy_repo_root() {
    pwd -P
}

remote_proxy_state_root() {
    echo "$(remote_proxy_repo_root)/state"
}

remote_proxy_config_root() {
    echo "$(remote_proxy_repo_root)/config"
}

remote_proxy_load_env_file() {
    local env_file="$1"
    if [ ! -f "$env_file" ]; then
        echo "ERROR: missing env file: $env_file" >&2
        return 1
    fi
    set -a
    # shellcheck disable=SC1090
    . "$env_file"
    set +a
}

remote_proxy_normalize_memory_limit() {
    local raw_value="${1:-}"
    local default_value="${2:-128M}"
    local minimum_mb="${3:-128}"
    local candidate="${raw_value:-$default_value}"

    if [[ "$candidate" =~ ^([0-9]+)[Mm]$ ]]; then
        local mem_mb="${BASH_REMATCH[1]}"
        if [ "$mem_mb" -lt "$minimum_mb" ]; then
            candidate="${minimum_mb}M"
        else
            candidate="${mem_mb}M"
        fi
    fi

    echo "$candidate"
}

remote_proxy_configure_systemd_scope() {
    if [ "$(id -u)" -eq 0 ]; then
        export REMOTE_PROXY_IS_ROOT=1
        export REMOTE_PROXY_SYSTEMD_DIR="/etc/containers/systemd"
        export REMOTE_PROXY_SYSTEMCTL_CMD="systemctl"
        export REMOTE_PROXY_WANTED_BY_TARGET="multi-user.target"
    else
        export REMOTE_PROXY_IS_ROOT=0
        export REMOTE_PROXY_SYSTEMD_DIR="$HOME/.config/containers/systemd"
        export REMOTE_PROXY_SYSTEMCTL_CMD="systemctl --user"
        export REMOTE_PROXY_WANTED_BY_TARGET="default.target"
    fi
}

remote_proxy_systemctl() {
    # shellcheck disable=SC2086
    $REMOTE_PROXY_SYSTEMCTL_CMD "$@"
}

remote_proxy_cliproxy_service_root() {
    echo "$(remote_proxy_state_root)/cliproxy-plus"
}

remote_proxy_cliproxy_env_file() {
    echo "$(remote_proxy_config_root)/cliproxy-plus.env"
}
