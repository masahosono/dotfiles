#!/bin/bash
# Claude Code 通知用スクリプト
# 第1引数: イベント種別 (notification | stop)
# stdin: Claude Code が渡す JSON（cwd・message を利用）
event="${1:-stop}"

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // "unknown"' 2>/dev/null)
project=$(basename "$cwd")
t=$(date '+%H:%M:%S')

if [ "$event" = "notification" ]; then
  title="⚠️ Claude Code — 入力待ち"
  msg=$(echo "$input" | jq -r '.message // "確認または入力が必要です"' 2>/dev/null)
  body="$t  $msg"
else
  title="✅ Claude Code — 応答完了"
  body="$t"
fi

# プロジェクト名をサブタイトル、時刻（と入力待ちメッセージ）を本文に表示
osascript \
  -e 'on run argv' \
  -e 'display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv)' \
  -e 'end run' \
  "$body" "$title" "$project" 2>/dev/null || true

# 通知音は iOS の "Note" (ToneLibrary.framework)。.m4r は osascript の sound name では鳴らせないので afplay で直接再生する。
afplay "/System/Library/PrivateFrameworks/ToneLibrary.framework/Versions/A/Resources/AlertTones/Modern/Note.m4r" >/dev/null 2>&1 &

# WezTerm のタブインジケータを点灯させるため BEL を controlling TTY に送る
printf '\a' > /dev/tty 2>/dev/null || true
