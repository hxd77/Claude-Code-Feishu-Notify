#!/usr/bin/env bash
# PostToolUse AskUserQuestion → ASK 通知
# 当 Claude Code 使用 AskUserQuestion 工具时，PostToolUse hook 触发此脚本
CONTEXT=$(cat -)
export CLAUDE_PERMISSION_PROMPT="AskUserQuestion"
echo "$CONTEXT" | bash ~/.claude/hooks/feishu-notify.sh
