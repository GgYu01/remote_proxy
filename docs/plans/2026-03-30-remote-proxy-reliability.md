# Remote Proxy 可靠性实施计划

> **给 Claude 的执行说明：** 该计划要求按任务粒度逐项落地，而不是只作为交接文档保存。

**目标：** 把 `remote_proxy` 建成一个可靠的部署基线，既支持独立 VPS 的正式上线，也支持 `infra-core` sidecar 集成，并配套长期可维护文档与更安全的运维行为。

**架构原则：** 保持单仓库，但明确拆分受支持的部署拓扑。脚本只对 standalone VPS 负责，`infra-core` 只作为集成路径记录。高风险脚本修改前，先补对应测试。

**技术栈：** Bash、Python 3、sing-box、Podman、systemd、Markdown 文档。

---

### 任务 1：建立设计与文档骨架

**文件：**
- 新建：`docs/plans/2026-03-30-remote-proxy-reliability-design.md`
- 新建：`docs/plans/2026-03-30-remote-proxy-reliability.md`
- 新建：`docs/deploy/standalone-vps.md`
- 新建：`docs/deploy/infra-core-ubuntu-online.md`
- 新建：`docs/clients/android.md`
- 新建：`docs/clients/windows.md`
- 新建：`docs/clients/linux.md`
- 新建：`docs/security/secrets-and-rotation.md`
- 新建：`docs/ops/troubleshooting.md`
- 新建：`docs/ops/host-baselines.md`
- 修改：`README.md`

**步骤 1：先写会失败的文档一致性测试**

新增测试，断言 README 已引用新的文档路径，并且不再把 `.env` 当作主配置文件，也不再提及过期命令名。

**步骤 2：执行测试并确认先失败**

执行：`python -m unittest tests.test_docs_consistency -v`

预期：失败，因为旧文档仍引用过期命令或缺失新文件。

**步骤 3：按已批准的拓扑拆分更新文档**

写入新文档，并把 README 改造成稳定入口。

**步骤 4：重新执行测试**

执行：`python -m unittest tests.test_docs_consistency -v`

预期：PASS。

### 任务 2：让受管密钥/配置更新具备幂等性

**文件：**
- 修改：`scripts/gen_keys.sh`
- 新增：`tests/test_gen_keys.py`

**步骤 1：先写会失败的测试**

新增测试，在临时工作区中以 mocked `podman` 输出运行 `scripts/gen_keys.sh`，并断言：

- 重复执行不会重复写入 `VLESS_UUID`；
- `REALITY_PRIVATE_KEY`、`REALITY_PUBLIC_KEY`、`REALITY_SHORT_ID` 会以确定性方式更新或保持；
- 最终 `config.env` 中每个受管键只有一个生效赋值。

**步骤 2：执行测试并确认先失败**

执行：`python -m unittest tests.test_gen_keys -v`

预期：失败，因为旧逻辑会追加重复键。

**步骤 3：实现最小但正确的幂等更新逻辑**

重构 `scripts/gen_keys.sh`，改为原位更新受管字段，而不是盲目追加。

**步骤 4：重新执行测试**

执行：`python -m unittest tests.test_gen_keys -v`

预期：PASS。

### 任务 3：从验证输出中去除敏感数据

**文件：**
- 修改：`scripts/verify.sh`
- 新增：`tests/test_verify_script.py`

**步骤 1：先写会失败的测试**

新增测试，在受控临时环境中以 mocked `curl`、`ss` 和配置值运行 `scripts/verify.sh`，断言输出中不包含原始用户名密码。

**步骤 2：执行测试并确认先失败**

执行：`python -m unittest tests.test_verify_script -v`

预期：失败，因为旧输出会包含 `user:password@`。

**步骤 3：实现最小脱敏改造**

保留功能性验证，但输出改为脱敏后的 endpoint 标签，而不是带凭据的完整代理 URL。

**步骤 4：重新执行测试**

执行：`python -m unittest tests.test_verify_script -v`

预期：PASS。

### 任务 4：加固部署配置面

**文件：**
- 修改：`config.env.example`
- 修改：`scripts/deploy.sh`
- 新增：`tests/test_deploy_script.py`

**步骤 1：先写会失败的测试**

新增测试，断言生成出的服务定义：

- 会尊重固定镜像变量；
- 会应用合理的最小内存下限；
- 在启用时会包含文档已说明的兼容性环境变量。

**步骤 2：执行测试并确认先失败**

执行：`python -m unittest tests.test_deploy_script -v`

预期：失败，因为旧脚本硬编码 `latest`，也缺少配置驱动的兼容参数处理。

**步骤 3：实现最小必要的部署加固**

更新配置面与部署生成逻辑。

**步骤 4：重新执行测试**

执行：`python -m unittest tests.test_deploy_script -v`

预期：PASS。

### 任务 5：刷新本地验证入口

**文件：**
- 修改：`tests/simulate_install.sh`
- 修改：`scripts/audit_project.py`

**步骤 1：补齐会失败的检查路径**

新增测试或断言，证明文档树与脚本检查已经对齐到新的结构。

**步骤 2：执行检查并确认先失败**

执行：`python scripts/audit_project.py`

预期：如果文件引用或结构仍然陈旧，则失败。

**步骤 3：更新验证辅助脚本**

让 audit / simulation 辅助脚本与新文档树、新脚本行为保持一致。

**步骤 4：重新执行**

执行：`python scripts/audit_project.py`

预期：PASS。

### 任务 6：全量验证

**文件：**
- 仅验证，不改文件

**步骤 1：执行聚焦单元测试**

执行：

```bash
python -m unittest tests.test_docs_consistency tests.test_gen_keys tests.test_verify_script tests.test_deploy_script -v
```

预期：全部通过。

**步骤 2：执行项目审计**

执行：

```bash
python scripts/audit_project.py
```

预期：PASS。

**步骤 3：执行模拟安装**

执行：

```bash
"C:/Program Files/Git/bin/bash.exe" tests/simulate_install.sh
```

预期：PASS。

**步骤 4：汇总主机后续工作**

把 `dedirock`、`akilecloud` 和 `Ubuntu.online` 的后续对齐动作补齐进文档。

## 执行说明

用户已经批准设计，并要求在当前会话中直接执行，因此这份计划是本轮工作的执行清单，不只是交接材料。
