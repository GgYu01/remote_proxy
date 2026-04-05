# CLIProxyAPIPlus 独立 VPS 部署指南

## 适用范围

以下情况使用本指南：

- 目标主机是全新或近乎全新的 Debian / Ubuntu VPS；
- 你希望使用 Podman + systemd 部署 `CLIProxyAPIPlus`；
- 你希望通过仓库内脚本完成安装、验证、升级与版本切换。

## 配置文件

主配置文件：

- `config/cliproxy-plus.env`

初始化方式：

```bash
mkdir -p config
cp config/cliproxy-plus.env.example config/cliproxy-plus.env
nano config/cliproxy-plus.env
```

至少应人工确认以下字段：

- `CLIPROXY_IMAGE`
- `CLIPROXY_PORT`
- `CLIPROXY_MEMORY_LIMIT`
- `CLIPROXY_MANAGEMENT_KEY`
- `CLIPROXY_API_KEY`
- `CLIPROXY_USAGE_STATISTICS_ENABLED`

## 安装

```bash
chmod +x install.sh scripts/*.sh scripts/service.sh scripts/services/cliproxy_plus/*.sh
./install.sh cliproxy-plus
```

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
```

## 更新

```bash
./scripts/service.sh cliproxy-plus update
```

## 切换版本

```bash
./scripts/service.sh cliproxy-plus switch-version docker.io/eceasy/cli-proxy-api-plus:v6.9.15-0
```

## usage 持久化说明

`CLIProxyAPIPlus` 的 usage 默认是内存态，本仓库通过生命周期脚本补齐正式持久化流程：

1. 更新前导出 usage 到 `state/cliproxy-plus/usage/latest.json`
2. 重建服务
3. 更新后导回 usage
4. 再执行验证

因此，镜像升级或版本切换不会静默丢失 usage 统计。
