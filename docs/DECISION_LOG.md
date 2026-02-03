# 决策与灵感日志 (Decision & Inspiration Log)

## 决策记录

### [D-001] 核心引擎选择
- **选项**: Sing-box vs Xray vs Gost vs Multiple Containers
- **决策**: Sing-box
- **原因**: 经过分析，Sing-box 提供最佳的内存效率（Go 1.20+ 优化），且单一二进制原生支持所有所需协议（SOCKS5, HTTP, SS, VMess, Trojan），非常适合资源受限的 VPS 环境。
- **妥协**: 暂无明显妥协，功能完全覆盖。

### [D-002] 协议栈升级 (Protocol Stack Upgrade)
- **变更**: 引入 VLESS，保留 Trojan/Shadowsocks，移除/降级 VMess。
- **原因**: 
  - **Stealth (隐匿性)**: 配置 `stack: system` 使用宿主机网络栈，避免 User-space 网络栈指纹被目标网站识别。
  - **Efficiency (流量/内存)**: VLESS 协议无额外加密开销（依赖底层 TLS/传输层），比 VMess 更省流量和 CPU。
  - **Stability (稳定性)**: Trojan 模拟 HTTPS 流量，穿越防火墙能力强且稳定。
- **最终组合**:
  1. **VLESS** (主力，极致精简)
  2. **Trojan** (伪装，高稳定性)
  3. **Shadowsocks** (兼容，备用)
  4. **HTTP/SOCKS5** (本地/调试用)

### [D-003] 隐匿性终极策略 (Ultimate Stealth Strategy)
- **协议层**: VLESS + Reality (Inbound)
  - *Rationale*: 消除 SNI 暴露，抵抗主动探测。
- **传输层**: System Stack (Outbound)
  - *Rationale*: 避免 User-space TCP 协议栈指纹。
- **网络层**: IPv4 Preferred
  - *Rationale*: 规避 IPv6 Datacenter 标记。

## 脏代码记录 (Dirty Code Log)
- *暂无*
