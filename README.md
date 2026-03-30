# Remote Proxy 部署基线

`remote_proxy` 是当前维护中的远端代理部署基线，用于两类场景：

- 在 Linux VPS 上独立部署个人远端代理；
- 为现有 `infra-core` 环境补充同等能力的接入说明与运维规范。

这份 README 是总入口。后续如果旧文档与这里冲突，以这里链接出去的文档为准。

## 本仓库支持的拓扑

本仓库明确支持两种不同的部署拓扑：

1. `standalone-vps`
   适用于全新或近乎全新的 Debian / Ubuntu VPS，由本仓库完整接管代理部署。

2. `infra-core-sidecar`
   适用于代理运行在现有 `/mnt/hdo/infra-core` Docker Compose 环境中的场景，例如 `Ubuntu.online`。

这两种模式不能混用理解。仓库内脚本自动化的是 `standalone-vps` 路径；`infra-core` 路径是集成说明，不是直接执行 `install.sh` 的目标。

## 安全规则

- `config.env` 是独立 VPS 路径的主配置文件，不再把 `.env` 作为独立部署主配置。
- `config.env.example` 中的值全部只是占位示例；只要端口会暴露到公网，就必须先修改凭据。
- 真实密码、私钥、在线分享链接、客户端导入链接都不能提交到 Git。
- 除非你在明确测试升级，否则应固定 sing-box 镜像版本，不要默默漂到 `latest`。

## 快速开始

### 独立 VPS 部署

```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
cp config.env.example config.env
nano config.env
chmod +x install.sh scripts/*.sh
./install.sh
./scripts/verify.sh
./scripts/show_info.sh
```

权威部署说明：

- [独立 VPS 部署指南](docs/deploy/standalone-vps.md)

### 已有 `infra-core` 主机

对于 `Ubuntu.online` 以及类似主机，不要在 `/mnt/hdo/infra-core` 内直接盲跑 `install.sh`。这类主机应按 sidecar / compose 集成方式处理：

- [Infra-core / Ubuntu.online 集成指南](docs/deploy/infra-core-ubuntu-online.md)

## 客户端接入

- [Android 客户端指南](docs/clients/android.md)
- [Windows 客户端指南](docs/clients/windows.md)
- [Linux 客户端指南](docs/clients/linux.md)

## 密钥、轮换与恢复

- [密钥与轮换指南](docs/security/secrets-and-rotation.md)

## 运维

- [故障排查指南](docs/ops/troubleshooting.md)
- [已知主机基线](docs/ops/host-baselines.md)

## 脚本概览

- `install.sh`：独立 VPS 路径的统一入口。
- `scripts/setup_env.sh`：安装系统依赖并准备 swap。
- `scripts/gen_keys.sh`：为 `config.env` 执行幂等的受管密钥生成。
- `scripts/gen_config.py`：根据 `config.env` 渲染 `singbox.json`。
- `scripts/deploy.sh`：生成 Quadlet 与后备 systemd 服务定义。
- `scripts/verify.sh`：验证监听端口和本地代理连通性，并避免打印原始凭据。
- `scripts/show_info.sh`：根据当前配置输出客户端连接信息。

## 当前运行模型

默认生成配置会在 `BASE_PORT` 到 `BASE_PORT + 4` 上暴露以下入站：

- SOCKS5
- HTTP
- Shadowsocks
- VLESS + Reality
- Trojan

## 文档现状

当前文档体系已经按以下原则归一：

- 独立部署唯一主配置文件是 `config.env`；
- 独立 VPS 只有一条受支持的自动化部署路径；
- `infra-core` 只有一条受支持的集成说明路径；
- Android / Windows / Linux 都有单独的客户端接入说明。

如果历史文档与这些规则冲突，请以本 README 链接的文档为准。
