# Pi Subagent 模型额度配置指南

在 Grok Bot 架构中，Grok Bot 负责高价值的意图理解、任务拆解与最终验收，而具体的繁重执行活（如代码编写、批量文件重构、长文本整理）派发给本机运行的 Pi coding agent（[pi.dev](https://pi.dev)）。

由于执行过程会消耗大量 Token，为了避免耗尽 Grok Bot 自身的对话配额，Pi 可以灵活使用你自己的模型额度。本文介绍两种常见的额度接入方案：

---

## 方案 A：直接使用 Pi 原生 Provider（推荐，简单稳定）

这是最直接、也是官方推荐的配置方式。直接为 Pi 接入官方大模型 API Key 或 OpenAI 兼容格式的中转服务商，完全无需维护额外的网关中间件。

### 1. 官方 API Key
Pi 原生支持主流的模型提供商（例如 DeepSeek、OpenRouter、Anthropic、OpenAI、Google 等）。

- **配置方式**：
  在系统环境或启动配置中注入对应的 API Key（或通过 `pi /login` 进行交互式凭据配置）：
  ```bash
  export DEEPSEEK_API_KEY="sk-your-official-api-key"
  ```
- **使用方式**：
  - 设为默认：在 `~/.pi/agent/config.json` 或环境变量 `PI_TASK_MODEL="deepseek/deepseek-chat"` 中设置；
  - 派发时显式指定：
    ```bash
    ~/tools/pi-call/pi-task run /path/to/work "编写单元测试" --session task1 --owner mybot --model deepseek/deepseek-chat
    ```
  - 省略 `--model`：如果未指定 `--model` 且未设置 `PI_TASK_MODEL`，`pi-task` 将直接由 Pi 采用其自带配置的默认模型与额度。

### 2. OpenAI 兼容的中转服务站
如果你使用的是第三方 API 代理中转服务（通常提供与 OpenAI 规范完全兼容的 `/v1/chat/completions` 接口）：

- **配置方式**：
  在 Pi 的自定义模型配置文件（通常为 `~/.pi/agent/models.json`）中声明自定义 Provider：
  ```json
  {
    "providers": {
      "my-relay": {
        "baseUrl": "https://api.relay-example.com/v1",
        "apiKey": "sk-relay-placeholder-key",
        "api": "openai-compatible",
        "models": [
          {
            "id": "claude-3-5-sonnet-20241022",
            "name": "Claude 3.5 Sonnet",
            "contextWindow": 200000
          }
        ]
      }
    }
  }
  ```
- **使用方式**：
  ```bash
  ~/tools/pi-call/pi-task run /path/to/work "重构模块" --session task2 --owner mybot --model my-relay/claude-3-5-sonnet-20241022
  ```

---

## 方案 B：自建 Magpie 网关（可选，订阅转 API）

如果你持有网页端订阅配额，并希望将其转化为标准 API 接口以统一供给 Pi 等 coding agent 调用，可以部署类似 Magpie 的转换网关。

### 1. 架构与网络安全最佳实践

为了确保服务安全且不将敏感认证暴露在公网，推荐遵循以下部署原则：

```text
[VPS 网关服务]
  └─ 仅绑定 Tailscale 内网地址 (例如 100.64.0.1:8080)
  └─ 严禁开放公网端口 (防火墙关闭公网该端口)
  └─ 开启 Bearer API Key 认证
         ▲
         │ (Tailscale 虚拟局域网加密传输)
         ▼
[Grok Bot 所在机器]
  └─ 接入同一 Tailscale 网络
  └─ ~/.pi/agent/models.json 代理指向 http://100.64.0.1:8080/v1
```

- **部署在独立 VPS 上**：将网关服务独立托管，不与 Bot 业务容器混部。
- **仅监听内网 IP**：配置服务监听地址为 Tailscale 虚拟网卡 IP（例如 `100.64.0.1`）或 Unix Socket，**切勿监听 `0.0.0.0`**。
- **防火墙零公网暴露**：云服务器的安全组与 `iptables` 严禁对公网开放该端口，仅允许内网网段访问。
- **强制密钥认证**：即使在内网环境，也必须启用网关自带的访问令牌验证（如 Authorization Bearer Token）。

### 2. Pi 侧配置示例

在运行 Pi 的主机上加入同一 Tailscale 网络后，在 `~/.pi/agent/models.json` 中配置该网关作为 Provider：

```json
{
  "providers": {
    "magpie": {
      "baseUrl": "http://100.64.0.1:8080/v1",
      "apiKey": "your-internal-gateway-token",
      "api": "openai-compatible",
      "models": [
        {
          "id": "provider-slug/model-name",
          "name": "Gateway Model",
          "contextWindow": 128000
        }
      ]
    }
  }
}
```

测试联通性：
```bash
pi -p 'Reply with OK' --provider magpie --model provider/model-name --no-session
```

### 3. 合规与封号风险警示
- **服务条款（TOS）限制**：将网页端个人订阅转化为 API 供 Agent 批量调用可能违反对应平台的使用条款。
- **风险防范**：建议使用非主号或专用账号进行接入，并设置合理的调用频率与并发限制，防范封号风险。

---

## 总结与建议

| 维度 | 方案 A：直接 Provider | 方案 B：自建网关（如 Magpie） |
| :--- | :--- | :--- |
| **部署成本** | 零维护，开箱即用 | 需要独立 VPS 及 Tailscale 组网 |
| **稳定性** | 极高（官方稳定 SLA） | 取决于网关可用性与上游状态 |
| **适用场景** | 生产开发、追求高可靠性与速度 | 已有闲置订阅配额、多设备共享额度池 |
| **推荐模型** | DeepSeek V3/R1、Claude 3.5 Sonnet、OpenRouter 等 | 按网关支持的订阅模型选择 |
