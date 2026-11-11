# AGENTS.md — GAP (Grokbot And Pi) 配置向导

> 本文档专门写给 **Grok Bot（AI Agent）**。  
> 当用户将本仓库链接发给你时，请按照本文档的 7 个步骤依序自行配置完成。  
> 每一项明确了操作步骤、完成标准，以及**必须由用户操作**的边界。

---

## 步骤 1：检查并安装 Pi

### Agent 执行
1. 检查 Node.js 版本（必须 `>= 22`）：
   ```bash
   node -v
   ```
2. 检查 `pi` 命令是否已安装：
   ```bash
   command -v pi || which pi
   ```
3. 若未安装，在当前用户环境中全局安装 Pi coding agent：
   ```bash
   npm i -g @earendil-works/pi-coding-agent
   ```
4. 验证 Pi 可执行性：
   ```bash
   pi --version
   ```

### 判定完成标准
- `node -v` 输出主版本号 `>= 22`。
- `pi --version` 能够正常输出版本号且退出码为 0。

---

## 步骤 2：配置模型与额度

### 必须由用户做的事
- **确定额度来源**：请向用户确认使用哪种模型额度（详情参见 [docs/quota.md](docs/quota.md)）：
  - 选项 A：直接使用官方 API Key（如 DeepSeek、OpenRouter 等）或 OpenAI 兼容中转站；
  - 选项 B：使用 VPS 上通过 Tailscale 内网运行的 Magpie 转换网关；
  - 选项 C：如果 Pi 本机已经配置好默认模型额度，可直接沿用默认设置。

### Agent 执行
在获得用户配置或默认授权后，运行最小无会话命令测试模型连通性：
```bash
# 测试 Pi 原生默认模型
pi -p "Reply with only OK" --no-session

# 或测试指定的 provider 与 model
pi -p "Reply with only OK" --provider <provider> --model <model> --no-session
```

### 判定完成标准
- 命令输出包含 `OK`，且退出码为 0。

---

## 步骤 3：克隆仓库并安装脚本

### Agent 执行
克隆本仓库到临时目录并执行安全安装脚本：
```bash
git clone https://github.com/Chasen-Liao/grokbot-and-pi /tmp/grokbot-and-pi
cd /tmp/grokbot-and-pi
./install.sh
```

### 判定完成标准
- 目标目录 `~/tools/pi-call/` 下存在 `pi-task`、`pi-task.mjs`、`pi-call.mjs`、`pi-run` 且均具备可执行权限（`chmod +x`），`extensions/pi-guard.ts` 已同步安装且 guard 默认开启。
- 运行 `~/tools/pi-call/pi-task --help` 正常打印使用指南。

---

## 步骤 4：创建 Webhook 唤醒例行任务（Routine）

### Agent 与用户协作
1. 参考 [routines/pi-task-notify.md](routines/pi-task-notify.md)。
2. 获取当前 Bot 的 Agent ID（可从当前 Bot 的 profile 路径中读取，例如 `/home/box/agent-data/agents/<BOT_ID>/profile.json` 目录名）。
3. **在 Grok Bot 平台的 Routines 界面创建例行任务**：
   - 触发方式：**Webhook**。
   - 任务名称：如 `Pi 任务完成唤醒`。
   - 提示词内容：将 `routines/pi-task-notify.md` 中的「例行任务提示词」完整填入，将其中的 `<BOT_ID>` 严格替换为真实的 Agent ID。

### 判定完成标准
- Routine 创建并启用，生成了对应的 Webhook URL 以及认证 Bearer Token。

---

## 步骤 5：录入 Webhook 密钥（必须由用户完成）

### ⚠️ 铁律安全要求（必须由用户完成）
- **严禁**让用户在普通聊天窗口中明文发送 URL 和 Secret！
- **严禁**将 Webhook 密钥写入代码仓库、本地文件或脚本中！
- Agent 必须明确引导用户：**使用平台的安全凭证输入卡（Secret Card / 环境变量设置）**录入以下两个变量：
  - `<BOT>_PI_NOTIFY_URL`：步骤 4 中生成的 Webhook 回调地址；
  - `<BOT>_PI_NOTIFY_KEY`：步骤 4 中生成的 Bearer Token 密钥。
  （其中 `<BOT>` 为当前 Bot 指定的大写前缀标识，例如 `GROKBOT`）。

### Agent 验证
检查环境变量是否已对当前 Bot 环境生效（仅检查变量名是否存在，不打印密钥值）：
```bash
[ -n "${GROKBOT_PI_NOTIFY_URL:-}" ] && [ -n "${GROKBOT_PI_NOTIFY_KEY:-}" ] && echo "Configured"
```

### 判定完成标准
- 环境变量已安全注入，不暴露任何具体密钥内容。

---

## 步骤 6：保存 Grok Bot 技能（Skills）

### Agent 执行
将本仓库 `skills/` 下的两个 Skill 文件存入当前 Bot 的技能系统（例如存至 Bot 专用的 skills 目录或按平台规范加载）：
1. `skills/grokbot-pi-setup/SKILL.md`：用于后续重新配置与自检。
2. `skills/grokbot-pi-dispatch/SKILL.md`：用于日常编写任务书并后台派活。

### 判定完成标准
- 两个技能的 `SKILL.md` 已被当前 Bot 正确加载，Bot 能够理解「派活给 Pi」、「写任务书」及「按 grokbot-pi-dispatch 派活」的意图与规则。

---

## 步骤 7：端到端闭环冒烟测试

### Agent 执行测试流程
1. **后台派发最小任务**（必须在后台运行，不阻塞当前轮）：
   ```bash
   ~/tools/pi-call/pi-task run /tmp "在 /tmp/gap-smoke.txt 中写入 gap-ok 并自查结束" --session smoke-gap --owner <BOT_ID> --notify-prefix <BOT>
   ```
2. 向用户简要说明已派发最小任务，**不要结束当前轮**，用一次长时间阻塞的 AwaitShell 等它跑完（Bot 空闲时电脑可能睡眠或重启，会冻住 Pi）；Webhook 唤醒只是兜底。
   - 电脑刚从睡眠醒来时，Tailscale 等链路可能还没恢复（端口通但请求挂住，最后报 `UND_ERR_SOCKET`）。所以派活前先测模型通路：如果走网关，按 `bin/pi-preflight.example` 配好 `bin/pi-preflight`，`pi-task` 会在 run/reply/approve 前自动检查、必要时重连再开跑；Pi 遇到连接错误自动重试时也会再跑一次。
3. **等它跑完或被 Webhook 唤醒后**：
   - 运行检查自身任务：
     ```bash
     ~/tools/pi-call/pi-task pending --owner <BOT_ID>
     ```
   - 读取结果：
     ```bash
     ~/tools/pi-call/pi-task status <TASK_ID>
     cat ~/.pi/tasks/<TASK_ID>/result.md
     ```
   - **亲自核验产物真实性**：
     ```bash
     cat /tmp/gap-smoke.txt # 检查内容必须为 gap-ok
     ```
   - 核验合格后，确认任务：
     ```bash
     ~/tools/pi-call/pi-task ack <TASK_ID> --owner <BOT_ID>
     ```
   - 验证待办已清空：
     ```bash
     ~/tools/pi-call/pi-task pending --owner <BOT_ID> # 输出应为空
     ```
4. 向用户汇报端到端测试成功，GAP 架构已就绪。

### 判定完成标准
- Bot 等待任务完成或被 Webhook 独立唤醒；
- `cat /tmp/gap-smoke.txt` 内容确实为 `gap-ok`；
- 执行 `ack` 后 `pi-task pending --owner <BOT_ID>` 输出为空；
- 全链路闭环验证通过。
