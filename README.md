# Claude Code → 飞书通知 Hook

Claude Code 会话结束后，自动发送详细摘要到飞书群，支持**阅后即焚**（N 秒后自动删除）。

## 功能

- 🟡 **需要操作** → 黄色卡片（Claude 提问 / 权限确认时触发）
- 🟢 **任务完成** → 绿色卡片（含 Token 用量、耗时、费用）
- 🔥 **阅后即焚** → 消息 N 秒后自动删除（需 API 模式）
- ⬇️ **自动降级** → API 不可用时自动切 Webhook，消息不丢

## 工作原理

两个 Hook 事件覆盖全部场景：

```
AskUserQuestion 工具
  → PostToolUse hook 触发
  → feishu-ask.sh
  → 飞书 ASK 卡片（黄色，需要你操作）

Stop 事件（会话结束）
  → Stop hook 触发
  → feishu-notify.sh 检查 CLAUDE_PERMISSION_PROMPT
    → 有值 → 飞书 ASK 卡片
    → 空值 → 飞书 DONE 卡片（绿色，含 Token / 费用）
```

## 快速开始

### 1. 安装脚本

```bash
mkdir -p ~/.claude/hooks
cp feishu-notify.sh ~/.claude/hooks/
cp feishu-ask.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/feishu-notify.sh ~/.claude/hooks/feishu-ask.sh
```

### 2. 配置 Hook

将 `settings.hook.json` 的内容合并到 `~/.claude/settings.json`：

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/feishu-notify.sh"
          }
        ]
      }
    ]
  }
}
```

### 3. 配置飞书通道（二选一）

#### 方式 A：Webhook（简单，无需应用）

1. 飞书群 → 设置 → 群机器人 → 添加自定义机器人
2. 复制 Webhook 地址
3. 编辑 `~/.claude/hooks/feishu-notify.sh` 顶部：

```bash
FEISHU_WEBHOOK_ASK_URL="https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
FEISHU_WEBHOOK_DONE_URL="https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
```

> 不支持自动删除，其他功能完整。

#### 方式 B：API（完整功能，含阅后即焚）

1. [飞书开放平台](https://open.feishu.cn) → 创建企业自建应用
2. 添加应用能力 → 开启 **机器人**
3. 权限管理 → 添加 `im:message:send` + `im:message:delete`
4. 发布应用，管理员审批
5. 把机器人加入目标飞书群
6. 获取群 chat_id（API 调试台 → `GET /im/v1/chats`）
7. 编辑脚本顶部：

```bash
FEISHU_APP_ID="cli_xxxxxxxxxxxx"
FEISHU_APP_SECRET="xxxxxxxxxxxxxxxx"
FEISHU_CHAT_ID_ASK="oc_xxxxxxxxxxxxxx"
FEISHU_CHAT_ID_DONE="oc_xxxxxxxxxxxxxx"
FEISHU_DELETE_AFTER_SEC=60   # 0 = 不删除
```

### 4. 验证

```bash
echo '{"event":"Stop","session_id":"test","cwd":"/test","model":"test"}' \
  | CLAUDE_TASK="测试" bash ~/.claude/hooks/feishu-notify.sh
```

飞书群收到卡片即为成功。

## 卡片内容

| 字段 | ASK 卡片 | DONE 卡片 |
|------|---------|----------|
| 任务 | ✅ | ✅ |
| 目录 | ✅ | ✅ |
| 模型 | ✅ | ✅ |
| 耗时 | ✅ | ✅ |
| Token 用量 | — | ✅ |
| 预估费用 | — | ✅ |
| 会话 ID | ✅ | ✅ |
| 自动删除倒计时 | ✅ | ✅ |

## 环境要求

- Python 3（标准库，无额外依赖）
- Bash（Linux / macOS / Git Bash / WSL）
- 飞书账号

## License

MIT
