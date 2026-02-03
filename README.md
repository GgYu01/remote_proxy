# Remote Proxy Deployment (Podman Quadlet)

这是一个基于 **Podman Quadlet** 和 **Sing-box** 的轻量级、多协议代理部署方案。

## ✨ 特性 (Features)
- **多协议支持**: VLESS+Reality (推荐), Trojan, Shadowsocks, HTTP/SOCKS5。
- **内存优化**: 占用极低 (<50MB)，自动配置 Swap 防止内存溢出。
- **非 Host 模式**: 使用 Podman Bridge 网络 + 端口映射，隔离性更好。
- **新手友好**: 全自动化脚本，无需懂 Linux 命令。

## 🚀 新手快速开始 (Beginner's Guide)

### 第一步：准备服务器
你需要一台 Linux 服务器 (推荐 Debian 11/12 或 Ubuntu 20.04+)。

### 第二步：下载代码
在服务器终端输入以下命令：
```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
```

### 第三步：修改密码 (可选)
如果不修改，默认密码是 `password`，端口从 `10000` 开始。
要修改，请运行：
```bash
cp config.env.example config.env
nano config.env
# 修改完成后按 Ctrl+O 保存，Ctrl+X 退出
```

### 第四步：一键安装
```bash
chmod +x install.sh
./install.sh
```
脚本会自动完成：系统更新、安装 Podman、配置 Swap、生成证书、启动服务。

### 第五步：验证
安装完成后，脚本会提示你如何查看状态。你也可以运行：
```bash
./scripts/verify.sh
```

## 📂 脚本说明 (Scripts)
- `install.sh`: **主入口**。小白只需运行这一个。
- `scripts/setup_env.sh`: **环境初始化**。自动安装 Podman、uidmap 等依赖，并配置 Swap。
- `scripts/manage_swap.sh`: **Swap 管理**。智能检测内存，自动创建/挂载 Swap 文件。
- `scripts/gen_config.py`: **配置生成**。读取 `config.env` 生成 Sing-box 配置文件。
- `scripts/deploy.sh`: **服务部署**。生成 Systemd 服务文件并启动。

## 📖 进阶文档
- [详细架构设计](docs/DESIGN_ARCHITECTURE.md)
- [维护手册](docs/HANDOVER_MANUAL.md)
- [协议选择指南](docs/KNOWLEDGE_BASE.md)

## ⚖️ License
MIT
