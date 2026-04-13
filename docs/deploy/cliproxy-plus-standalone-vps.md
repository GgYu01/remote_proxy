# CLIProxyAPIPlus 独立 VPS 部署指南

## 适用范围

以下情况使用本指南：

- 目标主机是全新或近乎全新的 Debian / Ubuntu VPS；
- 你希望使用 Podman + systemd 部署 `CLIProxyAPIPlus`；
- 你希望通过仓库内脚本完成安装、验证、升级与版本切换。

## 运行时兼容层

`cliproxy-plus` 的安装、部署、版本切换都会先执行运行时兼容检查：

- 默认模式：`REMOTE_PROXY_RUNTIME_POLICY=hybrid`
- Python 下限：`>= 3.9`
- 兼容层会优先复用主机上已经存在的兼容解释器，例如 `python3.10`、`python3.11`；
- 如果当前发行版原生仓库能稳定提供版本化 Python 包，脚本会自动补装并切换到该解释器；
- 如果主机过旧且当前仓库源无法提供兼容版本，脚本会阻断，而不是去动系统默认 `/usr/bin/python3`。

对旧平台的人工兜底方式：

```bash
export REMOTE_PROXY_PYTHON_BIN=/usr/bin/python3.10
./install.sh cliproxy-plus
```

如果没有可验证的新解释器，应先升级宿主机基线，再继续部署。

## 配置文件

主配置文件：

- `config/cliproxy-plus.env`

初始化方式：

```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
```

至少应人工确认以下字段：

- `CLIPROXY_IMAGE`
- `CLIPROXY_PORT`
- `CLIPROXY_MEMORY_LIMIT`
- `CLIPROXY_MANAGEMENT_KEY`
- `CLIPROXY_MANAGEMENT_ALLOW_REMOTE`
- `CLIPROXY_API_KEY`
- `CLIPROXY_USAGE_STATISTICS_ENABLED`

## 安装

```bash
chmod +x install.sh scripts/*.sh scripts/service.sh scripts/services/cliproxy_plus/*.sh
./install.sh cliproxy-plus
```

这条安装路径会自动执行：

1. 基础依赖安装；
2. 运行时兼容检查与 Python 解释器选择；
3. 生成 `config.yaml`；
4. 部署 Podman/systemd 服务；
5. 管理面验证。

## 验证

```bash
./scripts/service.sh cliproxy-plus verify
```

也可以直接检查服务状态：

```bash
systemctl status cliproxy-plus
journalctl -u cliproxy-plus -f
podman ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'
```

## 端口

- `8317/tcp`
  默认主 HTTP API 端口。
- `8316/tcp`
  默认不对外暴露，仅在启用 pprof 时本地监听。

## 本地调用示例

```bash
source config/cliproxy-plus.env
curl -H "Authorization: Bearer ${CLIPROXY_API_KEY}" \
  http://127.0.0.1:${CLIPROXY_PORT}/v1/models

curl -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
  http://127.0.0.1:${CLIPROXY_PORT}/v0/management/usage

curl -H "Authorization: Bearer ${CLIPROXY_MANAGEMENT_KEY}" \
  http://<server-ip>:${CLIPROXY_PORT}/v0/management/usage
```

## 更新

```bash
./scripts/service.sh cliproxy-plus update
```

## 切换版本

```bash
./scripts/service.sh cliproxy-plus switch-version docker.io/eceasy/cli-proxy-api-plus:v6.9.15-0
```

如果脚本阻断并提示 Python 版本过低，请优先检查：

1. 当前宿主机是否已有 `python3.9+` 或 `python3.10+`；
2. 是否已正确导出 `REMOTE_PROXY_PYTHON_BIN`；
3. 当前系统仓库是否能提供兼容版本包；
4. 这台主机是否已经落到需要先升级 OS 的旧基线。

## usage 持久化说明

`CLIProxyAPIPlus` 的 usage 默认是内存态，本仓库通过生命周期脚本补齐正式持久化流程：

1. 更新前导出 usage 到 `state/cliproxy-plus/usage/latest.json`
2. 重建服务
3. 更新后导回 usage
4. 再执行验证

因此，镜像升级或版本切换不会静默丢失 usage 统计。
