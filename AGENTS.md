# AGENTS.md

`remote_proxy` 是远端代理部署基线仓库，重点维护单机 VPS 自动化部署路径和公开文档，不承载私有库存、订阅发布脚本或主机密钥。

## Scope
- 本仓库负责 `standalone-vps` 自动化脚本、公开部署文档、客户端接入说明和本地测试。
- 与特定主机绑定的 secrets、inventory、订阅发布逻辑、线上热修状态，不应直接提交到本仓库。
- 修改线上主机前，先把可复现的修复落回本仓库并通过本地验证。

## Commands
```bash
python3 -m unittest -v
python3 scripts/audit_project.py
bash tests/simulate_install.sh
python3 scripts/gen_config.py
./scripts/verify.sh
```

## Conventions
- 文档使用简体中文，命令、路径、环境变量保持原样。
- Shell 脚本使用 `set -euo pipefail`。
- Python 兼容性以 Debian 12 / Ubuntu 22.04 常见系统 Python 为下限，不要依赖只在较新 Python 可用的文件写入 API。
- 任何会影响开机自启、systemd/Quadlet 生成、密钥轮换或客户端导入信息的改动，都必须同步更新相关文档与测试。

## Delivery Rules
- 修复脚本行为时，先让测试或仿真失败，再修复到变绿。
- 不要把 Lisahost 或其他线上主机的临时状态当成源码真相；以仓库内可复现、可验证的实现为准。
- 推送前至少运行单元测试、严格审计和安装仿真三类验证。
