<div align="center">

<img src="diagram/architecture.svg" alt="Architecture" width="100%"/>

# Claude Code → 飞书通知 Hook

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python](https://img.shields.io/badge/Python-3.7+-blue?logo=python&logoColor=white)](https://www.python.org/)
[![Bash](https://img.shields.io/badge/Bash-4.0+-4EAA25?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Feishu](https://img.shields.io/badge/Feishu-API-3370FF?logo=feishu&logoColor=white)](https://open.feishu.cn)
[![Platform](https://img.shields.io/badge/Platform-Win%20%7C%20Mac%20%7C%20Linux-lightgrey)]()

**Claude Code 会话结束 → 飞书群实时卡片 → 60 秒后自动消失**

</div>

---

## 能做什么

<table>
<tr>
<td width="50%">

### 🟡 需要你操作

Claude Code 弹出权限确认 / 主动提问时，飞书群**立刻**收到黄色提醒卡片

> *"回到终端，Claude 在等你"*

</td>
<td width="50%">

###  任务完成

会话结束后推送绿色摘要卡片，包含完整用量数据

> *Token / 耗时 / 费用一目了然*

</td>
</tr>
</table>

### 🔥 阅后即焚

API 模式下，消息在 **60 秒后自动删除**——需要时看得见，不需要时不占屏幕。

---

## 快速开始

### 1. 安装

```bash
mkdir -p ~/.claude/hooks
cp feishu-notify.sh feishu-ask.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/feishu-notify.sh ~/.claude/hooks/feishu-ask.sh
```

### 2. 配置 Hook

把 `settings.hook.json` 合并到 `~/.claude/settings.json`（或手动添加 hooks 区块）。

### 3. 选择发送模式

<details open>
<summary><b>🔌 模式 A：Webhook（30 秒搞定）</b></summary>

飞书群 → 设置 → 群机器人 → 添加自定义机器人 → 复制地址，填入脚本：

```bash
FEISHU_WEBHOOK_ASK_URL="https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
FEISHU_WEBHOOK_DONE_URL="https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
```

> ⚠️ 不支持自动删除，其他功能完整。

</details>

<details>
<summary><b>⚡ 模式 B：API（完整功能 + 阅后即焚）</b></summary>

1. [飞书开放平台](https://open.feishu.cn) → 创建企业自建应用
2. 添加 **机器人** 能力 + 权限 `im:message:send` `im:message:delete`
3. 发布 → 审批 → 机器人拉入目标群
4. 获取 `chat_id`（API 调试台 → `GET /im/v1/chats`）
5. 填入脚本：

```bash
FEISHU_APP_ID="cli_xxxxxxxx"
FEISHU_APP_SECRET="xxxxxxxx"
FEISHU_CHAT_ID_ASK="oc_xxxxxxxx"
FEISHU_CHAT_ID_DONE="oc_xxxxxxxx"
FEISHU_DELETE_AFTER_SEC=60
```

</details>

### 4. 验证

```bash
echo '{"event":"Stop","session_id":"test","cwd":"/project","model":"test"}' \
  | CLAUDE_TASK="测试消息" bash ~/.claude/hooks/feishu-notify.sh
```

飞书群收到卡片即为成功。

---

## DONE 卡片详情

| 字段 | 说明 |
|------|------|
| 📋 任务 | Claude 当前执行的任务描述 |
| 📁 目录 | 项目工作目录 |
| 🤖 模型 | 使用的 AI 模型名称 |
| ⏱️ 耗时 | 任务执行时长（分/秒） |
| 🔤 Token | 输入 / 缓存写入 / 输出 / 总计 |
| 💰 费用 | 预估 USD 费用 |
| 🆔 会话 ID | 当前会话唯一标识 |
| 🔥 自毁 | 60s 倒计时后自动删除（API 模式） |

---

## Hook 覆盖矩阵

| 触发场景 | Hook 事件 | 飞书卡片 |
|---------|----------|---------|
| 权限确认弹窗 | `Notification` | ASK |
| Claude 主动提问 | `PostToolUse` (AskUserQuestion) | ASK |
| 会话结束（有等待） | `Stop` + 检测 Prompt | ASK |
| 会话结束（已完成） | `Stop` + 无 Prompt | DONE |

---

## 项目结构

```
.
├── feishu-notify.sh      # 主脚本：双通道路由 + API/Webhook 自动降级
├── feishu-ask.sh          # 包装器：AskUserQuestion / Notification → ASK 通道
├── settings.hook.json     # Hook 配置（合并到 ~/.claude/settings.json）
├── diagram/
│   └── architecture.svg  # 架构流程图
└── .gitignore
```

---

## 环境要求

- Python 3（标准库，零依赖）
- Bash（Linux / macOS / Git Bash / WSL）
- 飞书账号

---

<div align="center">

**MIT License** · Made with Claude Code

</div>
