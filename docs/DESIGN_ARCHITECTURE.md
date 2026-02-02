# 系统架构与设计 (Design & Architecture)

## 核心理念 (Core Philosophy)
- **Unified Core (统一核心)**: 使用 Sing-box 或 Xray 单一进程处理多协议，极大降低内存开销。
- **Native Podman (原生 Podman)**: 使用 Quadlet (.container files) 利用 Systemd 管理容器，移除 Docker Daemon 开销。
- **Configuration as Code**: 所有配置通过模板生成，确保可复现性。

## 架构图 (Architecture Diagram)
*(待补充 Mermaid 图表)*

## 脚本架构 (Script Architecture)

### 1. 配置层 (Configuration Layer)
- **`.env`**: 唯一的配置入口。
  - 定义端口 (PORT_START)
  - 定义 UUID/密码 (User credentials)
  - 定义 Swap 大小 (SWAP_SIZE)
  - 定义版本号 (SINGBOX_VERSION)

### 2. 执行层 (Execution Layer)
- **`install.sh` (Master Script)**: 一键入口，按顺序调用子脚本。
  - ├── `scripts/setup_env.sh`: 环境准备
  - │   ├── 系统更新 (apt/yum update)
  - │   ├── 工具安装 (podman, curl, jq)
  - │   └── Swap 配置 (调用 manage_swap.sh)
  - ├── `scripts/gen_config.py`: 配置生成
  - │   └── 读取 .env -> 渲染 config_templates -> 生成 sing-box.json
  - └── `scripts/deploy_service.sh`: 服务部署
      └── 注册 Systemd Quadlet -> 启动服务

## 数据流向 (Data Flow)
User Client -> [Protocol Port] -> Podman Container -> Sing-box Inbound -> Outbound (Direct) -> Internet

## 设计模式
- **Template Pattern**: 配置生成脚本使用模板模式。
- **Sidecar (Optional)**: 如果需要额外日志收集 (暂不启用以省资源)。
