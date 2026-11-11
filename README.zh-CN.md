# GAP — Grokbot And Pi

[English](README.md) | 简体中文

让 Grok Bot 把繁重的代码编写、文件批量修改、长文档整理等执行活派给同机运行的 **Pi coding agent**（[pi.dev](https://pi.dev)）作为 subagent，把 Grok Bot 宝贵的额度集中在意图规划与结果验收上。

---

## 为什么需要 GAP？

- **节省 Grok Bot 昂贵额度**：平台对话配额昂贵，最适合用来做需求梳理、任务拆解与代码审查。将需要反复读文件、改代码、跑测试的多步执行活交给 Pi，消耗你自己配置的模型额度（官方 API Key、第三方中转站、Pi 默认自带额度，或私有部署的网关）。
- **同机执行，速度快且无跨网开销**：Pi 直接运行在 Grok Bot 所在的云端 Linux 电脑上，直接读写本地文件与执行 bash，省去跨机器同步文件的复杂性。
- **高韧性追踪与严格验收**：无人值守的 coding agent 可能遇到机器休眠、网络中断或幻觉。GAP 提供了持久化任务管理（`pi-task`）、睡醒断网预检重连、空闲超时熔断、防删库扩展（`pi-guard`）以及人工审批闭环机制。

---

## 架构与闭环工作流

![GAP Architecture](docs/architecture.png)

GAP 包含清晰的 4 步闭环：

```mermaid
flowchart TD
  B["Grok Bot"] -->|"pi-task run --owner <BOT_ID>"| T["pi-task（后台任务管理器）"]
  T -->|"RPC 会话"| P["Pi Coding Agent（同机运行）"]
  P -->|"文件 / Shell / 工具"| W["工作区与模型"]
  P -->|"事件流 / 状态"| T
  T -->|"持久化状态"| D["~/.pi/tasks/<ID>/"]
  B -->|"AwaitShell（本轮长时间等待）"| B
  T -.->|"完成通知 / needs_approval"| H["Webhook 例行任务（唤醒兜底）"]
  H -.->|"对话轮次结束时唤醒"| B
  B -->|"pi-task pending --owner <BOT_ID>"| C["读 result.md 亲自核验 diff 与测试"]
  C -->|"pi-task ack <ID> --owner <BOT_ID>"| R["向用户汇报真实证据并确认"]
```

1. **Bot 派活（`pi-task run`）**：Grok Bot 编写简明且边界明确的任务书，通过后台模式启动 `pi-task run <工作目录> '<任务书>' --session <会话名> --owner <BOT_ID> --notify-prefix <BOT>`。
2. **本轮长等待（防宿主机休眠冻结）**：Bot 派发后**不要结束当前轮次**。因为云端电脑在 Bot 空闲时容易睡眠或重启（导致后台 Pi 进程被冻住或杀掉），Bot 在本轮用一次长时间阻塞的等待（例如 `AwaitShell`，单次最长约 13 分钟）等 Pi 执行完毕。阻塞等待几乎不消耗 Bot 模型额度，同时能保持宿主机唤醒。
3. **Webhook 唤醒兜底**：若由于不可抗力对话轮次提前结束，任务执行完毕或需要用户审批（`needs_approval`）时，`pi-task` 会在后台向设定的 Webhook 地址发起 HTTP POST 通知（仅包含 `{source, id, owner, state, exit_code}`，不含任务正文与敏感密钥），唤醒 Bot 的例行任务。
4. **亲自核验与确认（Ack）**：Bot 检查 `~/.pi/tasks/<ID>/result.md`，亲自运行 git diff、产物检查或单元测试，将核验证据汇报给用户，验收合格后运行 `pi-task ack <ID> --owner <BOT_ID>` 确认完成。

> **磁盘是唯一事实来源**：所有任务状态、事件流与最终产物均持久化保存在 `~/.pi/tasks/<ID>/`。Webhook 仅用于降低唤醒延迟；若网络抖动丢包，Bot 唤醒后运行 `pi-task pending --owner <BOT_ID>` 即可完整查回所有未报告的任务。

---

## 快速开始

### 1. 发给 Grok Bot 自助配置（推荐）

只需把本仓库链接发给你的 Grok Bot，让它按 [AGENTS.md](AGENTS.md) 自动化配置：

```text
请阅读 https://github.com/Chasen-Liao/grokbot-and-pi 的 AGENTS.md，帮我把 GAP 配置好。
```

Bot 会依序检查 Node.js（>= 22）、检查或安装 Pi CLI、运行安装脚本、协助配置模型额度与 Webhook 唤醒 Routine、录入技能并完成冒烟测试。

### 2. 手动安装步骤

如果你希望在 Bot 所在机器上自行手动安装：

```bash
# 1. 确保 Node.js >= 22，并全局安装 Pi CLI
node -v  # 必须 >= 22
npm i -g @earendil-works/pi-coding-agent
pi --version

# 2. 克隆本仓库并执行安全安装脚本（默认安装到 ~/tools/pi-call）
git clone https://github.com/Chasen-Liao/grokbot-and-pi /tmp/grokbot-and-pi
cd /tmp/grokbot-and-pi
./install.sh

# 3. 将工具目录加入 PATH（可选，如加入 ~/.bashrc）
export PATH="$HOME/tools/pi-call:$PATH"

# 4. 验证命令正常可用
~/tools/pi-call/pi-task --help
```

---

## 日常使用

Grok Bot 通过 `pi-task` 调度与跟踪任务，常用命令如下：

```bash
# 1. 后台派发任务（必须带 --owner）
~/tools/pi-call/pi-task run /workspace/project "重构鉴权中间件并补充单测" \
  --session auth-refactor \
  --owner YOUR_AGENT_ID \
  --notify-prefix GROKBOT \
  [--model provider/model] [--thinking medium] [--timeout 1800]

# 2. 追加要求或在原会话续跑
~/tools/pi-call/pi-task reply TASK_ID "把 token 过期的边界条件也覆盖上" --owner YOUR_AGENT_ID

# 3. 查看状态、查看最新日志或取消任务
~/tools/pi-call/pi-task status TASK_ID
~/tools/pi-call/pi-task log TASK_ID -n 30
~/tools/pi-call/pi-task cancel TASK_ID

# 4. 查看未确认任务并在亲身核验后确认
~/tools/pi-call/pi-task pending --owner YOUR_AGENT_ID
~/tools/pi-call/pi-task ack TASK_ID --owner YOUR_AGENT_ID

# 5. 处理被 pi-guard 拦截的高危审批（必须由用户决断！）
~/tools/pi-call/pi-task approve TASK_ID REQ_ID --owner YOUR_AGENT_ID
~/tools/pi-call/pi-task deny TASK_ID REQ_ID --owner YOUR_AGENT_ID
```

### 任务书五要素

Grok Bot 派活时编写的任务书应当越精炼越好，包含五个关键要素：
1. **做什么**：一两句话讲清楚目标与必要背景（Pi 无法看到聊天上下文）；
2. **产物路径**：修改或生成文件的绝对路径；
3. **完成标准**：可量化核验的标准（如单测通过、导出对应接口）；
4. **严格边界**：如「只改 `/workspace/project/src` 目录，严禁删除任何文件，严禁 git push」；
5. **收尾规则**：「写完产物自查一次即结束，不要反复重试或无限自查」。

---

## 可靠性与韧性保障

- **宿主机睡眠与重启自动恢复**：
  Bot 所在电脑空闲时容易休眠，休眠会冻住 Pi。通过在派发轮次中保持阻塞等待（`AwaitShell`），可确保任务连贯执行不被休眠打断。若机器被突发重启打断，`pi-task status` 能自动识别孤儿进程并标记为 `interrupted`。Bot 仅需运行 `pi-task cancel <ID>` 清理旧状态，再用 `pi-task reply <ID> '电脑刚才重启了，请接着做剩下的工作…' --owner <BOT_ID>` 即可在原会话中无缝续跑。
- **模型链路预检（`pi-preflight`）**：
  电脑刚从睡眠唤醒时，虚拟网卡与转发链路（如 Tailscale）可能处于假死状态：本地端口看似可连，但 HTTP 请求挂起并在 2 分钟后报 `UND_ERR_SOCKET`。将 `bin/pi-preflight.example` 复制到 `~/tools/pi-call/pi-preflight` 并配好健康探测接口，`pi-task` 会在 `run`、`reply` 与 `approve` 执行前自动执行预检，若链路不通则自动重启网络并等待就绪。Pi 遇到连接报错自动重试时也会并行拉起预检。
- **空闲超时熔断（`idle-timeout`）**：
  若 Pi 持续 300 秒（可通过 `--idle-timeout <秒数>` 或环境变量 `PI_TASK_IDLE_TIMEOUT` 配置）未产生任何新的 RPC 事件，`pi-task` 会自动将其判为 `failed`（标记原因 `idle timeout`）并照常发送通知，防止任务因后端死锁无限期挂死。
- **多模型与额度灵活调度**：
  支持直接传入 `--model <provider/model>`、读取环境变量 `PI_TASK_MODEL`，或直接采用 Pi 本地配置的原生默认模型。若在 VPS 上自建网关（如 Magpie）将网页配额转为 API，**务必仅监听 Tailscale 内网地址并启用 Token 认证，严禁向公网开放端口**（详见 [docs/quota.md](docs/quota.md)）。

---

## 安全防护与权限边界

- **防删库跑路扩展（`pi-guard`）**：
  内置在 `extensions/pi-guard.ts` 中并默认开启。`pi-guard` 极窄拦截灾难性删除命令（如针对根目录、用户主目录、工作区或通配符的递归删除 `rm -rf /`、`/workspace`、`*`、`~`，以及危险的 `find -delete`、`mkfs`、底层覆写 `dd of=/dev/`）。项目的正常构建清理（如 `rm -rf ./build`、`node_modules`）完全放行。
- **人机协同审批闭环（`needs_approval`）**：
  当 Pi 尝试执行被拦截的命令时，命令被暂存并分配唯一请求号（`req`），Webhook 向 Bot 发送 `state: "needs_approval"` 通知。**Bot 必须将命令原样展示给人类用户，严禁擅自审批放行。** 只有当用户明确同意放行后，Bot 才执行 `pi-task approve <ID> <req> --owner <BOT_ID>`。
- **高危不可逆操作严禁派给 Pi**：
  文件删除、发送消息/邮件、在线付款、公开发帖、代码库推送（`git push`）等高风险操作**绝对不交给 Pi**。必须在任务完成并由用户确认后，由 Grok Bot 亲自执行。
- **敏感凭证防泄漏**：
  通知密钥（`<BOT>_PI_NOTIFY_URL`、`<BOT>_PI_NOTIFY_KEY`）与认证文件（`~/.pi/agent/auth.json`）在启动 Pi 子进程前会被彻底清除，严禁将其打印到聊天框或持久化到任务日志中。

---

## 仓库目录结构

```text
grokbot-and-pi/
├── AGENTS.md                  # 专供 Grok Bot 阅读的 7 步端到端自配置指南
├── bin/
│   ├── pi-task                # 主 CLI 入口（集成预检与环境管理）
│   ├── pi-task.mjs            # 任务核心生命周期管理器（RPC、事件流、owner 机制、审批）
│   ├── pi-call.mjs            # 底层单次 RPC 客户端
│   ├── pi-run                 # 同步单次快捷包装脚本
│   └── pi-preflight.example   # 模型网络链路预检与自动重连示例脚本
├── extensions/
│   └── pi-guard.ts            # 轻量级防删库扩展（基于 tool_call 拦截）
├── skills/
│   ├── grokbot-pi-setup/      # 用于初始化环境与连通性验证的 Bot 技能
│   └── grokbot-pi-dispatch/   # 用于日常任务书撰写、后台派活与验收确认的 Bot 技能
├── routines/
│   └── pi-task-notify.md      # Grok Bot 平台的 Webhook Routine 提示词模板
├── docs/
│   ├── architecture.png       # 架构示意图
│   ├── quota.md               # 模型额度接入指南（官方 API、中转站、自建 Magpie 网关）
│   ├── security.md            # pi-guard 防护规则细节与人机审批放行机制说明
│   ├── setup-guide.md         # 详细部署、内部生命周期与存储结构参考文档
│   └── pi-task-reference.md   # pi-task 命令行子命令、参数与环境变量完整手册
├── tests/
│   └── pi-guard.test.mjs      # pi-guard 拦截与放行逻辑测试集
├── install.sh                 # 安全的一键安装脚本
├── UPSTREAM-README.md         # 上游项目原始文档（供追溯参考）
└── LICENSE                    # MIT 开源许可证
```

---

## 扩展文档

- [模型额度配置指南 (docs/quota.md)](docs/quota.md) — 官方 API Key、OpenAI 兼容中转站与自建 Magpie 网关安全配置。
- [安全防护机制与放行流程 (docs/security.md)](docs/security.md) — `pi-guard` 拦截规则与 `approve`/`deny` 审批流程。
- [详细部署与生命周期说明 (docs/setup-guide.md)](docs/setup-guide.md) — 任务生命周期、目录存储格式与手动配置向导。
- [pi-task 命令行完整参考手册 (docs/pi-task-reference.md)](docs/pi-task-reference.md) — 子命令参数、退出码与环境变量完整说明。
- [例行任务唤醒模板 (routines/pi-task-notify.md)](routines/pi-task-notify.md) — 在 Grok Bot 平台创建 Webhook Routine 的标准提示词。

---

## 致谢与开源协议

本项目基于 [robbin/grokbot-local-agent](https://github.com/robbin/grokbot-local-agent) 构建与改进，遵循 [MIT 许可证](LICENSE)。完整上游说明请参阅 [UPSTREAM-README.md](UPSTREAM-README.md)。向原作者 robbin 的卓越设计致敬！
