# 交接手册 (Handover Manual)

## 先看哪里

交接优先顺序：

1. [README](../README.md)
2. [总体设计](plans/2026-03-30-remote-proxy-reliability-design.md)
3. [Standalone VPS deployment](deploy/standalone-vps.md)
4. [Infra-core / Ubuntu.online integration](deploy/infra-core-ubuntu-online.md)
5. [Known host baselines](ops/host-baselines.md)
6. [Troubleshooting](ops/troubleshooting.md)

## 当前操作原则

- standalone 路径使用 `config.env`。
- `install.sh` / `scripts/*.sh` 只面向 standalone VPS 自动化。
- `infra-core` 相关主机不要直接套用 standalone 安装流程。
- 真实密码、私钥、分享链接不进入 Git 仓库。

## 常见维护命令

Root:

```bash
systemctl status remote-proxy
journalctl -u remote-proxy -f
systemctl cat remote-proxy
```

Rootless:

```bash
systemctl --user status remote-proxy
journalctl --user -u remote-proxy -f
systemctl --user cat remote-proxy
```

## 配置变更后

```bash
python3 scripts/gen_config.py
./scripts/deploy.sh
./scripts/verify.sh
```

如果改动涉及密钥或客户端导入信息，再运行：

```bash
./scripts/show_info.sh
```
