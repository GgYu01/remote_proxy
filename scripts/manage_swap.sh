#!/bin/bash

# ==============================================================================
# Script Name: manage_swap.sh
# Description: A professional script to create or modify a swap file on a
#              Linux system. It safely handles existing swap configurations.
# Author:      AI Assistant
# Version:     1.1
# ==============================================================================

# --- Configuration ---
# 设置你想要的 SWAP 空间大小 (单位: GB)
# 你也可以通过命令行参数 -s 或 --size 来覆盖这个值
# sudo ./manage_swap.sh --size 4
# sudo ./manage_swap.sh --size 1
DEFAULT_SWAP_SIZE_GB=2
REPLACE_EXISTING=false

# 设置 SWAP 文件的路径
SWAP_FILE_PATH="/swapfile"
# --- End Configuration ---

# 脚本执行时若有任何命令失败则立即退出
set -e
# 管道中的命令失败也视为失败
set -o pipefail

# --- Functions ---

# 打印使用方法
print_usage() {
    echo "Usage: $0 [-s|--size <size_in_gb>] [--replace-existing] [-h|--help]"
    echo "  -s, --size    Specify the desired swap size in Gigabytes (e.g., 2)."
    echo "  --replace-existing    Replace an existing active swap instead of reusing it."
    echo "  -h, --help    Display this help message."
    echo ""
    echo "If no size is specified, it will use the default value of ${DEFAULT_SWAP_SIZE_GB}GB."
}

# 检查是否以 root 身份运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "❌ ERROR: This script must be run as root. Please use 'sudo' or log in as root." >&2
        exit 1
    fi
}

# 清理已存在的 swap
cleanup_existing_swap() {
    local existing_swap_path="$1"
    echo "INFO: Found existing swap at '${existing_swap_path}'."
    echo "INFO: Deactivating and removing old swap configuration..."

    # 停用 swap
    if ! swapoff "${existing_swap_path}"; then
        echo "⚠️ WARNING: Failed to deactivate swap at '${existing_swap_path}'. It might not be active." >&2
    fi

    # 从 /etc/fstab 中移除旧条目 (使用 sed 进行安全原地修改)
    if [ -f /etc/fstab ]; then
        sed -i.bak "\|${existing_swap_path}|d" /etc/fstab
        echo "INFO: Removed old swap entry from /etc/fstab. A backup was created at /etc/fstab.bak."
    fi

    # 删除旧的 swap 文件
    if [ -f "${existing_swap_path}" ]; then
        if ! rm -f "${existing_swap_path}"; then
            echo "❌ ERROR: Failed to delete old swap file at '${existing_swap_path}'." >&2
            exit 1
        fi
        echo "INFO: Successfully deleted old swap file: ${existing_swap_path}."
    fi
}

show_final_status() {
    echo ""
    echo "--- Final Verification ---"
    swapon --show
    echo "--------------------------"
    free -h
    echo "--------------------------"
}

# --- Main Logic ---

main() {
    # 解析命令行参数
    SWAP_SIZE_GB=${DEFAULT_SWAP_SIZE_GB}
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -s|--size)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    SWAP_SIZE_GB="$2"
                    shift
                else
                    echo "❌ ERROR: Size must be a positive integer." >&2
                    print_usage
                    exit 1
                fi
                ;;
            --replace-existing)
                REPLACE_EXISTING=true
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                echo "❌ ERROR: Unknown parameter passed: $1" >&2
                print_usage
                exit 1
                ;;
        esac
        shift
    done

    check_root

    echo "--- Swap Space Management ---"
    echo "🎯 Desired Swap Size: ${SWAP_SIZE_GB}GB"
    echo "💾 Swap File Path:    ${SWAP_FILE_PATH}"
    echo "-----------------------------"

    # 检查是否已存在 swap
    EXISTING_SWAP=$(swapon --show --noheadings | awk '{print $1}')

    if [ -n "$EXISTING_SWAP" ]; then
        if [ "$REPLACE_EXISTING" != "true" ]; then
            echo "INFO: Found active swap at '${EXISTING_SWAP}'. Reusing existing swap and skipping changes."
            echo "INFO: Pass --replace-existing if you explicitly want to recreate swap."
            show_final_status
            exit 0
        fi
        cleanup_existing_swap "$EXISTING_SWAP"
    fi

    # 检查磁盘空间是否足够 (转换为 KB 进行比较)
    local required_kb=$((SWAP_SIZE_GB * 1024 * 1024))
    local available_kb=$(df -k "$(dirname "$SWAP_FILE_PATH")" | awk 'NR==2 {print $4}')

    if [ "$available_kb" -lt "$required_kb" ]; then
        echo "❌ ERROR: Not enough disk space. Required: ${SWAP_SIZE_GB}GB, Available: $(numfmt --to=iec-i --suffix=B ${available_kb}K)." >&2
        exit 1
    fi
    echo "INFO: Disk space check passed."

    # 创建新的 swap 文件
    echo "INFO: Allocating ${SWAP_SIZE_GB}GB for the new swap file..."
    if command -v fallocate &> /dev/null; then
        fallocate -l "${SWAP_SIZE_GB}G" "$SWAP_FILE_PATH" || {
            echo "⚠️ WARNING: fallocate failed, falling back to dd (this may take a while)..."
            dd if=/dev/zero of="$SWAP_FILE_PATH" bs=1G count="$SWAP_SIZE_GB" status=progress
        }
    else
        echo "INFO: fallocate not found, using dd (this may take a while)..."
        dd if=/dev/zero of="$SWAP_FILE_PATH" bs=1G count="$SWAP_SIZE_GB" status=progress
    fi
    echo "INFO: File allocation complete."

    # 设置文件权限
    chmod 600 "$SWAP_FILE_PATH"
    echo "INFO: Set permissions to 600 for '${SWAP_FILE_PATH}'."

    # 将文件格式化为 swap
    mkswap "$SWAP_FILE_PATH"
    echo "INFO: Formatted '${SWAP_FILE_PATH}' as swap."

    # 启用 swap
    swapon "$SWAP_FILE_PATH"
    echo "INFO: Activated swap on '${SWAP_FILE_PATH}'."

    # 添加到 /etc/fstab 以实现持久化
    if ! grep -q "${SWAP_FILE_PATH}" /etc/fstab; then
        echo "${SWAP_FILE_PATH} none swap sw 0 0" >> /etc/fstab
        echo "INFO: Added swap entry to /etc/fstab for persistence."
    else
        echo "INFO: Swap entry already exists in /etc/fstab."
    fi

    echo ""
    echo "✅ Swap space successfully configured."
    show_final_status
}

# 执行主函数
main "$@"
