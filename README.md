# Remote Proxy 部署基线

`remote_proxy` 是当前维护中的远端服务部署基线，用于两类场景：

- 在 Linux VPS 上独立部署 `sing-box` 或 `CLIProxyAPIPlus`；
- 为现有 `infra-core` 环境补充同等能力的接入说明与运维规范。

这份 README 是总入口。后续如果旧文档与这里冲突，以这里链接出去的文档为准。

## 当前支持的服务

本仓库当前在 `standalone-vps` 路径下支持两个独立服务：

1. `singbox`
   继续提供 SOCKS5 / HTTP / Shadowsocks / VLESS Reality / Trojan 入站。

2. `cliproxy-plus`
   部署 `CLIProxyAPIPlus` HTTP API 服务，运行时服务名为 `cliproxy-plus`。

## 本仓库支持的拓扑

本仓库明确支持两种不同的部署拓扑：

1. `standalone-vps`
   适用于全新或近乎全新的 Debian / Ubuntu VPS，由本仓库完整接管代理部署。

2. `infra-core-sidecar`
   适用于代理运行在现有 `/mnt/hdo/infra-core` Docker Compose 环境中的场景，例如 `Ubuntu.online`。

这两种模式不能混用理解。仓库内脚本自动化的是 `standalone-vps` 路径；`infra-core` 路径是集成说明，不是直接执行 `install.sh` 的目标。

## 安全规则

- `config.env` 是独立 VPS 路径的主配置文件，不再把 `.env` 作为独立部署主配置。
- `config/cliproxy-plus.env` 是 `CLIProxyAPIPlus` 的主配置文件。
- `config.env.example` 中的值全部只是占位示例；只要端口会暴露到公网，就必须先修改凭据。
- `config/cliproxy-plus.env` 与 `config/cliproxy-plus.env.example` 当前都直接提交明文默认值，管理密钥与 API key 默认都是 `gaoyx123`。
- 真实密码、私钥、在线分享链接、客户端导入链接都不能提交到 Git。
- 除非你在明确测试升级，否则应固定 sing-box 镜像版本，不要默默漂到 `latest`。

## 快速开始

### 独立 VPS 部署 `singbox`

```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
cp config.env.example config.env
nano config.env
chmod +x install.sh scripts/*.sh
./install.sh singbox
./scripts/verify.sh
./scripts/show_info.sh
```

权威部署说明：

- [独立 VPS 部署指南](docs/deploy/standalone-vps.md)
- [CLIProxyAPIPlus 独立 VPS 部署指南](docs/deploy/cliproxy-plus-standalone-vps.md)

### 独立 VPS 部署 `cliproxy-plus`

```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
chmod +x install.sh scripts/*.sh scripts/service.sh scripts/services/cliproxy_plus/*.sh
./install.sh cliproxy-plus
./scripts/service.sh cliproxy-plus verify
```

### 已有 `infra-core` 主机

对于 `Ubuntu.online` 以及类似主机，不要在 `/mnt/hdo/infra-core` 内直接盲跑 `install.sh`。这类主机应按 sidecar / compose 集成方式处理：

- [Infra-core / Ubuntu.online 集成指南](docs/deploy/infra-core-ubuntu-online.md)

## 客户端接入

先区分两种使用场景：

1. `standalone-vps`
   这时客户端连接信息来自目标 VPS 本机的 `./scripts/show_info.sh` 输出。

2. 已发布订阅的受管环境
   这时客户端应优先使用运维侧发布的订阅 URL 或导入链接，而不是再回到单节点 `show_info.sh` 思路。

如果你维护的是“多节点池 + 订阅发布”方案，那么订阅入口文档应比这里的单机基线说明优先。

- [Android 客户端指南](docs/clients/android.md)
- [Windows 客户端指南](docs/clients/windows.md)
- [Linux 客户端指南](docs/clients/linux.md)

## 密钥、轮换与恢复

- [密钥与轮换指南](docs/security/secrets-and-rotation.md)

## 运维

- [故障排查指南](docs/ops/troubleshooting.md)
- [已知主机基线](docs/ops/host-baselines.md)

### 查看当前 Podman / systemd 服务

```bash
systemctl list-units --type=service | grep -E 'remote-proxy|cliproxy-plus'
systemctl status remote-proxy
systemctl status cliproxy-plus
podman ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
podman ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
```

## 脚本概览

- `install.sh`：独立 VPS 路径的统一入口，支持 `singbox` 与 `cliproxy-plus`。
- `scripts/service.sh`：`cliproxy-plus` 生命周期入口，支持 `install` / `verify` / `update` / `switch-version`。
- `scripts/setup_env.sh`：安装系统依赖并准备 swap。
- `scripts/gen_keys.sh`：为 `config.env` 执行幂等的受管密钥生成。
- `scripts/gen_config.py`：根据 `config.env` 渲染 `singbox.json`。
- `scripts/deploy.sh`：生成 Quadlet 与后备 systemd 服务定义。
- `scripts/verify.sh`：验证监听端口和本地代理连通性，并避免打印原始凭据。
- `scripts/show_info.sh`：根据当前配置输出客户端连接信息。
- `scripts/services/cliproxy_plus/gen_config.py`：生成 `CLIProxyAPIPlus` 的 `config.yaml`。
- `scripts/services/cliproxy_plus/deploy.sh`：部署 `cliproxy-plus` Podman/systemd 服务。
- `scripts/services/cliproxy_plus/usage_backup.sh`：升级前导出 usage。
- `scripts/services/cliproxy_plus/usage_restore.sh`：升级后导回 usage。
- `scripts/services/cliproxy_plus/verify.sh`：验证 `cliproxy-plus` 管理面可用。

## 当前运行模型

默认生成配置会在 `BASE_PORT` 到 `BASE_PORT + 4` 上暴露以下入站：

- SOCKS5
- HTTP
- Shadowsocks
- VLESS + Reality
- Trojan

### `CLIProxyAPIPlus` 默认端口作用

- `cliproxy-plus` 默认使用 Podman `host network`，这样宿主机上的本地管理脚本仍然会被服务识别为 localhost。
- `8317/tcp`
  主 HTTP API 端口。用于本地或受控网络内访问：
  - OpenAI-compatible API
  - `/v0/management/*` 管理接口
- `8316/tcp`
  仅在显式启用 `CLIPROXY_PPROF_ENABLE=true` 时本地监听，不作为默认对外端口。

## 本地调用示例

### 查询模型列表

```bash
source config/cliproxy-plus.env
curl -H "Authorization: Bearer ${CLIPROXY_API_KEY}" \
  http://127.0.0.1:${CLIPROXY_PORT}/v1/models
```

### 查询 usage 统计

```bash
source config/cliproxy-plus.env
curl -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
  http://127.0.0.1:${CLIPROXY_PORT}/v0/management/usage
```

### 导出 usage 统计

```bash
source config/cliproxy-plus.env
curl -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
  http://127.0.0.1:${CLIPROXY_PORT}/v0/management/usage/export
```

## 升级与版本切换

更新当前配置中指定的镜像版本：

```bash
./scripts/service.sh cliproxy-plus update
```

切换到指定版本标签：

```bash
./scripts/service.sh cliproxy-plus switch-version docker.io/eceasy/cli-proxy-api-plus:v6.9.15-0
```

`update` 和 `switch-version` 都会执行以下流程：

1. 先导出 usage 到宿主机 `state/cliproxy-plus/usage/latest.json`
2. 重建 `cliproxy-plus` 服务
3. 导回 usage
4. 执行本地管理面验证

## 文档现状

当前文档体系已经按以下原则归一：

- 独立部署唯一主配置文件是 `config.env`；
- `CLIProxyAPIPlus` 的主配置文件是 `config/cliproxy-plus.env`，并且仓库当前直接提交了明文默认凭据；
- 独立 VPS 只有一条受支持的自动化部署路径；
- `infra-core` 只有一条受支持的集成说明路径；
- Android / Windows / Linux 都有单独的客户端接入说明。

如果历史文档与这些规则冲突，请以本 README 链接的文档为准。
