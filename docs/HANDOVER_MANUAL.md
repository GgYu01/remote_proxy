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

### 初始化脚本详解 (Initialization Scripts)
本项目包含一套完整的初始化工具链，位于 `scripts/` 目录下：

1.  **`setup_env.sh` (环境准备)**
    - **功能**: 自动检测 Linux 发行版 (Debian/Ubuntu/CentOS)，更新 `apt/yum` 源，安装 `podman`, `curl`, `python3` 等必要依赖。
    - **特色**: 自动处理 Rootless Podman 所需的 `uidmap` 和 `slirp4netns`，无需手动干预。

2.  **`manage_swap.sh` (内存保障)**
    - **功能**: 检测系统 Swap 空间。如果不足 (默认要求 2GB)，自动创建 `/swapfile` 并挂载。
    - **配置**: 可通过 `config.env` 中的 `SWAP_SIZE_GB` 调整大小。
    - **安全**: 自动设置 `600` 权限，防止敏感信息泄露。

3.  **`deploy.sh` (容器编排)**
    - **功能**: 生成 Systemd Unit 文件 (`.container`)。
    - **网络**: 使用 **Bridge 模式** (非 Host)，通过 `PublishPort` 映射端口，确保容器隔离性。
    - **自愈**: 配置 `Restart=always`，确保服务崩溃或重启后自动恢复。

### 手动部署 (Step-by-Step)
如果不使用一键脚本，可以分步执行：
1. **环境准备**: `./scripts/setup_env.sh`
2. **生成密钥**: `./scripts/gen_keys.sh` (用于 Reality)
3. **生成配置**: `python3 scripts/gen_config.py`
4. **部署服务**: `./scripts/deploy.sh`

### 常见维护操作
- **查看日志**: `journalctl --user -u remote-proxy -f`
- **更新配置**: 修改 `.env` 后重新运行 `generate_config.sh` 并 `systemctl --user restart proxy-service`
