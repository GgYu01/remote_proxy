# Remote Proxy 可靠性设计

## 背景

`remote_proxy` 当前处在一个中间态：

- 仓库已经能在部分 VPS 上生成可运行的 sing-box 部署；
- 真实运行状态已经和仓库实现、仓库文档发生漂移；
- 用户还在 `Ubuntu.online` 上维护另一套独立的 `infra-core` 部署拓扑。

这意味着仓库还不能被当作“可重复多主机部署、可稳定交接、可用于故障响应”的可信基线。

## 问题定义

我们需要一个单一仓库，持续承担以下事实来源角色：

- 独立 VPS 个人远端代理部署；
- `infra-core` 风格 sidecar 部署的集成指南；
- Android / Windows / Linux 的客户端使用说明；
- 可预测的密钥管理、升级、回滚与验证流程。

## 目标

1. 让仓库成为可审阅、可复核的正式部署基线。
2. 明确拆分两种支持的拓扑：
   - `standalone-vps`：Podman + systemd/Quadlet 或后备服务。
   - `infra-core-sidecar`：Docker Compose / sidecar 风格集成指南。
3. 让密钥处理显式、安全、不可误提交。
4. 让部署行为足够幂等，能够反复复用到同类 VPS。
5. 让验证具备分层结构和可重复性，而不是“这台机器能起来就算完”。
6. 产出足够详细的文档，支持后续自助部署和维护。

## 非目标

- 本阶段不会无限扩展代理协议种类。
- 本阶段不会用全新编排器替换 `infra-core`。
- 本阶段不会把真实生产密钥存进 Git。

## 支持的拓扑

### 1. 独立 VPS

这是本仓库主要的可执行部署路径。

特征：

- 单台 Linux VPS；
- 运行时基于 Podman；
- 生命周期由 systemd 管理；
- 暴露 10000-10004 端口，承载 SOCKS5 / HTTP / SS / VLESS Reality / Trojan；
- 优化目标是全新 Debian / Ubuntu 主机上的可重复部署。

### 2. Infra-Core Sidecar

这是一条文档化的集成路径，不是对 `install.sh` 的直接复用。

特征：

- 目标主机已存在 `/mnt/hdo/infra-core` 目录树；
- 服务由 Docker Compose 驱动；
- 通过 sidecar 或 compose 片段承载 sing-box 容器；
- 文档必须说明如何接入现有基础设施，而不是假装 standalone 安装器可以直接接管主机。

## 已识别的根因

### 文档漂移

当前文档中的文件名、命令名和配置约定，已经与真实实现不一致。

### 配置可变性漂移

`config.env` 之前通过追加方式更新字段，导致重复键和值覆盖顺序依赖，给运维带来不确定性。

### 运行时漂移

不同主机上实际运行的是明显不同的 unit、不同的内存限制和不同的兼容参数。

### 验证缺口

当前验证只能证明本地 SOCKS5 / HTTP 可用，而且曾经会把凭据直接打印到日志里。

### 运维边界漂移

仓库曾把 standalone VPS 与 `infra-core` 当成同一个部署问题处理，这会持续制造误用。

## 设计决策

### 决策 1：保留单仓库，但拆分部署叙事

仓库继续作为唯一归档点，但文档与结构必须清晰说明：

- 哪些是脚本自动化内容；
- 哪些是人工集成说明；
- 哪些只适用于 standalone；
- 哪些只适用于 `infra-core`。

### 决策 2：密钥可以说明，不能公开

公开仓库会记录：

- 密钥类型；
- 生成方式；
- 放置位置；
- 轮换与迁移流程。

公开仓库不会包含：

- 真实密码；
- 真实私钥；
- 带真实凭据的分享链接。

### 决策 3：运行时输入优先固定

只要会实质影响可靠性，部署路径就不应默默依赖 `latest` 这种不稳定行为。

这包括：

- sing-box 镜像引用；
- 必要时的兼容性环境变量；
- 显式的默认内存值与下限。

### 决策 4：验证必须分层

我们采用五层验证：

- `L0`：语法、文档一致性、生成产物等静态检查。
- `L1`：聚焦配置与脚本行为的单元/集成测试。
- `L2`：本地开发机上的 mocked 安装/部署路径检查。
- `L3`：三台已知环境的主机验收。
- `L4`：新 VPS 首次上线的 fresh-host 回归验证。

## 文档架构

文档体系整理为：

- 顶层 `README.md`：概览、拓扑拆分、快速开始、安全规则；
- `docs/deploy/standalone-vps.md`：独立 VPS 权威部署指南；
- `docs/deploy/infra-core-ubuntu-online.md`：`infra-core` 集成指南；
- `docs/clients/android.md`
- `docs/clients/windows.md`
- `docs/clients/linux.md`
- `docs/security/secrets-and-rotation.md`
- `docs/ops/troubleshooting.md`
- `docs/ops/host-baselines.md`

## 本执行批次的实现范围

第一批聚焦：

1. 重建文档基线；
2. 加固配置与密钥处理；
3. 加固 deploy 与 verify；
4. 为新行为补测试；
5. 结合当前三台已知主机，补齐运维侧说明。

## 验收标准

只有同时满足以下条件，本批次才算合格：

- 文档不再声明不受支持或已经过时的行为；
- 受管密钥对应的配置更新具备幂等性；
- 验证输出不再打印原始凭据；
- 部署路径已明确记录或支持兼容性环境变量；
- standalone 与 `infra-core` 指南清晰分离；
- 高风险行为已有测试覆盖，且测试已重新执行。

## 风险

- Windows 开发环境与 Linux 部署目标之间的 shell 行为差异；
- sing-box 版本漂移；
- 用户私有的 `infra-core` 本地约定没有完全出现在公开仓库中；
- 部分主机停留在旧版生成 unit 上，导致跨主机行为分叉。

## 推进顺序

1. 先修仓库基线。
2. 再同步文档与测试。
3. 然后把 `dedirock` 与 `akilecloud` 对齐到新基线。
4. 为 `Ubuntu.online` 补全 `infra-core` sidecar 文档。
5. 后续所有新 VPS 接入都以新版 README 为入口。
