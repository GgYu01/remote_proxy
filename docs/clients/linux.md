# Linux 客户端指南

## 先判断你是哪条接入路径

### 路径 A：单台 VPS 独立部署

这时你可以继续使用单节点 VLESS Reality、SOCKS5 或 HTTP 入口。

### 路径 B：已发布订阅的受管环境

如果你的环境已经发布统一订阅，那么 Linux 客户端应优先直接导入订阅，而不是手工抄单节点参数。

当前这份文档后面的命令示例，主要是路径 A 的基线调试方法。

## 常见接入方式

- `Hiddify` Desktop
- `v2rayN` Linux 版本
- `sing-box` CLI 或 systemd 服务
- 应用级 SOCKS5 / HTTP 代理设置
- 面向浏览器优先场景的桌面网络代理设置

## 推荐路径

路径 A 下，只要客户端栈支持，优先使用 VLESS + Reality。

如果只是临时调试，或只想给轻量 CLI 工具走代理，也可以继续使用 SOCKS5 / HTTP。

如果是路径 B，请先看你的订阅发布文档，再决定是否还需要保留这些手工代理环境变量。

如果运维侧已经发布了“单节点锁定订阅”，优先直接导入那条单节点订阅；这样你不需要在客户端里额外切换默认节点。

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
