# 交接手册 (Handover Manual)

## 快速上手 (Quick Start)

### 前置要求
- Linux OS (Debian/Ubuntu recommended)
- Podman installed (`apt-get install podman`)
- Systemd enabled

### 部署步骤
1. 克隆仓库: `git clone ...`
2. 生成配置: `./scripts/generate_config.sh`
3. 安装服务: `./scripts/install_service.sh`
4. 验证状态: `systemctl --user status proxy-service`

### 常见维护操作
- **查看日志**: `journalctl --user -u proxy-service -f`
- **更新配置**: 修改 `.env` 后重新运行 `generate_config.sh` 并 `systemctl --user restart proxy-service`
