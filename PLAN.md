# 项目执行计划 (Project Execution Plan)

## 0. 核心目标
在远端 VPS 上使用 **Podman (Quadlet)** 部署一个 **高内存效率** 的多协议代理服务，支持 SOCKS5, HTTP, Shadowsocks, VMess, Trojan。

## 1. 技术选型 (Technology Stack)
- **Core Engine**: `Sing-box`
  - *理由*: 相比 Xray-core 和 Clash，Sing-box 在内存占用上通常更优（空闲时 <30MB），且原生支持全协议栈，配置结构统一。
- **Container Runtime**: `Podman` (Rootless)
- **Orchestration**: `Quadlet` (.container files)
  - *理由*: Systemd 原生集成，比 Docker Compose 更轻量，无守护进程开销。
- **Configuration**: Python/Shell 脚本生成器
  - *理由*: 避免维护巨大的静态 JSON，支持动态生成 UUID/密码。

## 2. 详细执行阶段 (Detailed Execution Phases)

### Phase 1: 基础架构与环境准备 (Infrastructure & Environment)
- [ ] **配置定义**: 创建 `.env.example`，包含 `SWAP_SIZE`, `PODMAN_VERSION`, `PROXY_PORTS`, `USER_UUID` 等关键参数。
- [ ] **环境初始化脚本 `scripts/setup_env.sh`**:
  - 检测 Linux 发行版。
  - 自动更新系统软件包。
  - 安装/更新 `podman`, `curl`, `jq`, `python3`。
  - **Swap 管理**: 整合 `manage_swap.sh`，根据配置自动挂载 Swap 防止 OOM。
- [ ] **目录清理**: 确保脚本具有执行权限，清理无用文件。

### Phase 2: 配置生成系统 (Configuration System)
- [ ] **开发 `scripts/gen_config.py`**:
  - 读取 `.env` 文件。
  - 生成 `sing-box.json` 配置文件。
  - 包含 5 个 Inbound:
    1. `socks` (SOCKS5)
    2. `http` (HTTP Proxy)
    3. `shadowsocks` (AEAD ciphers)
    4. `vmess` (VMess + WS)
    5. `trojan` (Trojan)
  - **Hard-mode Debug**: 默认开启 debug 日志，输出到标准输出。

### Phase 3: Podman Quadlet 集成 (Podman Quadlet Integration)
- [ ] **编写 `system/proxy.container` (Template)**:
  - 使用 `ghcr.io/sagernet/sing-box:latest` 镜像。
  - 挂载生成的 `sing-box.json`。
  - 动态替换端口配置。
  - 配置资源限制 (MemoryLimit=128M)。
- [ ] **编写 `scripts/deploy.sh`**:
  - 渲染 `.container` 文件。
  - 自动链接到 `~/.config/containers/systemd/`。
  - 执行 `systemctl --user daemon-reload`。

### Phase 4: 一键整合与验证 (Integration & Verification)
- [x] **编写 `install.sh`**:
  - 串联 `setup_env.sh` -> `gen_config.py` -> `deploy.sh`。
  - 提供友好的交互式/非交互式输出。
- [ ] **编写 `scripts/verify.sh`**:
  - 使用 `curl` 通过 5 种协议分别访问外部 IP (如 ipinfo.io)。
  - 验证失败时自动重试 10 次。
- [x] **完善文档**:
  - 更新 `README.md` 为“一键部署”风格。
  - 补全 `docs/` 下的所有文档。

### Phase 5: 严格审计 (Strict Audit) [NEW]
- [ ] **编写 `scripts/audit_project.py`**:
  - **完整性检查**: 确保所有 `scripts/` 下的文件都存在且可执行。
  - **语法检查**: 对 Shell 脚本执行 `bash -n`，对 Python 脚本执行 `python -m py_compile`。
  - **文档同步检查**: 检查 `docs/` 文件数量是否符合预期。
  - **配置检查**: 验证 `singbox.json` (如果存在) 或生成的 JSON 结构是否合法。

## 3. 防“偷懒”检查点 (Anti-Lazy Checkpoints)
必须通过 `python3 scripts/audit_project.py` 返回 Exit Code 0 才能标记任务结束。

## 4. 风险预案 (Risk Management)

为了防止 AI 任务过早结束，必须满足以下条件才能标记为 DONE：
1. **配置文件生成**：必须实际生成了包含 5 种协议的完整 JSON，不能是“示例代码”。
2. **Systemd 集成**：必须能够通过 `systemctl --user status` 看到服务运行。
3. **真实连接测试**：必须有一个脚本实际测试了代理连通性，而不仅仅是检查进程存在。
4. **文档同步**：代码变动后，`docs/` 目录下的修改时间必须更新。

## 4. 风险预案 (Risk Management)
- **Podman 版本过低**: 如果 VPS Podman 不支持 Quadlet (<4.4)，回退到 `podman play kube` (Pod YAML)。
- **内存溢出**: 如果 128M 不够，逐步增加至 256M，并在 `DECISION_LOG.md` 记录。

---
*Created by Sisyphus Agent - 2026-02-02*
