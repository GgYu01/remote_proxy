# 交接手册 (Handover Manual)

## 快速上手 (Quick Start)

### 前置要求
- Linux OS (Debian/Ubuntu recommended)
- Podman installed (`apt-get install podman`)
- Systemd enabled

### 部署步骤
1. 克隆仓库: `git clone ...`
2. 运行一键安装: `./install.sh`
   - 该脚本会自动配置环境、生成配置并启动服务。

### 手动部署 (Step-by-Step)
如果不使用一键脚本，可以分步执行：
1. **环境准备**: `./scripts/setup_env.sh`
2. **生成配置**: `python3 scripts/gen_config.py`
3. **部署服务**: `./scripts/deploy.sh`

### 常见维护操作
- **查看日志**: `journalctl --user -u remote-proxy -f`
- **更新配置**: 修改 `.env` 后重新运行 `generate_config.sh` 并 `systemctl --user restart proxy-service`
