#!/bin/bash
set -euo pipefail

COMMON_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck disable=SC1091
. "$COMMON_LIB_DIR/runtime_compat.sh"

remote_proxy_repo_root() {
    pwd -P
}

remote_proxy_legacy_state_root() {
    echo "$(remote_proxy_repo_root)/state"
}

remote_proxy_state_root() {
    if [ -n "${REMOTE_PROXY_STATE_ROOT:-}" ]; then
        echo "$REMOTE_PROXY_STATE_ROOT"
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        echo "/var/lib/remote_proxy"
        return 0
    fi

    echo "$(remote_proxy_legacy_state_root)"
}

remote_proxy_legacy_config_root() {
    echo "$(remote_proxy_repo_root)/config"
}

remote_proxy_config_root() {
    if [ -n "${REMOTE_PROXY_CONFIG_ROOT:-}" ]; then
        echo "$REMOTE_PROXY_CONFIG_ROOT"
        return 0
    fi

    if [ "$(id -u)" -eq 0 ]; then
        echo "/etc/remote_proxy"
        return 0
    fi

    echo "$(remote_proxy_legacy_config_root)"
}

remote_proxy_copy_if_missing() {
    local source_path="$1"
    local target_path="$2"

    if [ ! -e "$source_path" ] || [ -e "$target_path" ]; then
        return 0
    fi

    mkdir -p "$(dirname "$target_path")"
    cp -a "$source_path" "$target_path"
}

remote_proxy_append_env_default_if_missing() {
    local env_file="$1"
    local key="$2"
    local value="$3"

    if [ ! -f "$env_file" ]; then
        return 0
    fi

    if grep -q "^${key}=" "$env_file"; then
        return 0
    fi

    printf '%s=%s\n' "$key" "$value" >> "$env_file"
}

remote_proxy_set_env_value() {
    local env_file="$1"
    local key="$2"
    local value="$3"
    local tmp_file

    mkdir -p "$(dirname "$env_file")"
    tmp_file="$(mktemp "${env_file}.XXXXXX")"
    if [ -f "$env_file" ]; then
        awk -v key="$key" -v value="$value" '
            BEGIN { replaced = 0 }
            $0 ~ "^" key "=" {
                print key "=" value
                replaced = 1
                next
            }
            { print }
            END {
                if (replaced == 0) {
                    print key "=" value
                }
            }
        ' "$env_file" > "$tmp_file"
    else
        printf '%s=%s\n' "$key" "$value" > "$tmp_file"
    fi
    mv "$tmp_file" "$env_file"
}

remote_proxy_read_env_value() {
    local env_file="$1"
    local key="$2"

    if [ ! -f "$env_file" ]; then
        return 0
    fi
    awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); found = 1; exit } END { exit found ? 0 : 0 }' "$env_file"
}

remote_proxy_cliproxy_default_image() {
    echo "${REMOTE_PROXY_CLIPROXY_DEFAULT_IMAGE:-docker.io/eceasy/cli-proxy-api:latest}"
}

remote_proxy_cpa_usage_keeper_default_image() {
    echo "${REMOTE_PROXY_CPA_USAGE_KEEPER_DEFAULT_IMAGE:-ghcr.io/willxup/cpa-usage-keeper:latest}"
}

remote_proxy_cliproxy_keep_configured_image() {
    [ "${REMOTE_PROXY_CLIPROXY_KEEP_CONFIGURED_IMAGE:-false}" = "true" ]
}

remote_proxy_cpa_usage_keeper_keep_configured_image() {
    [ "${REMOTE_PROXY_CPA_USAGE_KEEPER_KEEP_CONFIGURED_IMAGE:-false}" = "true" ]
}

remote_proxy_cliproxy_is_managed_official_image() {
    case "${1:-}" in
        eceasy/cli-proxy-api|\
        eceasy/cli-proxy-api:*|\
        eceasy/cli-proxy-api@*|\
        docker.io/eceasy/cli-proxy-api|\
        docker.io/eceasy/cli-proxy-api:*|\
        docker.io/eceasy/cli-proxy-api@*|\
        eceasy/cli-proxy-api-plus|\
        eceasy/cli-proxy-api-plus:*|\
        eceasy/cli-proxy-api-plus@*|\
        docker.io/eceasy/cli-proxy-api-plus|\
        docker.io/eceasy/cli-proxy-api-plus:*|\
        docker.io/eceasy/cli-proxy-api-plus@*)
            return 0
            ;;
    esac
    return 1
}

remote_proxy_cpa_usage_keeper_is_managed_official_image() {
    case "${1:-}" in
        ghcr.io/willxup/cpa-usage-keeper|\
        ghcr.io/willxup/cpa-usage-keeper:*|\
        ghcr.io/willxup/cpa-usage-keeper@*|\
        willxup/cpa-usage-keeper|\
        willxup/cpa-usage-keeper:*|\
        willxup/cpa-usage-keeper@*)
            return 0
            ;;
    esac
    return 1
}

remote_proxy_cliproxy_should_use_default_image() {
    local current_image="${1:-}"
    local default_image

    default_image="$(remote_proxy_cliproxy_default_image)"
    if [ -z "$current_image" ]; then
        return 0
    fi
    if [ "$current_image" = "$default_image" ]; then
        return 1
    fi
    remote_proxy_cliproxy_is_managed_official_image "$current_image"
}

remote_proxy_cpa_usage_keeper_should_use_default_image() {
    local current_image="${1:-}"
    local default_image

    default_image="$(remote_proxy_cpa_usage_keeper_default_image)"
    if [ -z "$current_image" ]; then
        return 0
    fi
    if [ "$current_image" = "$default_image" ]; then
        return 1
    fi
    remote_proxy_cpa_usage_keeper_is_managed_official_image "$current_image"
}

remote_proxy_ensure_cliproxy_image_default() {
    local env_file="$1"
    local current_image
    local default_image

    if [ ! -f "$env_file" ]; then
        return 0
    fi

    current_image="$(remote_proxy_read_env_value "$env_file" "CLIPROXY_IMAGE")"
    default_image="$(remote_proxy_cliproxy_default_image)"
    if remote_proxy_cliproxy_keep_configured_image && [ -n "$current_image" ]; then
        return 0
    fi
    if remote_proxy_cliproxy_should_use_default_image "$current_image"; then
        remote_proxy_set_env_value "$env_file" "CLIPROXY_IMAGE" "$default_image"
        if [ -n "$current_image" ]; then
            echo "[INFO] migrated CLIPROXY_IMAGE from $current_image to $default_image"
        fi
    fi
}

remote_proxy_ensure_cpa_usage_keeper_image_default() {
    local env_file="$1"
    local current_image
    local default_image

    if [ ! -f "$env_file" ]; then
        return 0
    fi

    current_image="$(remote_proxy_read_env_value "$env_file" "CPA_USAGE_KEEPER_IMAGE")"
    default_image="$(remote_proxy_cpa_usage_keeper_default_image)"
    if remote_proxy_cpa_usage_keeper_keep_configured_image && [ -n "$current_image" ]; then
        return 0
    fi
    if remote_proxy_cpa_usage_keeper_should_use_default_image "$current_image"; then
        remote_proxy_set_env_value "$env_file" "CPA_USAGE_KEEPER_IMAGE" "$default_image"
        if [ -n "$current_image" ]; then
            echo "[INFO] migrated CPA_USAGE_KEEPER_IMAGE from $current_image to $default_image"
        fi
    fi
}

remote_proxy_singbox_env_file() {
    if [ -n "${REMOTE_PROXY_SINGBOX_ENV_FILE:-}" ]; then
        echo "$REMOTE_PROXY_SINGBOX_ENV_FILE"
        return 0
    fi

    if [ -n "${REMOTE_PROXY_CONFIG_ROOT:-}" ] || [ "$(id -u)" -eq 0 ]; then
        echo "$(remote_proxy_config_root)/singbox.env"
        return 0
    fi

    echo "$(remote_proxy_repo_root)/config.env"
}

remote_proxy_singbox_runtime_root() {
    echo "$(remote_proxy_state_root)/singbox"
}

remote_proxy_singbox_rendered_config_path() {
    if [ -n "${REMOTE_PROXY_SINGBOX_RENDERED_CONFIG:-}" ]; then
        echo "$REMOTE_PROXY_SINGBOX_RENDERED_CONFIG"
        return 0
    fi

    if [ -n "${REMOTE_PROXY_STATE_ROOT:-}" ] || [ "$(id -u)" -eq 0 ]; then
        echo "$(remote_proxy_singbox_runtime_root)/config.json"
        return 0
    fi

    echo "$(remote_proxy_repo_root)/singbox.json"
}

remote_proxy_ensure_singbox_layout() {
    local env_file
    local rendered_config

    env_file="$(remote_proxy_singbox_env_file)"
    rendered_config="$(remote_proxy_singbox_rendered_config_path)"

    mkdir -p "$(dirname "$env_file")" "$(dirname "$rendered_config")"
    remote_proxy_copy_if_missing "$(remote_proxy_repo_root)/config.env" "$env_file"
    remote_proxy_copy_if_missing "$(remote_proxy_repo_root)/singbox.json" "$rendered_config"
    remote_proxy_append_env_default_if_missing "$env_file" "SING_BOX_RESOURCE_PRIORITY" "high"
}

remote_proxy_ensure_cliproxy_layout() {
    local env_file
    local service_root
    local legacy_env
    local legacy_root

    env_file="$(remote_proxy_cliproxy_env_file)"
    service_root="$(remote_proxy_cliproxy_service_root)"
    legacy_env="$(remote_proxy_repo_root)/config/cliproxy-plus.env"
    legacy_root="$(remote_proxy_repo_root)/state/cliproxy-plus"

    mkdir -p "$(dirname "$env_file")" "$service_root"
    remote_proxy_copy_if_missing "$legacy_env" "$env_file"
    remote_proxy_append_env_default_if_missing \
        "$env_file" \
        "CLIPROXY_NETWORK_MODE" \
        "private"
    remote_proxy_append_env_default_if_missing \
        "$env_file" \
        "CLIPROXY_RESOURCE_PRIORITY" \
        "high"
    remote_proxy_append_env_default_if_missing \
        "$env_file" \
        "CLIPROXY_USAGE_STATISTICS_ENABLED" \
        "true"
    remote_proxy_append_env_default_if_missing \
        "$env_file" \
        "CLIPROXY_REDIS_USAGE_QUEUE_RETENTION_SECONDS" \
        "3600"
    remote_proxy_append_env_default_if_missing \
        "$env_file" \
        "CLIPROXY_QUOTA_EXCEEDED_ANTIGRAVITY_CREDITS" \
        "true"
    remote_proxy_ensure_cliproxy_image_default "$env_file"

    if [ -d "$legacy_root" ] && [ "$legacy_root" != "$service_root" ]; then
        mkdir -p "$service_root"
        if [ ! -e "$service_root/config.yaml" ] && [ -e "$legacy_root/config.yaml" ]; then
            cp -a "$legacy_root/config.yaml" "$service_root/config.yaml"
        fi
        for entry in auths logs usage; do
            if [ ! -e "$service_root/$entry" ] && [ -e "$legacy_root/$entry" ]; then
                cp -a "$legacy_root/$entry" "$service_root/$entry"
            fi
        done
    fi
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

remote_proxy_resource_value() {
    local prefix="$1"
    local suffix="$2"
    local default_value="${3:-}"
    local service_key="${prefix}_${suffix}"
    local global_key="REMOTE_PROXY_${suffix}"
    local service_value="${!service_key:-}"
    local global_value="${!global_key:-}"

    if [ -n "$service_value" ]; then
        echo "$service_value"
        return 0
    fi
    if [ -n "$global_value" ]; then
        echo "$global_value"
        return 0
    fi
    echo "$default_value"
}

remote_proxy_resource_priority_enabled() {
    local prefix="$1"
    local policy

    policy="$(remote_proxy_resource_value "$prefix" "RESOURCE_PRIORITY" "high")"
    case "$policy" in
        0|false|FALSE|off|OFF|none|NONE|normal|NORMAL|disabled|DISABLED)
            return 1
            ;;
    esac
    return 0
}

remote_proxy_systemd_resource_lines() {
    local prefix="$1"
    local default_nice=""
    local default_oom_score_adjust=""
    local cpu_weight io_weight nice oom_score_adjust

    remote_proxy_resource_priority_enabled "$prefix" || return 0

    if [ "$(id -u)" -eq 0 ]; then
        default_nice="-5"
        default_oom_score_adjust="-500"
    fi

    cpu_weight="$(remote_proxy_resource_value "$prefix" "SYSTEMD_CPU_WEIGHT" "1000")"
    io_weight="$(remote_proxy_resource_value "$prefix" "SYSTEMD_IO_WEIGHT" "1000")"
    nice="$(remote_proxy_resource_value "$prefix" "SYSTEMD_NICE" "$default_nice")"
    oom_score_adjust="$(remote_proxy_resource_value "$prefix" "SYSTEMD_OOM_SCORE_ADJUST" "$default_oom_score_adjust")"

    [ -z "$cpu_weight" ] || printf 'CPUWeight=%s\n' "$cpu_weight"
    [ -z "$io_weight" ] || printf 'IOWeight=%s\n' "$io_weight"
    [ -z "$nice" ] || printf 'Nice=%s\n' "$nice"
    [ -z "$oom_score_adjust" ] || printf 'OOMScoreAdjust=%s\n' "$oom_score_adjust"
}

remote_proxy_podman_run_resource_args() {
    local prefix="$1"
    local default_cpu_shares=""
    local default_oom_score_adj=""
    local cpu_shares oom_score_adj

    remote_proxy_resource_priority_enabled "$prefix" || return 0

    if [ "$(id -u)" -eq 0 ]; then
        default_cpu_shares="2048"
        default_oom_score_adj="-500"
    fi

    cpu_shares="$(remote_proxy_resource_value "$prefix" "PODMAN_CPU_SHARES" "$default_cpu_shares")"
    oom_score_adj="$(remote_proxy_resource_value "$prefix" "PODMAN_OOM_SCORE_ADJ" "$default_oom_score_adj")"

    [ -z "$cpu_shares" ] || printf -- '--cpu-shares %s ' "$cpu_shares"
    [ -z "$oom_score_adj" ] || printf -- '--oom-score-adj %s ' "$oom_score_adj"
}

remote_proxy_quadlet_resource_lines() {
    local prefix="$1"
    local default_cpu_shares=""
    local default_oom_score_adj=""
    local cpu_shares oom_score_adj

    remote_proxy_resource_priority_enabled "$prefix" || return 0

    if [ "$(id -u)" -eq 0 ]; then
        default_cpu_shares="2048"
        default_oom_score_adj="-500"
    fi

    cpu_shares="$(remote_proxy_resource_value "$prefix" "PODMAN_CPU_SHARES" "$default_cpu_shares")"
    oom_score_adj="$(remote_proxy_resource_value "$prefix" "PODMAN_OOM_SCORE_ADJ" "$default_oom_score_adj")"

    [ -z "$cpu_shares" ] || printf 'PodmanArgs=--cpu-shares %s\n' "$cpu_shares"
    [ -z "$oom_score_adj" ] || printf 'PodmanArgs=--oom-score-adj %s\n' "$oom_score_adj"
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

remote_proxy_gateway_network_name() {
    echo "${REMOTE_PROXY_GATEWAY_NETWORK_NAME:-remote-proxy-gateway}"
}

remote_proxy_gateway_network_unit() {
    echo "$(remote_proxy_gateway_network_name).network"
}

remote_proxy_write_gateway_network_quadlet() {
    local network_file
    local network_name

    network_name="$(remote_proxy_gateway_network_name)"
    network_file="$REMOTE_PROXY_SYSTEMD_DIR/$(remote_proxy_gateway_network_unit)"
    mkdir -p "$REMOTE_PROXY_SYSTEMD_DIR"
    cat > "$network_file" <<EOF
[Network]
NetworkName=${network_name}
Driver=bridge
EOF
}

remote_proxy_cliproxy_service_root() {
    echo "$(remote_proxy_state_root)/cliproxy-plus"
}

remote_proxy_cliproxy_backup_root() {
    echo "$(remote_proxy_state_root)/backups/cliproxy-plus"
}

remote_proxy_cliproxy_env_file() {
    if [ -n "${REMOTE_PROXY_CLIPROXY_ENV_FILE:-}" ]; then
        echo "$REMOTE_PROXY_CLIPROXY_ENV_FILE"
        return 0
    fi

    if [ -n "${REMOTE_PROXY_CONFIG_ROOT:-}" ] || [ "$(id -u)" -eq 0 ]; then
        echo "$(remote_proxy_config_root)/cliproxy-plus.env"
        return 0
    fi

    echo "$(remote_proxy_repo_root)/config/cliproxy-plus.env"
}

remote_proxy_cpa_usage_keeper_env_file() {
    if [ -n "${REMOTE_PROXY_CPA_USAGE_KEEPER_ENV_FILE:-}" ]; then
        echo "$REMOTE_PROXY_CPA_USAGE_KEEPER_ENV_FILE"
        return 0
    fi

    if [ -n "${REMOTE_PROXY_CONFIG_ROOT:-}" ] || [ "$(id -u)" -eq 0 ]; then
        echo "$(remote_proxy_config_root)/cpa-usage-keeper.env"
        return 0
    fi

    echo "$(remote_proxy_repo_root)/config/cpa-usage-keeper.env"
}

remote_proxy_cpa_usage_keeper_service_root() {
    echo "$(remote_proxy_state_root)/cpa-usage-keeper"
}

remote_proxy_sea_gateway_env_file() {
    if [ -n "${REMOTE_PROXY_SEA_GATEWAY_ENV_FILE:-}" ]; then
        echo "$REMOTE_PROXY_SEA_GATEWAY_ENV_FILE"
        return 0
    fi

    if [ -n "${REMOTE_PROXY_CONFIG_ROOT:-}" ] || [ "$(id -u)" -eq 0 ]; then
        echo "$(remote_proxy_config_root)/sea-gateway.env"
        return 0
    fi

    echo "$(remote_proxy_repo_root)/config/sea-gateway.env"
}

remote_proxy_sea_gateway_service_root() {
    echo "$(remote_proxy_state_root)/sea-gateway"
}

remote_proxy_ensure_sea_gateway_layout() {
    local env_file
    local service_root
    local legacy_env

    env_file="$(remote_proxy_sea_gateway_env_file)"
    service_root="$(remote_proxy_sea_gateway_service_root)"
    legacy_env="$(remote_proxy_repo_root)/config/sea-gateway.env"

    mkdir -p "$(dirname "$env_file")" "$service_root"
    remote_proxy_copy_if_missing "$legacy_env" "$env_file"
}

remote_proxy_ensure_cpa_usage_keeper_layout() {
    local env_file
    local service_root
    local legacy_env

    env_file="$(remote_proxy_cpa_usage_keeper_env_file)"
    service_root="$(remote_proxy_cpa_usage_keeper_service_root)"
    legacy_env="$(remote_proxy_repo_root)/config/cpa-usage-keeper.env"

    mkdir -p "$(dirname "$env_file")" "$service_root"
    remote_proxy_copy_if_missing "$legacy_env" "$env_file"
    remote_proxy_append_env_default_if_missing "$env_file" "CPA_USAGE_KEEPER_IMAGE" "$(remote_proxy_cpa_usage_keeper_default_image)"
    remote_proxy_ensure_cpa_usage_keeper_image_default "$env_file"
    remote_proxy_append_env_default_if_missing "$env_file" "CPA_USAGE_KEEPER_NETWORK_MODE" "private"
    remote_proxy_append_env_default_if_missing "$env_file" "CPA_USAGE_KEEPER_RESOURCE_PRIORITY" "high"
    remote_proxy_append_env_default_if_missing "$env_file" "APP_PORT" "8080"
    remote_proxy_append_env_default_if_missing "$env_file" "WORK_DIR" "/data"
    remote_proxy_append_env_default_if_missing "$env_file" "REDIS_QUEUE_ADDR" "cliproxy-plus:8317"
    remote_proxy_append_env_default_if_missing "$env_file" "CPA_BASE_URL" "http://cliproxy-plus:8317"
    remote_proxy_append_env_default_if_missing "$env_file" "CPA_PUBLIC_URL" "https://keeper.sea.prod.gglohh.top"
    remote_proxy_append_env_default_if_missing "$env_file" "REDIS_QUEUE_BATCH_SIZE" "10000"
    remote_proxy_append_env_default_if_missing "$env_file" "REDIS_QUEUE_IDLE_INTERVAL" "1s"
    remote_proxy_append_env_default_if_missing "$env_file" "REQUEST_TIMEOUT" "30s"
    remote_proxy_append_env_default_if_missing "$env_file" "AUTH_ENABLED" "true"
}
