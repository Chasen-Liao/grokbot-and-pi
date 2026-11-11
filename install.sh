#!/usr/bin/env bash
# install.sh — 安装 grokbot-and-pi 工具脚本
#
# 检查 Node >= 22 和 pi 命令，将 bin/ 复制到 ${PI_TASK_HOME:-$HOME/tools/pi-call}
# 脚本绝不执行任何删除操作。

set -euo pipefail

echo "==> 检查系统依赖环境..."

# 1. 检查 node
if ! command -v node >/dev/null 2>&1; then
  echo "错误：未检测到 'node' 命令。" >&2
  echo "grokbot-and-pi 需要 Node.js >= 22，请先安装 Node.js（https://nodejs.org/）。" >&2
  exit 1
fi

NODE_MAJOR=$(node -e 'console.log(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)
if [ "$NODE_MAJOR" -lt 22 ]; then
  echo "错误：当前 Node.js 版本为 $(node -v)，但需要 Node.js >= 22。" >&2
  echo "请升级 Node.js 后重试（例如使用 nvm、fnm 或包管理器）。" >&2
  exit 1
fi
echo "  ✓ Node.js $(node -v) 符合要求"

# 2. 检查 pi
if ! command -v pi >/dev/null 2>&1; then
  echo "错误：未在 PATH 中找到 'pi' 命令。" >&2
  echo "请先安装 Pi coding agent（参见 https://pi.dev 或执行 npm i -g @earendil-works/pi-coding-agent）。" >&2
  exit 1
fi
echo "  ✓ 检测到 pi 命令: $(command -v pi)"

# 3. 复制 bin/ 脚本到目标目录
TARGET_DIR="${PI_TASK_HOME:-$HOME/tools/pi-call}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 安装脚本至: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

# 复制文件（不删除已有文件）
cp -p "$SCRIPT_DIR/bin/"* "$TARGET_DIR/"
chmod +x "$TARGET_DIR/pi-task" "$TARGET_DIR/pi-task.mjs" "$TARGET_DIR/pi-call.mjs" "$TARGET_DIR/pi-run"

echo "  ✓ 已复制并配置可执行权限: pi-task, pi-task.mjs, pi-call.mjs, pi-run"

# 4. 打印后续指引
echo ""
echo "=========================================="
echo "✅ 安装成功！已就绪于: $TARGET_DIR"
echo "=========================================="
echo ""
echo "下一步操作建议："
echo ""
echo "1. 将工具目录加入 PATH（可在 ~/.bashrc 或 shell 配置中持久化）："
echo "   export PATH=\"$TARGET_DIR:\$PATH\""
echo ""
echo "2. 运行冒烟测试（关闭通知，快速验证执行与追踪）："
echo "   PI_NOTIFY_OFF=1 \"$TARGET_DIR/pi-task\" run /tmp 'Reply with only OK' --session smoke --owner smoke-test"
echo "   # 观察输出包含 STATE done 后确认该任务："
echo "   \"$TARGET_DIR/pi-task\" ack smoke-... --owner smoke-test"
echo ""
echo "3. 为 Grok Bot 配置 Webhook 唤醒例行任务："
echo "   参考 routines/pi-task-notify.md 在 Bot 平台创建例行任务，并安全配置环境变量："
echo "   <BOT>_PI_NOTIFY_URL 和 <BOT>_PI_NOTIFY_KEY"
echo ""
echo "4. 在 Grok Bot 中加载对应技能："
echo "   - skills/grokbot-pi-setup   : 初始化环境与连通性验证"
echo "   - skills/grokbot-pi-dispatch: 自动派活、监控与验收确认"
echo ""
