# 需求池 (Requirements Pool)

## 原始需求 (Original Requirements)
- [ ] **多协议支持**：支持 5 种主流代理协议 (SOCKS5, HTTP, Shadowsocks, VMess, Trojan)。
- [ ] **容器化部署**：使用 Podman (原生 Quadlet 优先)。
- [ ] **资源优化**：内存占用最小化 (High Memory Efficiency)。
- [ ] **配置即代码**：使用脚本/配置管理，避免手动操作。
- [ ] **双语隔离**：文档中文，代码/提交英文。
- [ ] **无安全性限制**：Debug 模式开启，敏感信息直接存库。

## 用户故事 (User Stories)
- 作为用户，我希望通过一个命令完成部署，无需手动编辑复杂 JSON。
- 作为用户，我希望系统自动重启（Systemd 集成），并在崩溃时恢复。
- 作为全栈工程师，我希望看到清晰的架构图和决策日志。

## 状态标记
- `[P0]` 必须完成
- `[P1]` 期望完成
- `[P2]` 可选
