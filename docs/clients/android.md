# Android 客户端指南

## 推荐客户端

- `sing-box` Android
- 如果你只需要导入 VLESS / Trojan / Shadowsocks，也可以用 `v2rayNG`

## 推荐导入路径

在当前仓库基线下，优先使用 VLESS + Reality。

部署完成后，在 VPS 上执行 `./scripts/show_info.sh`，获取生成出的分享链接。

## Android 使用检查清单

1. 导入 VLESS Reality 分享链接。
2. 确认服务器地址是 VPS 公网 IP。
3. 确认端口是 `BASE_PORT + 3`。
4. 确认链接中带有 `pbk`、`sid` 和 `sni`。
5. 如需整机代理，再按需要开启 route 模式。

## 验证方式

- 用该配置打开浏览器。
- 确认出口 IP 已变成 VPS IP。
- 确认目标站点访问正常，且没有 TLS 证书警告。

## 安全提示

- 如果怀疑分享链接泄露，优先轮换 UUID。
- Reality 密钥只应在你准备同步更新所有客户端时再轮换。
