# 系统架构与设计 (Design & Architecture)

## 核心理念 (Core Philosophy)
- **Unified Core (统一核心)**: 使用 Sing-box 或 Xray 单一进程处理多协议，极大降低内存开销。
- **Native Podman (原生 Podman)**: 使用 Quadlet (.container files) 利用 Systemd 管理容器，移除 Docker Daemon 开销。
- **Configuration as Code**: 所有配置通过模板生成，确保可复现性。

## 架构图 (Architecture Diagram)
*(待补充 Mermaid 图表)*

## 数据流向 (Data Flow)
User Client -> [Protocol Port] -> Podman Container -> Sing-box Inbound -> Outbound (Direct) -> Internet

## 设计模式
- **Template Pattern**: 配置生成脚本使用模板模式。
- **Sidecar (Optional)**: 如果需要额外日志收集 (暂不启用以省资源)。
