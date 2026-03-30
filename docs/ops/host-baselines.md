# 已知主机基线

## 快照日期

2026-03-30

## dedirock

- 系统：Debian 13
- 服务：`remote-proxy.service` 处于 active
- 运行方式：后备 systemd 服务拉起 Podman
- 实际内存限制：`256M`
- 过时配置兼容变量：已存在
- 验证结果：SOCKS5 + HTTP 本地验证通过
- 状态：当前最适合作为参考基线的主机

## akilecloud

- 系统：Debian 13
- 服务：`remote-proxy.service` 处于 active
- 运行方式：后备 systemd 服务拉起 Podman
- 观察到的实际内存限制：生成 unit 中仍是 `8M`
- 过时配置兼容变量：观察到的 unit 中缺失
- Git 状态：detached，且已偏离当前仓库基线
- 验证结果：本地验证能过，但不应再把它当作黄金基线
- 状态：高优先级对齐目标

## Ubuntu.online

- 系统：Ubuntu 24.04
- 部署模型：现有 `/mnt/hdo/infra-core` compose 体系
- 已观察到的代理容器：`infra_vless_sidecar`
- 状态：应通过 `infra-core` 文档集成，不应直接使用 standalone Podman 安装器
