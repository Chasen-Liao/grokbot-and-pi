# 安全防护机制与放行流程 (Security & Guard)

GAP (Grokbot And Pi) 架构面向 AI Agent 自动化调度，其中 Pi 具备在宿主环境中执行 Shell 命令的能力。为了避免 LLM 偶发幻觉导致极其严重的系统性破坏，系统内置了轻量级防护扩展 `pi-guard`。

---

## 1. pi-guard 的防护范围与设计原则

`pi-guard` 的设计原则是**只防灾难性删除或抹盘，范围极窄，不加其他繁复规则**：

- **拦截的高危操作**：
  1. `rm` 带有递归参数（`-r`、`-R` 或 `--recursive`），且删除目标为系统关键目录、工作区、上级目录或通配符，包括：`/`、`/*`、`~`、`~/`、`$HOME`、`${HOME}`、`/home`、`/root`、`/etc`、`/usr`、`/var`、`/boot`、`/opt`、`/bin`、`/lib`、`/workspace`、`..`、`*`（无论是否带 `--no-preserve-root`）。
  2. `find` 从根目录或用户主目录出发（`/`、`~`、`$HOME` 等）并带有 `-delete` 参数。
  3. 磁盘格式化命令 `mkfs`（如 `mkfs.ext4`）。
  4. 底层块设备覆写 `dd` 写入目标为设备文件（`of=/dev/...`）。
- **完全放行的常规操作**：
  - 项目日常构建产物与依赖删除（如 `rm -rf ./build`、`rm -rf node_modules`、`rm -rf dist`、`rm file.txt`、`rm -f /tmp/test.txt` 等）一律放行。
  - 常规非破坏性命令（`ls`、`cat`、`git status`、`find . -name "*.log" -delete` 等）一律放行。

---

## 2. 审批与放行流程 (Approval Workflow)

当 Pi 尝试执行被 `pi-guard` 识别为灾难性的操作时，系统不会直接将任务宣告失败，而是进入闭环审批流程：

```
[Pi 尝试执行危险命令]
       │
       ▼
[pi-guard 拦截] ──写入──> $PI_TASK_DIR_CURRENT/approvals.jsonl
       │                 (生成短随机 req ID，通知 Pi 先跳过继续做别的)
       ▼
[pi-task 实时感知] ─────> Webhook 触发 (state: "needs_approval", req, command)
       │
       ▼
[宿主 Bot 醒来] ────────> 将命令原样展示给用户并询问放行意见
       │                 (⚠️ 铁律：Bot 绝不自行审批)
       ├─────────────────────────────────┐
       ▼ [用户同意]                       ▼ [用户拒绝]
~/tools/pi-call/pi-task approve <ID> <req>   ~/tools/pi-call/pi-task deny <ID> <req>
       │                                         │
 写入 approved.json 并续跑 Pi               告知 Pi 该操作被拒，换不删除的做法或跳过
 (命令完全一致即予放行)
```

1. **拦截并记录**：
   `pi-guard` 拦截命令，在当前任务目录下向 `approvals.jsonl` 追加一条记录 `{req, command, reason, ts}`。返回给 Pi 的 reason 明确说明：「已请求用户放行（req=<id>），先跳过这一步继续做别的，不要换个写法绕过」。
2. **Webhook 唤醒**：
   `pi-task` 在后台监控到新的审批请求后，立刻向宿主 Bot 发送一次 Webhook 通知，通知 payload 包含：
   ```json
   {
     "source": "pi-task",
     "id": "<TASK_ID>",
     "owner": "<BOT_ID>",
     "state": "needs_approval",
     "exit_code": null,
     "req": "<REQ_ID>",
     "command": "<DANGEROUS_COMMAND>"
   }
   ```
   **注意**：此时任务本身并不结束，仍在继续执行其他无需放行的工作，直到整轮结束。
3. **用户裁决**：
   Bot 收到 `needs_approval` 后，**必须把命令原样发给用户**，询问用户是否授权放行。**Bot 自身永远不得擅自放行！**
4. **执行 approve 或 deny**：
   - 若用户确认同意：Bot 运行 `pi-task approve <ID> <req> [--owner <id>]`。该命令将目标命令原样写入本任务的 `approved.json` 白名单中，并给 Pi 发送放行提示续跑。当 Pi 再次执行该完全一致的命令时，`pi-guard` 查白名单直接放行。
   - 若用户拒绝：Bot 运行 `pi-task deny <ID> <req> [--owner <id>]`，通知 Pi 该操作被拒绝，促使 Pi 寻找替代方案或跳过。

---

## 3. 防护边界与局限性说明

### 防君子不防小人
`pi-guard` 是一个位于 Pi 工具层（`tool_call` 事件）的轻量级拦截器：
- 它的定位是**防止 LLM 在自主编写命令时出现严重失误或通配符误写（如 `rm -rf /` 或手滑删了整个 `/workspace`）**。
- **它无法防御有意的恶意绕过**：例如，如果任务或者恶意代码通过写入 Python/Node/Shell 脚本并随后执行该脚本来递归删除，或者通过 Base64 编码间接执行 Shell，`pi-guard` 无法从 AST 层面深挖间接执行的删除。

### 强隔离需求：使用 Sandbox 扩展
如果业务场景需要抵御恶意代码执行或实现强宿主隔离，单靠命令过滤是不够的。推荐使用 Pi 官方的沙盒扩展方案（参见 Pi 官方仓库中的 `examples/extensions/sandbox`）：
- 通过 Docker 容器、轻量虚拟机（如 MicroVM / Firecracker）或 Bubblewrap / nsjail 等 Linux 命名空间技术，将 Pi 及其执行的所有命令完全限制在隔离沙盒内；
- 沙盒内即便执行抹盘也仅破坏临时容器实例，无法影响宿主系统与主工作区。
