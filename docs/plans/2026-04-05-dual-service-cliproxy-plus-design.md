# Remote Proxy 双服务与 CLIProxyAPIPlus 集成设计

## 背景

`remote_proxy` 当前是一个围绕 `sing-box` 独立 VPS 部署建立起来的仓库基线：

- 主机准备、配置生成、Podman 部署、systemd 生命周期与本地验证都已围绕 `sing-box` 成形；
- 文档、测试与脚本默认假设“仓库只负责一个代理服务”；
- 新目标要求在同一仓库内新增第二类服务：`CLIProxyAPIPlus`，并保持一键部署、低内存占用、可升级、可切版本、可持久化。

远端目标主机 `vmrack` 当前是空白 Debian 12：

- 未安装 `podman`；
- 未安装 `docker`；
- 不存在既有 `/root/remote_proxy`；
- 可用内存有限，适合延续“Podman + systemd，无常驻 Compose 守护”的路线。

这意味着本次不是给现有脚本补一个临时分支，而是要把仓库升级成正式的“双服务部署基线”。

## 问题定义

我们要解决的不只是“把 `CLIProxyAPIPlus` 跑起来”，而是要在单仓库内同时满足下面几件事：

1. 保持现有 `sing-box` 部署路径继续可用，且不回归。
2. 新增 `CLIProxyAPIPlus` 的正式部署、验证、升级、版本切换与运维文档。
3. 在镜像更新和容器重建后，保留：
   - 认证文件；
   - 配置文件；
   - 日志；
   - 使用统计。
4. 把部署与运维操作标准化为仓库内脚本，不依赖手工散命令。
5. 让 README 能成为运维入口，明确：
   - 当前 Podman/systemd 存在哪些服务；
   - `CLIProxyAPIPlus` 各端口的作用；
   - 本地如何调用；
   - 如何更新版本与切换版本。

## 根因

### 根因 1：当前仓库是单服务模型

现有 `install.sh -> gen_config.py -> deploy.sh -> verify.sh` 的控制流只为 `sing-box` 设计。

直接在现有脚本中加入 `if SERVICE=cliproxy-plus` 这类分支，会把配置、部署、验证、文档和测试继续耦合到一个脚本泥团里，短期可跑，长期不可维护。

### 根因 2：`CLIProxyAPIPlus` 的持久化模型与 `sing-box` 不同

`sing-box` 基本是“生成静态配置，运行固定容器”的模型。

`CLIProxyAPIPlus` 则同时存在：

- `config.yaml`；
- `auth-dir` 下的认证 JSON；
- `logs`；
- 管理 API；
- 内存态 usage 统计；
- 通过管理 API 导出的 usage 备份/导入流程。

其中认证文件天然可持久化，usage 统计却默认不会自动落盘。这是“镜像更新后不丢统计”的真正根因。

### 根因 3：现有控制层没有“升级前状态导出 / 升级后状态恢复”机制

现有 `remote_proxy` 只处理部署与本地验证，不负责把运行时数据从旧容器迁出再迁入新容器。

对 `CLIProxyAPIPlus` 而言，如果没有这层机制，任何 `podman pull && podman replace` 都可能导致 usage 丢失。

## 目标

1. 把仓库升级为双服务正式基线：
   - `sing-box`
   - `cliproxy-plus`
2. 保持 Podman + systemd 为唯一正式自动化部署路径。
3. 为 `CLIProxyAPIPlus` 提供真正可用的状态持久化与版本切换机制。
4. 让所有高风险路径都有测试覆盖：
   - 服务文件渲染；
   - 配置生成；
   - usage 导出/导回；
   - 版本切换；
   - README 与部署文档一致性。
5. 以 `vmrack` 真机部署验证通过作为本批次闭环标准。

## 非目标

- 本批次不引入 Docker Compose 作为正式运行时。
- 本批次不把 `CLIProxyAPIPlus` 的 TLS 打开为默认路径。
- 本批次不试图把 usage 统计改造到上游源码内部持久化；我们在仓库控制层提供正式持久化闭环。
- 本批次不改变 `sing-box` 默认对外端口模型。

## 总体架构

### 1. 仓库职责升级为“远端服务基线”

仓库不再等价于“只部署 sing-box”，而是成为两个独立服务的统一控制面：

- 公共层：
  - 主机准备；
  - Podman/systemd 适配；
  - 公共日志与错误处理；
  - 远端脚本入口；
  - README 与部署文档；
  - 审计与测试。
- 服务层：
  - `sing-box`
  - `cliproxy-plus`

### 2. 服务之间独立，控制层共享

推荐目录形态：

- `scripts/lib/`
- `scripts/services/singbox/`
- `scripts/services/cliproxy_plus/`
- `config/`
- `state/`

其中：

- 公共库只处理通用行为；
- 服务目录只处理本服务逻辑；
- 运行时状态统一落在宿主机 `state/`；
- 任何镜像替换都不得把状态写回容器内部。

## 配置设计

### 1. 分离服务配置

避免一个巨型 `config.env` 同时承载两种服务的全部字段。

建议新增：

- `config/singbox.env`
- `config/cliproxy-plus.env`

`sing-box` 保留现有配置语义，但迁移到明确的服务级 env 文件。

`cliproxy-plus` 新增以下关键配置：

- `CLIPROXY_IMAGE`
- `CLIPROXY_PORT`
- `CLIPROXY_MEMORY_LIMIT`
- `CLIPROXY_MANAGEMENT_KEY`
- `CLIPROXY_USAGE_AUTOBACKUP`
- `CLIPROXY_USAGE_BACKUP_PATH`
- `CLIPROXY_PPROF_ENABLE`
- `CLIPROXY_PPROF_ADDR`

### 2. 运行时状态目录

`CLIProxyAPIPlus` 宿主机持久化状态固定为：

- `state/cliproxy-plus/config.yaml`
- `state/cliproxy-plus/auths/`
- `state/cliproxy-plus/logs/`
- `state/cliproxy-plus/usage/latest.json`

作用：

- `config.yaml`：服务配置真源；
- `auths/`：OAuth 与认证文件；
- `logs/`：应用日志；
- `usage/latest.json`：升级前导出的 usage 快照。

## `CLIProxyAPIPlus` 服务设计

### 1. 协议与暴露面

默认部署为 HTTP，不启用 HTTPS：

- `tls.enable: false`
- `host: ''`
- `port: 8317` 或配置指定端口

原因：

- 用户明确要求 HTTP 而不是 HTTPS；
- 该服务本质是内网或受控接入的 API 入口；
- TLS 不应成为本仓库阻塞点，若未来需要公网 TLS，应交由上层反代或边界服务。

### 2. 管理面

管理 API 必须存在，并且当前仓库默认以“公网可访问 + 独立密钥”为准。

建议策略：

- `remote-management.allow-remote: true`
- 所有导出/导入与运维动作仍优先通过宿主机本地 `curl http://127.0.0.1:<port>` 调用
- 管理密钥通过 `Authorization: Bearer <key>` 发送
- 不开放 `pprof` 到公网

### 3. 端口定义

README 和部署文档必须明确说明端口角色：

- 业务 API 端口：
  - `8317/tcp`
  - 用于 OpenAI-compatible / 管理 API / 本地维护入口
- 调试端口：
  - 默认禁用 `pprof`
  - 若启用，默认本地绑定 `127.0.0.1:8316`
- 其余上游示例 compose 中出现的额外端口，不作为本仓库默认暴露项，只有在验证出强依赖后才纳入。

### 4. 本地调用说明

README 必须给出最小可执行示例，包括：

- `curl` 调用 `/v1/models`
- `curl` 调用 OpenAI chat/completions 或 responses 接口
- `curl` 通过管理 API 获取 usage
- `curl` 导出 usage

## 持久化与升级设计

### 1. 认证与日志持久化

通过 Podman volume/bind mount 保证：

- 配置不丢；
- 认证文件不丢；
- 日志不丢。

### 2. usage 统计正式解

由于 usage 默认只在内存里，必须由仓库控制层做显式导出/导回。

正式流程：

1. 升级或重建前：
   - 调用本地管理 API：
     - `GET /v0/management/usage/export`
   - 写入 `state/cliproxy-plus/usage/latest.json`
2. 新容器启动并通过健康检查后：
   - 若 usage 文件存在，则：
     - `POST /v0/management/usage/import`
   - 导回成功后记录日志
3. 若导出失败：
   - 默认阻断升级
   - 除非显式指定 `--skip-usage-backup`

### 3. 版本切换

提供正式命令：

- `./scripts/service.sh cliproxy-plus install`
- `./scripts/service.sh cliproxy-plus verify`
- `./scripts/service.sh cliproxy-plus update`
- `./scripts/service.sh cliproxy-plus switch-version <tag>`

其中：

- `update`：拉取当前 env 中定义的镜像 tag 并重建
- `switch-version`：修改目标 image tag，执行导出、重建、导回与验证

### 4. 回滚

版本切换失败时：

1. 恢复旧镜像 tag；
2. 重建旧容器；
3. 再次导回最近 usage 快照；
4. 重新执行 `verify`。

## systemd / Podman 设计

### 1. 服务名固定

- `remote-proxy.service`：`sing-box`
- `cliproxy-plus.service`：`CLIProxyAPIPlus`

### 2. 运行方式

优先 Quadlet，生成失败时回退到标准 systemd service。

### 3. README 运维说明

README 必须说明如何查看当前系统已安装/正在运行的 Podman 服务，例如：

- `systemctl list-units --type=service | grep -E 'remote-proxy|cliproxy-plus'`
- `systemctl status remote-proxy`
- `systemctl status cliproxy-plus`
- `podman ps --format '{{.Names}}\t{{.Image}}\t{{.Status}}'`
- `podman ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}'`

## 测试策略

采用风险驱动的 L0-L4 五层验证：

- `L0`：静态文档与配置生成检查
- `L1`：单元测试
- `L2`：脚本级集成测试（mocked podman/systemctl/curl）
- `L3`：本地开发机模拟安装与版本切换
- `L4`：`vmrack` 真机部署与升级验证

本批次新增重点测试：

1. `CLIProxyAPIPlus` 配置生成测试
2. `cliproxy-plus` 服务文件渲染测试
3. usage 导出/导入脚本测试
4. 版本切换脚本测试
5. README 与部署文档一致性测试
6. 不回归现有 `sing-box` 测试

## 文档要求

README 至少新增四块内容：

1. 双服务支持矩阵
2. Podman/systemd 当前服务检查命令
3. `CLIProxyAPIPlus` 端口说明
4. 本地调用示例、升级命令、版本切换命令

并新增单独部署文档，明确：

- 主机准备
- 安装命令
- 验证命令
- 升级/切版本
- usage 备份与恢复行为

## 验收标准

只有同时满足以下条件，本批次才算通过：

1. `sing-box` 现有测试与行为不回归。
2. `CLIProxyAPIPlus` 具备一键部署路径。
3. Podman/systemd 服务能在 `vmrack` 上成功启动。
4. README 已说明：
   - 查看当前 Podman/systemd 服务的命令；
   - `CLIProxyAPIPlus` 各端口作用；
   - 本地如何调用；
   - 如何更新与切换版本。
5. `CLIProxyAPIPlus` 验证脚本在 `vmrack` 上通过。
6. 至少完成一次真实版本切换并证明：
   - 认证目录仍在；
   - usage 已成功导出并导回；
   - 新版本服务可访问。

## 推进顺序

1. 先补设计与计划文档。
2. 先写失败测试，不先写生产代码。
3. 重构控制层为双服务模型。
4. 实现 `cliproxy-plus` 配置、部署、验证、升级、切版本。
5. 更新 README 与部署文档。
6. 本地跑测试。
7. 上 `vmrack` 真机部署。
8. 做真实升级/切版本验证。
