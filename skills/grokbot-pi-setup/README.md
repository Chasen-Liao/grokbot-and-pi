# 🔧 grokbot-pi-setup

让 Grok Bot 能把执行活派给电脑上的 **Pi**：装 Pi → 给 Pi 接一个模型（**官方 API / 中转站 / Magpie 网关 / Pi 自带默认模型**）→ 克隆仓库并运行 `./install.sh` → 配「Pi 跑完 webhook 叫醒 Bot」→ 端到端验收。

**适合谁**：Grok Bot 额度珍贵，想让 Bot 专注于「思考拆解」与「结果验收」，具体的批量代码和文档编写「干活」交给 Pi 并消耗自身模型额度的人。

**安装**
```bash
npx skills add Chasen-Liao/Chasen-Skills --skill grokbot-pi-setup --global --yes
```

**触发**：对 Bot 说「帮我配好 Pi 派活」「按 grokbot-pi-setup 装一下」。

装好以后日常怎么用，看 [grokbot-pi-dispatch](../grokbot-pi-dispatch/README.md)。

⚠️ Pi 默认没有沙箱，任务里要限定目录、禁止删除。
