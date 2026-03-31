# Infra-Core / Ubuntu.online 集成指南

## 适用范围

当目标主机已经运行 `/mnt/hdo/infra-core` 这套 Docker Compose 体系时，使用本指南。

这是一条“集成路径”，不是 `install.sh` 的直接执行目标。

## 当前已观察到的布局

在当前 `Ubuntu.online` 主机上，和代理相关的现有内容包括：

- `/mnt/hdo/infra-core/services/proxied/vless-sidecar/docker-compose.yml`
- `/mnt/hdo/infra-core/services/proxied/vless-sidecar/README.md`
- `/mnt/hdo/infra-core/docs/PROXY_GUIDE.md`
- 一个正在运行的容器 `infra_vless_sidecar`

这说明该主机已经有一套基于 compose 的代理拓扑。

## 推荐集成策略

1. 让 `remote_proxy` 继续作为代理设计、密钥规则与客户端说明的事实来源。
2. 让 `infra-core` 继续拥有 compose 编排、共享网络和 sidecar 生命周期。
3. 只把与 sing-box 配置模型直接相关的内容移植到 sidecar 路径。
4. 不要用独立 VPS 的 Podman 安装器覆盖 `infra-core` 现有服务定义。

## 集成检查清单

1. 检查 `services/proxied/vless-sidecar/docker-compose.yml`。
2. 检查 `services/proxied/vless-sidecar/README.md`。
3. 对比它的镜像标签、挂载配置和暴露端口，与本仓库 standalone 基线是否一致。
4. 对齐密钥字段命名以及面向客户端的连接信息输出。
5. 在 standalone 基线稳定后，再回写 `infra-core` 侧文档。

## `infra-core` 侧应交付的内容

- 一份与 standalone sing-box 配置模型对齐的 compose 示例；
- 一份密钥映射说明；
- 一组只针对 Docker Compose 的重启与验证命令；
- 一份“当前已发布订阅如何被 Windows / Linux / Android 客户端直接导入”的现网接入说明。

## 客户端文档边界

这里要明确区分两层文档：

1. `remote_proxy/docs/clients/*`
   这组文档主要描述 standalone 基线和单节点接入思路。

2. 运维侧现网订阅文档
   如果 `infra-core` 已经额外发布统一订阅 URL、多节点池或导入捷径，那么这份现网文档应优先于 standalone 基线文档。

否则就会出现“公开仓库还在讲 `show_info.sh` 单节点链接，但现网已经改成订阅入口”的文档漂移。

## 明确禁止

- 不要在 `/mnt/hdo/infra-core` 中直接执行 `./install.sh`；
- 不要假设 compose 环境会具备 Podman Quadlet 的行为；
- 不要把 README 中的占位密钥或公开文档示例，混入 `infra-core` 的真实运行时密钥。
