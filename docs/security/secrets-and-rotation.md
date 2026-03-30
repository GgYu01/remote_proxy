# 密钥与轮换

## 密钥类型

独立 VPS 基线当前使用以下可变密钥：

- `PROXY_PASS`
- `SS_PASSWORD`
- `VLESS_UUID`
- `REALITY_PRIVATE_KEY`
- `REALITY_PUBLIC_KEY`
- `REALITY_SHORT_ID`

## 公开仓库规则

- 公开文档可以解释这些字段的用途。
- 公开文档可以展示占位值。
- 公开文档不能包含任何真实主机正在使用的值。

## 轮换规则

### 低扰动轮换

优先轮换：

- `PROXY_PASS`
- `SS_PASSWORD`

它们会影响 HTTP / SOCKS / Shadowsocks / Trojan 的鉴权路径。

### 中扰动轮换

轮换：

- `VLESS_UUID`

所有使用 VLESS 的客户端都需要同步更新。

### 高扰动轮换

轮换：

- Reality 密钥对

一旦轮换，所有 Reality 客户端都必须重新更新配置。

## 标准轮换步骤

1. 修改 `config.env`；
2. 重新生成 `singbox.json`；
3. 重新部署服务；
4. 重新执行验证；
5. 更新客户端配置；
6. 撤销并删除所有旧的分享链接或导出配置。
