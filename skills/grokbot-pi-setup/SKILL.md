---
name: grokbot-pi-setup
description: 第一次让 Grok Bot 把执行活派给电脑上的 Pi 之前用：在 Bot 的电脑上装 Pi、给 Pi 接一个模型（任意 API key、中转站、网关或自带默认模型）、装 pi-task 并配好「Pi 跑完自动叫醒 Bot」的 webhook，并跑通一次验收。装好后日常派活看 grokbot-pi-dispatch。
---

# grokbot-pi-setup：让 Grok Bot 能派活给 Pi

目标：Grok Bot 额度贵，只用来「拆任务 + 验收」；真正干活交给 Bot 电脑上的 Pi（无头 coding agent），Pi 用什么模型都行（官方 API、中转站、自建网关或 Pi 默认自带额度），花的是你自己的额度。

做完应该满足三条：
1. Bot 的 Shell 里 `pi -p 'reply ok' --no-session`（或指定 `--provider` / `--model`）回复 ok。
2. `~/tools/pi-call/pi-task` 能跑，有一个 webhook 例行任务能把 Bot 单独叫醒。
3. 两个密钥 `<BOT>_PI_NOTIFY_URL`、`<BOT>_PI_NOTIFY_KEY` 已存好，Bot 不在聊天里打印它们。

按下面顺序做，每步验收过再往下走。删除、付款、登录这类动作先问用户。

## 1. 装 Pi
- 在 Bot 的电脑上按 Pi 官方文档安装，确认 `pi --version` 能跑（推荐 Node >= 22）。
- 先跑通 `pi -p 'reply ok' --no-session`，证明 Pi 本身没问题。

## 2. 给 Pi 接一个模型（来源随意）
Pi 能用的模型都行，挑你手上有的（详情参见 `docs/quota.md`）：
- 直接用官方 API key 或中转站：DeepSeek、OpenRouter 等，按 Pi 文档配置（如 `~/.pi/agent/models.json` 或 `pi /login`）。
- 用自建网关统一管理（可选）：比如 Magpie，把订阅或各家 key 统一接进去。若部署在 VPS 上，**务必只监听 Tailscale 内网地址，严禁开放公网端口**，并开启 token 认证。
  - 走网关时建议配通路预检：`cp bin/pi-preflight.example ~/tools/pi-call/pi-preflight`，改好里面的健康接口和 Tailscale/转发脚本路径。Bot 电脑经常睡眠，醒来后链路可能端口通但请求挂住，pi-task 会在派活前用它检查、必要时重连。
- 直接使用 Pi 默认配置：如果 Pi 本身已经配置好默认模型，后续派活时甚至不需要指定 `--model`。

验证模型连通性：
```bash
pi -p 'reply ok' --no-session
# 或指定模型：
pi -p 'reply ok' --provider <provider> --model <model> --no-session
```
回复 ok 即可。

## 3. 装 pi-task 并配「跑完自动叫醒」
克隆本仓库并运行安装脚本（会自动检查 Node >= 22 和 pi，复制到 `~/tools/pi-call`）：

```bash
git clone https://github.com/Chasen-Liao/grokbot-and-pi /tmp/grokbot-and-pi
cd /tmp/grokbot-and-pi && ./install.sh
```

冒烟测试：
```bash
PI_NOTIFY_OFF=1 ~/tools/pi-call/pi-task run /tmp 'Reply with only OK' --session smoke --owner <ID>
```
看到 `STATE done` 后，再确认该任务：
```bash
~/tools/pi-call/pi-task ack <TASK_ID> --owner <ID>
```

然后配唤醒：
1. Bot 自己建一个 webhook 触发的例行任务，例如「Pi 完成唤醒」。内容参见仓库里的 `routines/pi-task-notify.md`：醒来先跑 `pi-task pending --owner <ID>`，按 grokbot-pi-dispatch 第 4 步核验、回报、ack；别的 Bot 的任务不碰。
2. 让用户用密钥输入卡，把 webhook 地址和 key 存成环境变量 `<BOT>_PI_NOTIFY_URL`、`<BOT>_PI_NOTIFY_KEY`（不要贴进聊天或文件）。多个 Bot 各用各的变量名前缀。派活时只需加上 `--notify-prefix <BOT>`，`pi-task` 会自动读取对应通知配置并完成回调，无需手动映射环境变量。

## 4. 端到端验收
派一个最小任务（比如「在 /tmp/pi-test.txt 写一行 hello」），按 grokbot-pi-dispatch 的命令后台跑，不要结束当前轮，用长时间阻塞等待跑完立刻验收（Webhook 唤醒作为兜底）。确认：`pi-task pending` 里有它、文件内容正确，ack 后 pending 变空。

## 风险，要跟用户说清楚
- Pi 默认没有沙箱，能改电脑上的任何文件。任务里必须限定目录、禁止删除。
- 若将个人订阅通过网关转成 API 使用，可能违反服务条款，有封号风险，建议用小号。
- 密钥只保存在环境变量中，不写进文件、不打印到聊天界面。
