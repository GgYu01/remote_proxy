# 独立 VPS 部署指南

## 适用范围

以下情况使用本指南：

- 目标主机是全新或近乎全新的 Debian / Ubuntu VPS；
- 你希望由 `remote_proxy` 完整接管代理运行时；
- 目标主机接受使用 Podman + systemd。

## 部署前检查

1. 确认主机系统为 Debian 12/13 或 Ubuntu 22.04/24.04。
2. 确认你拥有 root 权限，或可执行 sudo 的运维账号。
3. 确认是否继续使用默认端口 `10000-10004`。
4. 确认本次是生成新的 UUID / Reality 密钥对，还是迁移既有配置。

## 配置文件与密钥

- 将 `config.env.example` 复制为 `config.env`。
- 以下字段必须填写或至少人工确认：
  - `PROXY_USER`
  - `PROXY_PASS`
  - `SS_PASSWORD`
  - `BASE_PORT`
  - `SING_BOX_IMAGE`
  - `ENABLE_DEPRECATED_SING_BOX_FLAGS`
  - `MEMORY_LIMIT`
- 以下字段只有在你希望脚本自动生成时才留空：
  - `VLESS_UUID`
  - `REALITY_PRIVATE_KEY`
  - `REALITY_PUBLIC_KEY`
  - `REALITY_SHORT_ID`

## 安装流程

```bash
git clone https://github.com/GgYu01/remote_proxy.git
cd remote_proxy
cp config.env.example config.env
nano config.env
chmod +x install.sh scripts/*.sh
./install.sh
```

`install.sh` 会依次执行：

1. 安装系统依赖并准备 swap；
2. 生成或校正受管密钥；
3. 生成 `singbox.json`；
4. 生成 Quadlet，必要时回退到后备 systemd 服务定义；
5. 执行本地验证并输出客户端连接信息。

## 验证

执行：

```bash
./scripts/verify.sh
```

应看到以下信号：

- `BASE_PORT` 到 `BASE_PORT + 4` 的端口已监听；
- SOCKS5 与 HTTP 的本地验证通过；
- 服务状态为 active；
- 验证输出中不会打印明文凭据。

## 服务检查

root 部署：

```bash
systemctl status remote-proxy
journalctl -u remote-proxy -f
systemctl cat remote-proxy
```

rootless 部署：

```bash
systemctl --user status remote-proxy
journalctl --user -u remote-proxy -f
systemctl --user cat remote-proxy
```

## 升级规则

1. 先备份 `config.env` 与当前渲染出的服务定义。
2. 升级仓库代码。
3. 有意识地检查 `SING_BOX_IMAGE`，不要误漂到 `latest`。
4. 重新执行：

```bash
python3 scripts/gen_config.py
./scripts/deploy.sh
./scripts/verify.sh
```

## 回滚规则

如果升级后运行异常：

1. 恢复旧版 `config.env`；
2. 恢复旧版镜像标签；
3. 重新执行部署；
4. 重新执行验证；
5. 确认服务定义与已知正常基线一致。

## 防火墙与公网暴露

- 能限制入站暴露就尽量限制。
- 只要 HTTP 或 SOCKS 端口暴露到公网，就默认会遭受探测。
- 占位凭据绝不能直接上线。
- 如果日志里出现异常探测，应立即轮换凭据。
