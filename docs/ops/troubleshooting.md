# 故障排查

## 首轮检查

```bash
systemctl status remote-proxy
systemctl cat remote-proxy
journalctl -u remote-proxy -n 100 --no-pager
ss -tulpn | grep -E '1000[0-4]'
```

## 已知故障模式

### 一台主机能启动，另一台主机启动失败

重点比对：

- 固定镜像标签；
- 生成出的 unit 内容；
- 内存限制；
- 兼容性环境变量；
- 渲染后的 `singbox.json`。

### 端口没有监听

- 先确认服务确实处于 active；
- 再确认容器确实已启动；
- 查看 journal 是否有 sing-box 启动错误。

### HTTP / SOCKS 验证失败

- 运行 `./scripts/verify.sh`；
- 核对 `config.env` 中的凭据；
- 确认 VPS 具备正常的出站联网能力。

### sing-box 过时配置兼容报错

如果 journal 明确提示需要兼容性环境变量，确认生成出的服务定义包含：

- `ENABLE_DEPRECATED_LEGACY_DNS_SERVERS=true`
- `ENABLE_DEPRECATED_MISSING_DOMAIN_RESOLVER=true`
- `ENABLE_DEPRECATED_LEGACY_DOMAIN_STRATEGY_OPTIONS=true`

### HTTP 端口遭遇公网探测

如果在 HTTP 端口日志中看到匿名探测或异常 TLS 流量：

- 立即轮换凭据；
- 尽量缩小公网暴露面；
- 日常使用优先走 VLESS + Reality，而不是长期暴露 HTTP 调试入口。
