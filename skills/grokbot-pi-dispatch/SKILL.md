---
name: grokbot-pi-dispatch
description: Grok Bot 要做超过两三步的执行活（写代码、改文件、扫目录、整理或生成内容）时，开干前读这个：Bot 只写任务书、用 pi-task 后台派给电脑上的 Pi、被 webhook 叫醒后验收并确认。还没装好先看 grokbot-pi-setup。
---

# grokbot-pi-dispatch：Bot 写任务，Pi 干活，Bot 验收

Bot 只做三件事：写任务、派给 Pi、验收。一两步的小事 Bot 自己做，别派。
派活用 `pi-task`：每个任务有 ID、状态目录和派活的 Bot（owner），跑完发通知，验收完 ack，不漏报也不报别人的任务。

## 0. 自己的 owner ID
Bot 的 agent id，在 `/home/box/agent-data/agents/<ID>/profile.json` 的目录名里。派活、reply、pending、ack、approve 都带 `--owner <ID>`。

## 1. 写任务书（越短越好）
只写五件事：
1. 要做什么（一两句，带上必要背景：Pi 看不到聊天）。
2. 产物写到哪个绝对路径。
3. 怎么算做完（可检查的标准）。
4. 边界：「只改 <目录>，不要删除任何文件，不要 git push」。
5. 收尾：「写完产物自查一次就结束，不要反复自查或重试」。

## 2. 后台派活
用 Bot 自己的 Shell 工具**后台**运行（不阻塞等待；不要用 `nohup`、`&`）：

```bash
~/tools/pi-call/pi-task run <工作目录> '<任务书>' --session <短名> --owner <ID> --notify-prefix <BOT> [--model <provider/model>] [--thinking medium] [--timeout 1800]
```

- `--notify-prefix <BOT>` 会自动从 `<BOT>_PI_NOTIFY_URL` 与 `<BOT>_PI_NOTIFY_KEY` 读取通知配置；在同一台电脑上有多个 Bot 时各用各的 webhook，无需手动传 secret。
- 模型可选：省略 `--model` 时优先读取 `PI_TASK_MODEL`，两者皆无时直接采用 Pi 配置的默认模型与额度；也可以显式传入 `--model <provider/model>`。
- 工作目录选最小的（项目目录或 /tmp/<名>），不要 / 或整个 home。
- 只读的活加 `--no-write`；不需要联网加 `--no-web`；难活才 `--thinking high`。
- 追加要求用 `pi-task reply <ID> '<补充>' --owner <ID>`，校验 owner 并沿用同一会话与目录。
- 派完告诉用户「已派出」，然后**立刻结束当前轮**，等 webhook 单独叫醒。

## 3. 等结果与审批放行
- 正常完成：pi-task 结束时 POST `{source,id,owner,state,exit_code}` 到 webhook，例行任务把 Bot 单独叫醒。
- 审批放行（needs_approval）：若 Pi 触发高危命令保护被 pi-guard 拦截，Webhook 会推送包含 `state: "needs_approval"`、`req` 和 `command` 的通知：
  1. Bot 必须将命令 `command` 原样展示给用户，并说明已被拦截，询问用户是否授权放行；
  2. 用户同意放行：运行 `~/tools/pi-call/pi-task approve <ID> <req> --owner <ID>`；
  3. 用户拒绝放行：运行 `~/tools/pi-call/pi-task deny <ID> <req> --owner <ID>`；
  4. 铁律：Bot 自己永远不能替用户点击或授权放行！
- 兜底：每次醒来、而且派过活，就跑 `pi-task pending --owner <ID>`。
- 看进度：`pi-task status <ID>`、`pi-task log <ID> -n 20`；取消：`pi-task cancel <ID>`。
- 硬盘上的 `~/.pi/tasks/<ID>/` 才是真相；漏了通知不要重跑。

## 4. 验收并确认
1. 读 `~/.pi/tasks/<ID>/result.md`，再亲自检查产物、diff 或测试。Pi 的回复只是声称，不算证据。
2. 回报用户：ID、状态、结论、验收证据、产物路径。
3. `pi-task ack <ID> --owner <ID>`。验收不过就不 ack，用 `pi-task reply <ID> '<补充说明>' --owner <ID>` 补充说明重派，最多两次；失败或超时先问用户要不要重试。

## 规矩
- 删除、发送消息或邮件、付款、发帖、push，永远不交给 Pi，由 Bot 在用户确认后自己做。
- 审批放行（needs_approval）必须由用户决断，Bot 严禁擅自 approve。
- Pi 内置 pi-guard 防灾难删除扩展默认开启；任务书仍应明确限定目录、禁止删除。
- 不读、不打印密钥和 `~/.pi/agent/auth.json`。
- 别的 Bot 的任务不看、不报、不 ack；永远带 `--owner` 过滤。
