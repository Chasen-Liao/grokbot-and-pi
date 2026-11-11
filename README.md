# GAP — Grokbot And Pi

让 Grok Bot 把繁重的代码编写、文件批处理、长文档整理等执行活派给同机运行的 **Pi coding agent**（[pi.dev](https://pi.dev)）作为 subagent，并在任务完成后通过 Webhook 唤醒 Bot 亲自核验与回报。

[English](README.en.md) | 简体中文

---

## 架构与核心流程

![GAP Architecture](docs/architecture.png)

GAP 包含清晰的 4 步闭环：

1. **Bot 派活**：Grok Bot 编写包含明确边界的任务书，通过 `pi-task run` 在后台启动任务，不阻塞当前对话；
2. **Pi 后台执行**：Pi 作为本地轻量无头 coding agent 执行代码与文件操作，Bot 结束当前轮次等待唤醒；
3. **curl 通知**：**任务结束时，由 `pi-task` 在后台自动向设定的 Webhook 地址发起 HTTP POST 通知**（数据仅包含 `{source, id, owner, state, exit_code}`，不含正文与密钥）；
4. **Bot 验收**：Webhook 唤醒 Grok Bot 的例行任务（Routine），Bot 运行 `pi-task pending --owner <BOT_ID>` 读取状态和 `result.md`，亲自检查日志、diff 与生成产物，验收无误后 `ack` 确认并向用户汇报。

> **磁盘是唯一事实来源**：Webhook 通知仅用于降低唤醒延迟。若网络偶发丢包，Bot 下次唤醒只需运行 `pi-task pending --owner <BOT_ID>` 即可完整找回未报告的任务。

---

## 快速开始

把仓库链接发给你的 Grok Bot，让它按 [AGENTS.md](AGENTS.md) 自行配置：
```text
请阅读 https://github.com/Chasen-Liao/grokbot-and-pi 的 AGENTS.md，帮我把 GAP 配置好。
```

### 手动安装步骤

如果你希望手动安装：

```bash
# 1. 确保 Node.js >= 22 并全局安装 Pi CLI
npm i -g @earendil-works/pi-coding-agent

# 2. 克隆本仓库并执行安装脚本（默认安装到 ~/tools/pi-call）
git clone https://github.com/Chasen-Liao/grokbot-and-pi /tmp/grokbot-and-pi
cd /tmp/grokbot-and-pi && ./install.sh

# 3. 配置模型额度与 Webhook 唤醒例行任务
# - 模型额度方案：参见 docs/quota.md
# - Webhook 例行任务模板：参见 routines/pi-task-notify.md
# - 加载技能：参见 skills/grokbot-pi-setup 与 skills/grokbot-pi-dispatch
```

---

## 与上游（grokbot-local-agent）的区别

本项目基于 [robbin/grokbot-local-agent](https://github.com/robbin/grokbot-local-agent) 改进而来，主要改动：

1. **支持任意 Provider 或 Pi 原生默认模型**：去除原先写死的网关默认值，支持 `--model` 与 `PI_TASK_MODEL`；缺省时不传参数，直接沿用 Pi 本地配置的默认模型与自带额度；
2. **多 Bot 隔离通知（`--notify-prefix <NAME>`）**：支持同台机器上的多个 Bot 独立配置 `<NAME>_PI_NOTIFY_URL` 和 `<NAME>_PI_NOTIFY_KEY`，启动 Pi 前自动清除所有敏感通知环境变量；
3. **一键安全安装脚本（`install.sh`）**：自动化环境检查（Node >= 22 与 Pi CLI），安全复制并配置权限；
4. **内置 Grok Bot 专属技能生态（Skills）**：开箱即用的 `grokbot-pi-setup` 与 `grokbot-pi-dispatch`；
5. **严谨的 `--owner` 闭环验收流程**：多 Bot 独立 pending 与 ack，拒绝越权确认，任务失败绝不盲目重跑；
6. **Agent 自动化向导（`AGENTS.md`）**：专门面向 AI Agent 编写的 7 步端到端自配置与验收指南；
7. **内置防删库跑路扩展（`pi-guard`）**：默认启用，对 `rm -rf /`、`/workspace` 等灾难性递归删除、`find -delete`、`mkfs` 及 `dd of=/dev/` 精准拦截，支持 Webhook `needs_approval` 发起人机放行机制（`approve` / `deny`，详见 [docs/security.md](docs/security.md)）；
8. **安全的追问所有权校验（`reply --owner`）**：`reply` 子命令支持 `--owner <id>` 强校验，不一致直接拒绝（exit 2），杜绝多 Bot 间串台越权；
9. **空闲超时熔断机制（`--idle-timeout`）**：支持 `--idle-timeout`（及 `PI_TASK_IDLE_TIMEOUT`，默认 300 秒），Pi 长期无新 RPC 事件时自动熔断为 failed（标记 idle timeout）并照常发出通知，防止任务无限死锁。

---

## 安全与边界说明

- **Pi 默认没有沙箱隔离**：Pi 具备直接读写文件和执行 Shell 命令的能力。任务书中必须严格限定工作目录，并严禁删除文件。
- **高危不可逆操作严禁派给 Pi**：文件删除（`rm` 等）、发送邮件/消息、在线付款/交易、公开发帖、`git push` 等操作**永远不交给 Pi**，必须在任务完成后由 Grok Bot 在获得用户确认后亲自执行。

---

## 致谢与开源协议

本项目基于 [robbin/grokbot-local-agent](https://github.com/robbin/grokbot-local-agent) 构建与改进，采用 [MIT 许可证](LICENSE)。特别致谢原作者 robbin 提供的优秀设计思路！
