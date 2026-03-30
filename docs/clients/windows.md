# Windows 客户端指南

## 推荐客户端

- `sing-box for Windows`
- 只有在你明确维护一份转换配置时，才建议使用兼容 `Clash Meta` 的客户端

## 推荐路径

优先使用生成出的 VLESS + Reality 链接。

## Windows 使用检查清单

1. 从 `./scripts/show_info.sh` 输出中导入 VLESS 链接。
2. 确认服务器地址指向 VPS 公网 IP。
3. 确认 `sni`、`pbk`、`sid` 与渲染后的配置一致。
4. 按需求决定只给浏览器走代理，还是启用系统级隧道模式。

## 回退路径

- SOCKS5：`BASE_PORT`
- HTTP：`BASE_PORT + 1`

这两个入口只建议用于调试，或者客户端本身不支持 Reality 的场景。

## 验证方式

- 检查浏览器的出口 IP。
- 如果你还要覆盖开发工具，再选一个 CLI 工具通过代理验证一次。
