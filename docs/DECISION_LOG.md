# 决策与灵感日志 (Decision & Inspiration Log)

## 决策记录

### [D-001] 核心引擎选择
- **选项**: Sing-box vs Xray vs Gost vs Multiple Containers
- **决策**: Sing-box
- **原因**: 经过分析，Sing-box 提供最佳的内存效率（Go 1.20+ 优化），且单一二进制原生支持所有所需协议（SOCKS5, HTTP, SS, VMess, Trojan），非常适合资源受限的 VPS 环境。
- **妥协**: 暂无明显妥协，功能完全覆盖。

### [D-002] 容器编排方式
- **选项**: Docker Compose vs Podman Kube Play vs Podman Quadlet
- **决策**: Podman Quadlet
- **原因**: User 要求 "Podman 原生且省内存"。Quadlet 是 Systemd 生成器，无额外守护进程开销，是最原生的方式。

## 灵光一闪 (Insights)
- *暂无*

## 脏代码记录 (Dirty Code Log)
- *暂无*
