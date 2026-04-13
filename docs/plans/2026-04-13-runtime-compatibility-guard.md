# Runtime Compatibility Guard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 `remote_proxy` 增加宿主机运行时依赖兼容层，稳定检测 Python 与关键命令依赖，在可安全修复时自动补齐/切换，在高风险场景下阻断并输出精确诊断。

**Architecture:** 新增共享的 `scripts/lib/runtime_compat.sh` 作为唯一运行时兼容层，负责宿主机识别、Python 解释器选择、包管理器能力探测和混合策略决策。`setup_env.sh` 负责“安装/修复 + 校验”，`install.sh`、`deploy.sh`、`scripts/services/cliproxy_plus/*.sh` 等入口只做只读 preflight，并统一通过共享层选择兼容的 Python 解释器，而不是强改系统默认 `python3`。

**Tech Stack:** Bash, Python 3.9+ compatibility discipline, unittest, mocked shell command tests

---

### Task 1: 固化失败测试与辅助执行器

**Files:**
- Modify: `tests/test_support.py`
- Create: `tests/test_runtime_compat.py`
- Test: `python3 -m unittest -v tests.test_runtime_compat`

**Step 1: Write the failing tests**

覆盖至少以下行为：
- 当默认 `python3` 版本过低但已有 `python3.10` / `python3.11` 可用时，兼容层能自动选择该解释器；
- 当宿主机默认 Python 过低、当前仓库源可提供版本化 Python 包时，`hybrid` 模式会自动安装并切到兼容解释器；
- 当宿主机是 Debian 10 / Ubuntu 20.04 这一类高风险旧基线且当前源没有兼容 Python 包时，脚本阻断并输出人工修复建议；
- 兼容层输出稳定的 `REMOTE_PROXY_PYTHON_BIN` 供后续 shell 入口复用。

**Step 2: Run tests to verify they fail**

Run: `python3 -m unittest -v tests.test_runtime_compat`
Expected: FAIL，提示缺少运行时兼容层或行为与预期不符。

**Step 3: Add/adjust helper execution support**

在 `tests/test_support.py` 中补充一个可执行任意 shell 片段的 helper，供 runtime 兼容层测试直接 `source` shell library 使用。

**Step 4: Re-run targeted tests**

Run: `python3 -m unittest -v tests.test_runtime_compat`
Expected: 仍然 FAIL，但失败点收敛到尚未实现的兼容层逻辑。

### Task 2: 实现共享 runtime compatibility 层

**Files:**
- Create: `scripts/lib/runtime_compat.sh`
- Modify: `scripts/lib/common.sh`
- Test: `python3 -m unittest -v tests.test_runtime_compat`

**Step 1: Write the minimal shell library**

实现以下职责：
- 识别宿主机发行版与版本：支持 `REMOTE_PROXY_OS_RELEASE_FILE` 注入，便于测试；
- 版本比较与 Python 候选解释器枚举；
- `hybrid / strict / auto` 策略决策；
- 仅从当前包管理器可见的仓库中探测并安装版本化 Python 包，不引入第三方源；
- 设置并输出 `REMOTE_PROXY_PYTHON_BIN`。

**Step 2: Run targeted tests**

Run: `python3 -m unittest -v tests.test_runtime_compat`
Expected: PASS

**Step 3: Refactor shared helpers**

把可复用的入口（例如日志输出、Python bin 选择、宿主机描述）保留在共享层，不要复制到多个入口脚本。

### Task 3: 接入 singbox / cliproxy-plus shell 入口

**Files:**
- Modify: `install.sh`
- Modify: `scripts/setup_env.sh`
- Modify: `scripts/deploy.sh`
- Modify: `scripts/gen_keys.sh`
- Modify: `scripts/show_info.sh`
- Modify: `scripts/services/cliproxy_plus/install.sh`
- Modify: `scripts/services/cliproxy_plus/deploy.sh`
- Modify: `scripts/services/cliproxy_plus/switch_version.sh`
- Test: `python3 -m unittest -v tests.test_setup_env tests.test_gen_keys tests.test_cliproxy_plus_deploy`

**Step 1: Write/extend failing tests**

需要补至少一条入口级测试，证明 shell 入口不再硬编码 `python3`，而是通过兼容层选择到版本化解释器。

**Step 2: Run targeted tests to verify they fail**

Run: `python3 -m unittest -v tests.test_setup_env tests.test_gen_keys tests.test_cliproxy_plus_deploy`
Expected: FAIL，暴露入口仍然硬编码 `python3` 或未执行 preflight。

**Step 3: Implement minimal integration**

- `setup_env.sh`：继续负责基础包安装，但在安装后执行 `ensure` 模式的 runtime preflight；
- `install.sh` 与各 `deploy/install/switch-version` 入口：在调用 Python 之前执行 `check` 模式 preflight；
- 所有 shell 入口用 `"$REMOTE_PROXY_PYTHON_BIN"` 替换硬编码 `python3`。

**Step 4: Re-run targeted tests**

Run: `python3 -m unittest -v tests.test_setup_env tests.test_gen_keys tests.test_cliproxy_plus_deploy tests.test_runtime_compat`
Expected: PASS

### Task 4: 补齐治理与文档

**Files:**
- Modify: `tests/test_governance.py`
- Modify: `docs/deploy/standalone-vps.md`
- Modify: `docs/deploy/cliproxy-plus-standalone-vps.md`
- Modify: `README.md`

**Step 1: Add governance coverage**

把 runtime compatibility library 纳入治理约束，至少保证：
- 不重新引入硬编码 `python3` shell 调用；
- 文档明确 mixed 模式边界和人工兜底方式。

**Step 2: Update docs in 简体中文**

文档需明确：
- 默认模式是 `REMOTE_PROXY_RUNTIME_POLICY=hybrid`
- 自动修复的边界：仅当前仓库源可见、且能稳定补装的版本化 Python 包
- 阻断场景：旧发行版默认 Python 过低且无兼容候选解释器
- 手工兜底方式：设置 `REMOTE_PROXY_PYTHON_BIN` 指向已验证解释器，或升级宿主机

### Task 5: 完整验证与交付

**Files:**
- Modify: `/workspaces/temp/tmp_remote_proxy_cliproxy_plus_2026-04-13/final_delivery_report.md`
- Modify: `/workspaces/temp/tmp_remote_proxy_cliproxy_plus_2026-04-13/progress.md`

**Step 1: Run full verification**

Run:

```bash
python3 -m unittest -v
python3 scripts/audit_project.py
bash tests/simulate_install.sh
python3 -m py_compile $(git ls-files '*.py')
git diff --check
```

Expected: 全部通过。

**Step 2: Update Chinese report**

把本轮新增的运行时兼容层设计、实现、验证边界和“无法做真机验证的剩余风险”写入临时交付报告。

**Step 3: Commit and push**

```bash
git add <updated files>
git commit -m "feat: add runtime compatibility guard"
git push origin master
```
