#!/bin/bash

remote_proxy_runtime_policy() {
    echo "${REMOTE_PROXY_RUNTIME_POLICY:-hybrid}"
}

remote_proxy_runtime_os_release_file() {
    echo "${REMOTE_PROXY_OS_RELEASE_FILE:-/etc/os-release}"
}

remote_proxy_runtime_os_release_value() {
    local key="$1"
    local file
    file="$(remote_proxy_runtime_os_release_file)"

    if [ ! -f "$file" ]; then
        return 1
    fi

    awk -F= -v target="$key" '
        $1 == target {
            value = substr($0, index($0, "=") + 1)
            gsub(/^"/, "", value)
            gsub(/"$/, "", value)
            print value
            exit 0
        }
    ' "$file"
}

remote_proxy_runtime_detect_os() {
    export REMOTE_PROXY_OS_ID
    export REMOTE_PROXY_OS_VERSION_ID
    export REMOTE_PROXY_OS_PRETTY_NAME

    REMOTE_PROXY_OS_ID="${REMOTE_PROXY_OS_ID:-$(remote_proxy_runtime_os_release_value ID 2>/dev/null || true)}"
    REMOTE_PROXY_OS_VERSION_ID="${REMOTE_PROXY_OS_VERSION_ID:-$(remote_proxy_runtime_os_release_value VERSION_ID 2>/dev/null || true)}"
    REMOTE_PROXY_OS_PRETTY_NAME="${REMOTE_PROXY_OS_PRETTY_NAME:-$(remote_proxy_runtime_os_release_value PRETTY_NAME 2>/dev/null || true)}"

    if [ -z "${REMOTE_PROXY_OS_ID:-}" ]; then
        REMOTE_PROXY_OS_ID="unknown"
    fi
    if [ -z "${REMOTE_PROXY_OS_VERSION_ID:-}" ]; then
        REMOTE_PROXY_OS_VERSION_ID="unknown"
    fi
    if [ -z "${REMOTE_PROXY_OS_PRETTY_NAME:-}" ]; then
        REMOTE_PROXY_OS_PRETTY_NAME="$REMOTE_PROXY_OS_ID $REMOTE_PROXY_OS_VERSION_ID"
    fi
}

remote_proxy_runtime_version_ge() {
    local candidate="$1"
    local minimum="$2"
    local first

    first="$(printf '%s\n%s\n' "$minimum" "$candidate" | sort -V | head -n 1)"
    [ "$first" = "$minimum" ]
}

remote_proxy_runtime_python_version() {
    local python_bin="$1"

    "$python_bin" -c 'import sys; print("{}.{}.{}".format(*sys.version_info[:3]))' 2>/dev/null
}

remote_proxy_runtime_python_candidates() {
    if [ -n "${REMOTE_PROXY_PYTHON_BIN:-}" ]; then
        printf '%s\n' "$REMOTE_PROXY_PYTHON_BIN"
    fi

    printf '%s\n' \
        python3 \
        python3.13 \
        python3.12 \
        python3.11 \
        python3.10 \
        python3.9
}

remote_proxy_runtime_select_existing_python() {
    local minimum_version="${1:-3.9}"
    local candidate
    local resolved
    local version

    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        if ! resolved="$(command -v "$candidate" 2>/dev/null)"; then
            continue
        fi
        version="$(remote_proxy_runtime_python_version "$resolved")"
        if [ -z "$version" ]; then
            continue
        fi
        if remote_proxy_runtime_version_ge "$version" "$minimum_version"; then
            export REMOTE_PROXY_PYTHON_BIN="$candidate"
            export REMOTE_PROXY_PYTHON_VERSION="$version"
            return 0
        fi
    done < <(remote_proxy_runtime_python_candidates)

    return 1
}

remote_proxy_runtime_package_manager() {
    if command -v apt-get >/dev/null 2>&1; then
        echo "apt"
        return 0
    fi
    if command -v yum >/dev/null 2>&1; then
        echo "yum"
        return 0
    fi
    return 1
}

remote_proxy_runtime_sudo_cmd() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi
    echo "sudo"
}

remote_proxy_runtime_apt_package_available() {
    local package_name="$1"
    apt-cache show "$package_name" >/dev/null 2>&1
}

remote_proxy_runtime_yum_package_available() {
    local package_name="$1"
    yum info -q "$package_name" >/dev/null 2>&1
}

remote_proxy_runtime_install_python_from_repo() {
    local minimum_version="${1:-3.9}"
    local package_manager
    local sudo_cmd
    local spec
    local command_name
    local package_name
    local version

    if ! package_manager="$(remote_proxy_runtime_package_manager)"; then
        return 1
    fi
    sudo_cmd="$(remote_proxy_runtime_sudo_cmd || true)"

    case "$package_manager" in
        apt)
            for spec in \
                "python3.13:python3.13" \
                "python3.12:python3.12" \
                "python3.11:python3.11" \
                "python3.10:python3.10" \
                "python3.9:python3.9"
            do
                command_name="${spec%%:*}"
                package_name="${spec##*:}"
                if ! remote_proxy_runtime_apt_package_available "$package_name"; then
                    continue
                fi
                echo ">>> Installing compatible Python from native repo: $package_name"
                if [ -n "$sudo_cmd" ]; then
                    "$sudo_cmd" apt-get install -yq "$package_name"
                else
                    apt-get install -yq "$package_name"
                fi
                if command -v "$command_name" >/dev/null 2>&1; then
                    version="$(remote_proxy_runtime_python_version "$command_name")"
                    if [ -n "$version" ] && remote_proxy_runtime_version_ge "$version" "$minimum_version"; then
                        export REMOTE_PROXY_PYTHON_BIN="$command_name"
                        export REMOTE_PROXY_PYTHON_VERSION="$version"
                        return 0
                    fi
                fi
            done
            ;;
        yum)
            for spec in \
                "python3.13:python3.13" \
                "python3.12:python3.12" \
                "python3.11:python3.11" \
                "python3.10:python3.10" \
                "python3.9:python3.9" \
                "python3.9:python39"
            do
                command_name="${spec%%:*}"
                package_name="${spec##*:}"
                if ! remote_proxy_runtime_yum_package_available "$package_name"; then
                    continue
                fi
                echo ">>> Installing compatible Python from native repo: $package_name"
                if [ -n "$sudo_cmd" ]; then
                    "$sudo_cmd" yum install -y "$package_name"
                else
                    yum install -y "$package_name"
                fi
                if command -v "$command_name" >/dev/null 2>&1; then
                    version="$(remote_proxy_runtime_python_version "$command_name")"
                    if [ -n "$version" ] && remote_proxy_runtime_version_ge "$version" "$minimum_version"; then
                        export REMOTE_PROXY_PYTHON_BIN="$command_name"
                        export REMOTE_PROXY_PYTHON_VERSION="$version"
                        return 0
                    fi
                fi
            done
            ;;
    esac

    return 1
}

remote_proxy_runtime_require_commands() {
    local missing=0
    local command_name

    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            echo "ERROR: missing required command: $command_name" >&2
            missing=1
        fi
    done

    if [ "$missing" -ne 0 ]; then
        return 1
    fi
    return 0
}

remote_proxy_runtime_fail_python() {
    local minimum_version="${1:-3.9}"

    remote_proxy_runtime_detect_os
    echo "ERROR: no compatible Python >= $minimum_version detected on ${REMOTE_PROXY_OS_PRETTY_NAME}." >&2
    echo "ERROR: hybrid mode only auto-installs versioned Python packages visible from the current native repositories." >&2
    echo "ERROR: set REMOTE_PROXY_PYTHON_BIN to a verified interpreter path, or upgrade the host OS baseline." >&2
    return 1
}

remote_proxy_runtime_resolve_python() {
    local mode="${1:-check}"
    local minimum_version="${2:-3.9}"
    local policy

    policy="$(remote_proxy_runtime_policy)"
    if remote_proxy_runtime_select_existing_python "$minimum_version"; then
        return 0
    fi

    case "$mode" in
        ensure)
            case "$policy" in
                auto|hybrid)
                    if remote_proxy_runtime_install_python_from_repo "$minimum_version"; then
                        return 0
                    fi
                    ;;
            esac
            ;;
    esac

    remote_proxy_runtime_fail_python "$minimum_version"
}

remote_proxy_runtime_preflight() {
    local mode="${1:-check}"
    local minimum_python_version="${2:-3.9}"
    shift 2 || true

    remote_proxy_runtime_detect_os
    remote_proxy_runtime_resolve_python "$mode" "$minimum_python_version" || return 1
    if [ "$#" -gt 0 ]; then
        remote_proxy_runtime_require_commands "$@" || return 1
    fi
    echo ">>> Runtime compatibility OK: ${REMOTE_PROXY_OS_PRETTY_NAME} / ${REMOTE_PROXY_PYTHON_BIN} (${REMOTE_PROXY_PYTHON_VERSION})"
}
