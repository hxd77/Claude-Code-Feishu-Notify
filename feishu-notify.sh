#!/usr/bin/env bash
# ============================================================
# Claude Code Stop Hook — 飞书双通道通知 + 阅后即焚
#
# GitHub: https://github.com/YOUR_USERNAME/claude-code-feishu-hook
#
# 两种发送模式（自动降级）：
#   API 模式：配置了 APP_ID/APP_SECRET → 发消息 + N 秒后自动删除
#   Webhook 模式：未配置 API → 退化为普通 webhook（不支持删除）
#
# 两个场景，两个通道：
#   ASK  → Claude 需要你操作（提问 / 权限确认）
#   DONE → 所有任务完成
# ============================================================

# ========== 飞书 API 配置（用于发消息 + 自动删除） ==========
# 获取方式：open.feishu.cn → 创建应用 → 应用凭证
FEISHU_APP_ID=""
FEISHU_APP_SECRET=""
# 目标群 chat_id（oc_ 开头），两个可以填同一个群
FEISHU_CHAT_ID_ASK=""
FEISHU_CHAT_ID_DONE=""
# 消息自动删除倒计时（秒），0 = 不删除
FEISHU_DELETE_AFTER_SEC=60
# ============================================================

# ========== Webhook 降级配置（API 未配时才生效） ==========
# 飞书群 → 群设置 → 群机器人 → 添加自定义机器人 → 复制 webhook
FEISHU_WEBHOOK_ASK_URL=""
FEISHU_WEBHOOK_DONE_URL=""
# ============================================================

INPUT_JSON=$(cat - 2>/dev/null || echo '{}')

PYTHON=""
for py in python python3; do
    if command -v "$py" >/dev/null 2>&1 && "$py" --version >/dev/null 2>&1; then
        PYTHON="$py"
        break
    fi
done
if [ -z "$PYTHON" ]; then
    echo '[feishu-notify] 未找到 Python，跳过发送'
    exit 0
fi

"$PYTHON" - "$INPUT_JSON" "$CLAUDE_TASK" "$CLAUDE_PERMISSION_PROMPT" \
    "$FEISHU_APP_ID" "$FEISHU_APP_SECRET" \
    "$FEISHU_CHAT_ID_ASK" "$FEISHU_CHAT_ID_DONE" \
    "$FEISHU_DELETE_AFTER_SEC" \
    "$FEISHU_WEBHOOK_ASK_URL" "$FEISHU_WEBHOOK_DONE_URL" <<'PYEOF'
import json, os, sys, urllib.request, urllib.error, datetime, traceback, subprocess, time

input_json   = sys.argv[1]  if len(sys.argv) > 1  else '{}'
claude_task  = sys.argv[2]  if len(sys.argv) > 2  else ''
claude_prompt= sys.argv[3]  if len(sys.argv) > 3  else ''
app_id       = sys.argv[4]  if len(sys.argv) > 4  else ''
app_secret   = sys.argv[5]  if len(sys.argv) > 5  else ''
chat_id_ask  = sys.argv[6]  if len(sys.argv) > 6  else ''
chat_id_done = sys.argv[7]  if len(sys.argv) > 7  else ''
delete_sec   = int(sys.argv[8]) if len(sys.argv) > 8 and sys.argv[8].isdigit() else 0
webhook_ask  = sys.argv[9]  if len(sys.argv) > 9  else ''
webhook_done = sys.argv[10] if len(sys.argv) > 10 else ''

try:
    ctx = json.loads(input_json)
except Exception:
    ctx = {}

event          = ctx.get('event', 'Stop')
session_id     = ctx.get('session_id', '')[:16] or 'N/A'
cwd            = ctx.get('cwd', os.getcwd())
model          = ctx.get('model', 'N/A')
total_tokens   = ctx.get('total_tokens', 0) or 0
input_tokens   = ctx.get('input_tokens', 0) or 0
output_tokens  = ctx.get('output_tokens', 0) or 0
cache_tokens   = ctx.get('cache_creation_input_tokens', 0) or 0
cost           = ctx.get('total_cost_usd', 0) or 0
duration_ms    = ctx.get('duration_ms', 0) or 0

is_asking = bool(claude_prompt)
use_api   = bool(app_id and app_secret)

if is_asking:
    target_webhook = webhook_ask
    target_chat_id = chat_id_ask
    status_text = "\U0001f7e1 Claude Code — 需要你的操作"
    status_color = "yellow"
    task_display = claude_prompt[:80] or claude_task or '待处理'
else:
    target_webhook = webhook_done
    target_chat_id = chat_id_done
    status_text = "\U0001f7e2 Claude Code — 任务执行完成"
    status_color = "green"
    task_display = claude_task or '会话结束'

if duration_ms:
    secs = duration_ms / 1000
    if secs >= 60:
        mins, remain = divmod(int(secs), 60)
        duration_str = f"{mins}分{remain}秒"
    else:
        duration_str = f"{secs:.0f}秒"
else:
    duration_str = 'N/A'

cost_str = f"${cost:.6f}" if cost else 'N/A'

if total_tokens:
    parts = []
    if input_tokens:   parts.append(f"输入 {input_tokens:,}")
    if cache_tokens:   parts.append(f"缓存写入 {cache_tokens:,}")
    if output_tokens:  parts.append(f"输出 {output_tokens:,}")
    parts.append(f"**总计 {total_tokens:,}**")
    token_str = " / ".join(parts)
else:
    token_str = 'N/A'

if len(cwd) > 60:
    cwd = '...' + cwd[-57:]

elements = []
if is_asking:
    elements.append({
        "tag": "markdown",
        "content": "Claude Code 正在等待你的操作。请回到终端查看并处理。"
    })
    elements.append({"tag": "hr"})

elements.append({
    "tag": "div",
    "fields": [
        {"is_short": True, "text": {"tag": "lark_md", "content": f"**\U0001f4cb 任务**\n{task_display}"}},
        {"is_short": True, "text": {"tag": "lark_md", "content": f"**\U0001f4c1 目录**\n{cwd}"}}
    ]
})
elements.append({
    "tag": "div",
    "fields": [
        {"is_short": True, "text": {"tag": "lark_md", "content": f"**\U0001f916 模型**\n{model}"}},
        {"is_short": True, "text": {"tag": "lark_md", "content": f"**⏱️ 耗时**\n{duration_str}"}}
    ]
})
if not is_asking:
    elements.append({
        "tag": "div",
        "fields": [
            {"is_short": True, "text": {"tag": "lark_md", "content": f"**\U0001f524 Token**\n{token_str}"}},
            {"is_short": True, "text": {"tag": "lark_md", "content": f"**\U0001f4b0 费用**\n{cost_str}"}}
        ]
    })
elements.append({
    "tag": "div",
    "fields": [
        {"is_short": False, "text": {"tag": "lark_md", "content": f"**\U0001f194 会话 ID**\n`{session_id}`"}}
    ]
})

t = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
footer_text = f"⏰ {t}  ·  Claude Code Hook"
if use_api and delete_sec > 0:
    footer_text += f"  ·  {delete_sec}s 后自动删除"

elements.append({"tag": "hr"})
elements.append({
    "tag": "note",
    "elements": [{"tag": "plain_text", "content": footer_text}]
})

card = {
    "msg_type": "interactive",
    "card": {
        "header": {
            "title": {"tag": "plain_text", "content": status_text},
            "template": status_color
        },
        "elements": elements
    }
}

def http_post(url, data, headers=None, timeout=10):
    if headers is None:
        headers = {}
    if isinstance(data, dict):
        data = json.dumps(data, ensure_ascii=False).encode('utf-8')
    headers.setdefault('Content-Type', 'application/json; charset=utf-8')
    req = urllib.request.Request(url, data=data, headers=headers, method='POST')
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode('utf-8'))

def spawn_delete_child(message_id, token, delay_sec):
    code = f'''
import time, urllib.request, json, sys
time.sleep({delay_sec})
url = "https://open.feishu.cn/open-apis/im/v1/messages/{message_id}"
req = urllib.request.Request(url, method="DELETE")
req.add_header("Authorization", "Bearer {token}")
try:
    with urllib.request.urlopen(req, timeout=10) as r:
        pass
except Exception as e:
    pass
'''
    kwargs = dict(
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        stdin=subprocess.DEVNULL, close_fds=True
    )
    if sys.platform == 'win32':
        kwargs['creationflags'] = 0x00000008
    else:
        kwargs['start_new_session'] = True
    subprocess.Popen([sys.executable, '-c', code], **kwargs)

if use_api:
    target_chat = target_chat_id or chat_id_done or chat_id_ask
    if not target_chat:
        print('[feishu-notify] FEISHU_CHAT_ID 未配置，回退到 webhook')
        use_api = False
    else:
        try:
            token_url = 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal'
            token_resp = http_post(token_url, {
                'app_id': app_id,
                'app_secret': app_secret
            }, timeout=10)
            access_token = token_resp.get('tenant_access_token', '')
            if not access_token:
                raise Exception(f'get token failed: {token_resp}')

            msg_url = ('https://open.feishu.cn/open-apis/im/v1/messages'
                       '?receive_id_type=chat_id')
            msg_resp = http_post(msg_url, {
                'receive_id': target_chat,
                'msg_type': 'interactive',
                'content': json.dumps(card['card'], ensure_ascii=False)
            }, headers={'Authorization': f'Bearer {access_token}'}, timeout=10)

            message_id = msg_resp.get('data', {}).get('message_id', '')
            if message_id:
                print(f'[feishu-notify] API sent, message_id={message_id}')
                if delete_sec > 0:
                    spawn_delete_child(message_id, access_token, delete_sec)
                    print(f'[feishu-notify] scheduled delete in {delete_sec}s')
            else:
                print(f'[feishu-notify] no message_id in response: {msg_resp}')

        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8', errors='replace')
            print(f'[feishu-notify] API error {e.code}: {body}')
            use_api = False
        except Exception as e:
            print(f'[feishu-notify] API failed: {e}')
            use_api = False

if not use_api:
    if not target_webhook:
        tag = 'ASK' if is_asking else 'DONE'
        print(f'[feishu-notify] FEISHU_WEBHOOK_{tag}_URL not set, skip')
        sys.exit(0)

    try:
        resp = http_post(target_webhook, card, timeout=10)
        print(f'[feishu-notify] Webhook sent: {resp}')
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        print(f'[feishu-notify] Webhook error {e.code}: {body}')
    except Exception as e:
        print(f'[feishu-notify] Webhook failed: {e}')
        traceback.print_exc()
PYEOF
