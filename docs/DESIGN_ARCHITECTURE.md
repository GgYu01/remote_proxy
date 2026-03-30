# 系统架构与设计 (Design & Architecture)

当前有效架构以以下文档为准：

- [总体设计](plans/2026-03-30-remote-proxy-reliability-design.md)
- [Standalone VPS deployment](deploy/standalone-vps.md)
- [Infra-core / Ubuntu.online integration](deploy/infra-core-ubuntu-online.md)

## 核心理念

- `config.env` 是 standalone 路径的唯一主配置入口。
- `install.sh` 只负责 standalone VPS 自动化路径。
- `infra-core` 是单独的 sidecar / compose 集成路径，不与 standalone 安装脚本混用。
- 文档必须区分“脚本自动化边界”和“人工集成边界”。

## 运行时模型

客户端流量路径：

`Client -> VPS public port -> sing-box inbound -> direct outbound -> Internet`

## 受支持拓扑

1. `standalone-vps`
2. `infra-core-sidecar`

旧文档中提到的历史命名不再作为当前基线。
