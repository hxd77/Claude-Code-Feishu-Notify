<div align="center">

<br>

<img src="assets/logo.svg" alt="Claude Code Feishu Notify" width="600"/>

<br>

[![License](https://img.shields.io/github/license/hxd77/Claude-Code-Feishu-Notify?color=f59e0b&style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/hxd77/Claude-Code-Feishu-Notify?color=f59e0b&style=flat-square)](https://github.com/hxd77/Claude-Code-Feishu-Notify/stargazers)
![Python](https://img.shields.io/badge/Python-3.7+-3776AB?logo=python&logoColor=white&style=flat-square)
![Bash](https://img.shields.io/badge/Bash-4.0+-4EAA25?logo=gnubash&logoColor=white&style=flat-square)
![Feishu](https://img.shields.io/badge/Feishu-Lark-3370FF?logo=feishu&logoColor=white&style=flat-square)
![Platform](https://img.shields.io/badge/Windows%20%7C%20macOS%20%7C%20Linux-6b7280?style=flat-square)

<br>

<h3>Claude Code 每完成一次对话 👉 飞书群收到一张卡片 👉 自动消失</h3>

</div>

<br>

---

<br>

<table>
<tr>
<td width="33%" align="center">
  <h3>🟡</h3>
  <b>需要操作</b>
  <br><sub>权限弹窗 / 提问时</sub>
  <br><sub>立刻推送黄色卡片</sub>
</td>
<td width="33%" align="center">
  <h3>🟢</h3>
  <b>任务完成</b>
  <br><sub>会话结束自动推送</sub>
  <br><sub>Token · 耗时 · 费用</sub>
</td>
<td width="33%" align="center">
  <h3>🔥</h3>
  <b>阅后即焚</b>
  <br><sub>60 秒后自动删除</sub>
  <br><sub>API 模式下生效</sub>
</td>
</tr>
</table>

<br>

---

## 架构总览

<p align="center">
  <img src="diagram/architecture.svg" alt="Architecture" width="100%"/>
</p>

> [!NOTE]
> **三层 Hook 覆盖** — `Notification` 捕获权限弹窗，`PostToolUse` 捕获主动提问，`Stop` 处理会话结束。API 失败自动降级 Webhook，消息不丢。

---

## 快速开始

### 📦 安装

```bash
mkdir -p ~/.claude/hooks
cp feishu-notify.sh feishu-ask.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/feishu-notify.sh ~/.claude/hooks/feishu-ask.sh
```

### ⚙️ 配置

将 `settings.hook.json` 合并到 `~/.claude/settings.json`，或手动添加：

```json
{
  "hooks": {
    "Stop": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/feishu-notify.sh" }] }],
    "PostToolUse": [{ "matcher": "AskUserQuestion", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/feishu-ask.sh" }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/feishu-ask.sh" }] }]
  }
}
```

### 🔗 选择通道

<details open>
<summary><b>🔌 Webhook 模式 — 零配置，30 秒上线</b></summary>

<br>

飞书群 → 设置 → 群机器人 → 自定义机器人 → 复制 Webhook 地址，编辑脚本顶部：

```bash
FEISHU_WEBHOOK_ASK_URL="https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
FEISHU_WEBHOOK_DONE_URL="https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
```

> ⚠️ Webhook 不支持消息自动删除，其余功能完整。

</details>

<br>

<details>
<summary><b>⚡ API 模式 — 阅后即焚 + 完整控制</b></summary>

<br>

> [!IMPORTANT]
> 需要 [飞书开放平台](https://open.feishu.cn) 创建应用并开启机器人能力。

```bash
FEISHU_APP_ID="cli_xxxxxxxx"
FEISHU_APP_SECRET="xxxxxxxx"
FEISHU_CHAT_ID_ASK="oc_xxxxxxxx"
FEISHU_CHAT_ID_DONE="oc_xxxxxxxx"
FEISHU_DELETE_AFTER_SEC=60   # 0 = 不删除
```

**所需权限**：`im:message:send` `im:message:delete`

</details>

<br>

### ✅ 验证

```bash
echo '{"event":"Stop","session_id":"test","cwd":"/project","model":"deepseek-v4"}' \
  | CLAUDE_TASK="测试消息" bash ~/.claude/hooks/feishu-notify.sh
```

<br>

---

## DONE 卡片内容

<br>

<table>
<tr>
  <td><b>📋 任务</b></td>
  <td>Claude 当前执行的任务描述</td>
  <td><b>📁 目录</b></td>
  <td>项目工作目录</td>
</tr>
<tr>
  <td><b>🤖 模型</b></td>
  <td>当前使用的 AI 模型</td>
  <td><b>⏱️ 耗时</b></td>
  <td>X 分 Y 秒</td>
</tr>
<tr>
  <td><b>🔤 Token</b></td>
  <td>输入 / 缓存写入 / 输出 / 总计</td>
  <td><b>💰 费用</b></td>
  <td>预估 USD 费用</td>
</tr>
<tr>
  <td><b>🆔 会话 ID</b></td>
  <td>唯一会话标识</td>
  <td><b>🔥 自毁</b></td>
  <td>60s 后自动删除（API）</td>
</tr>
</table>

<br>

---

## Hook 覆盖矩阵

| 你看到的 | 触发来源 | Hook 事件 | 卡片 |
|---------|---------|----------|------|
| `Do you want to proceed?` | 权限弹窗 | `Notification` | ASK 黄卡 |
| `是否允许执行 xxx?` | Claude 提问 | `PostToolUse` | ASK 黄卡 |
| 会话结束（有待处理） | Stop + 检测 Prompt | `Stop` | ASK 黄卡 |
| 会话结束（全部完成） | Stop | `Stop` | DONE 绿卡 |

> [!TIP]
> **所有场景全覆盖** — 不会被 Claude 的权限弹窗打断后忘记回来查看。

<br>

---

## 文件结构

```
claude-code-feishu-hook/
├── feishu-notify.sh        # 主脚本 · 路由 + 发送 + 自毁调度
├── feishu-ask.sh            # 包装器 · AskUserQuestion → ASK
├── settings.hook.json       # Hook 配置参考
├── diagram/
│   └── architecture.svg     # 架构流程图
├── assets/
│   └── logo.svg             # 项目 Logo
├── .gitignore
└── README.md
```

<br>

---

## 终端演示

```
$ claude                    # 你在终端输入需求
...
Claude Code 执行中 ...

                         ┌─────────────────────────┐
  💬 飞书群消息 ← ← ←    │  🟢 Claude Code          │
                         │  任务执行完成            │
                         │  📋 重构 auth 模块       │
                         │  🤖 deepseek-v4-pro[1m]  │
                         │  ⏱️ 2分15秒              │
                         │  🔤 输入 12,000 / 输出 3,420 / 总计 15,420 │
                         │  💰 $0.015420           │
                         │  ⏰ 60s 后自动删除       │
                         └─────────────────────────┘
                                          ↓
                                    60 秒后消失 ✨
```

<br>

---

<div align="center">

### ⭐ 觉得有用？给个 Star

**[Star this repo](https://github.com/hxd77/Claude-Code-Feishu-Notify)** · **[Report Bug](https://github.com/hxd77/Claude-Code-Feishu-Notify/issues)** · **[Request Feature](https://github.com/hxd77/Claude-Code-Feishu-Notify/issues)**

<br>

MIT License · Built with Claude Code

</div>
