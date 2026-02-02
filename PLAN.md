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

### Phase 1: 基础架构与清理 (Infrastructure & Cleanup)
- [ ] **清理旧环境**: 移除 Docker 相关残留（如果有），确保 Podman 环境纯净。
- [ ] **目录结构重构**:
  ```text
  .
  ├── config_templates/    # 配置模板 (Jinja2 or envsubst)
  ├── scripts/             # 管理脚本
  ├── system/              # Systemd/Quadlet 单元文件
  ├── docs/                # 文档
  └── .env.example         # 环境变量示例
  ```
- [ ] **依赖检查**: 编写脚本检查 `podman`, `systemd-container` 等依赖。

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
- [ ] **编写 `system/proxy.container`**:
  - 使用 `ghcr.io/sagernet/sing-box:latest` 镜像。
  - 挂载生成的 `sing-box.json`。
  - 暴露端口 (默认 10000-10004)。
  - 配置资源限制 (MemoryLimit=128M)。
- [ ] **编写 `scripts/deploy.sh`**:
  - 自动链接 `.container` 文件到 `~/.config/containers/systemd/`。
  - 执行 `systemctl --user daemon-reload`。

### Phase 4: 验证与文档 (Verification & Documentation)
- [ ] **编写验证脚本 `scripts/verify.sh`**:
  - 使用 `curl` 通过 5 种协议分别访问外部 IP (如 ipinfo.io)。
  - 验证失败时自动重试 10 次。
- [ ] **完善文档**:
  - 更新 `README.md`。
  - 补全 `docs/` 下的所有文档。

## 3. 防“偷懒”检查点 (Anti-Lazy Checkpoints)
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
