# Linux 客户端指南

## 常见接入方式

- `sing-box` CLI 或 systemd 服务
- 应用级 SOCKS5 / HTTP 代理设置
- 面向浏览器优先场景的桌面网络代理设置

## 推荐路径

只要客户端栈支持，优先使用 VLESS + Reality。

如果只是临时调试，或只想给轻量 CLI 工具走代理，也可以继续使用 SOCKS5 / HTTP。

## Linux CLI 示例

通过 SOCKS5 让浏览器或命令行工具走代理：

```bash
export ALL_PROXY="socks5://USER:PASS@SERVER_IP:BASE_PORT"
curl https://icanhazip.com
```

通过 HTTP 让浏览器或命令行工具走代理：

```bash
export HTTP_PROXY="http://USER:PASS@SERVER_IP:BASE_PORT_PLUS_1"
export HTTPS_PROXY="$HTTP_PROXY"
curl https://icanhazip.com
```

请将示例中的占位值替换为真实服务器参数，但不要把线上凭据写进可提交的 shell 配置文件。
