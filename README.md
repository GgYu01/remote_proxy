# Remote Proxy Deployment (Podman Quadlet)

这是一个基于 **Podman Quadlet** 和 **Sing-box** 的轻量级、多协议代理部署方案。

## ✨ 特性 (Features)
- **多协议支持**: 同时支持 SOCKS5, HTTP, Shadowsocks, VMess, Trojan。
- **内存优化**: 使用 Sing-box 统一核心，内存占用极低 (<50MB)。
- **原生 Podman**: 使用 Systemd 管理容器，无 Docker 守护进程开销。
- **一键部署**: 自动化脚本处理环境配置、Swap 挂载和服务启动。

## 🚀 快速开始 (Quick Start)

### 1. 克隆仓库
```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
```

### 2. 配置 (可选)
脚本会自动生成默认配置。如果需要修改端口或密码，请编辑 `config.env`:
```bash
cp config.env.example config.env
nano config.env
```

### 3. 一键安装
```bash
chmod +x install.sh
./install.sh
```

## 📂 目录结构 (Structure)
- `scripts/`: 管理脚本 (环境安装、配置生成、部署)。
- `docs/`: 详细设计文档与架构说明。
- `config.env`: 用户配置文件。
- `install.sh`: 入口脚本。

## 📖 文档 (Documentation)
更多详细信息请参考 `docs/` 目录：
- [需求池 (Requirements)](docs/REQUIREMENTS_POOL.md)
- [架构设计 (Architecture)](docs/DESIGN_ARCHITECTURE.md)
- [交接手册 (Handover Manual)](docs/HANDOVER_MANUAL.md)

## 🛠️ 常用命令 (Commands)
- **查看状态**: `systemctl --user status remote-proxy`
- **查看日志**: `journalctl --user -u remote-proxy -f`
- **重启服务**: `systemctl --user restart remote-proxy`
- **停止服务**: `systemctl --user stop remote-proxy`

## ⚖️ License
MIT
