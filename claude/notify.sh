#!/bin/bash
# Claude Code 通知用スクリプト
# 第1引数: イベント種別 (notification | stop)
event="${1:-stop}"

if [ "$event" = "notification" ]; then
  title="🙋 Claude Code - 入力待ち"
else
  title="✅ Claude Code - 完了"
fi

osascript -e "display notification \"\" with title \"$title\" sound name \"Glass\""

# WezTerm のタブインジケータを点灯させるため BEL を controlling TTY に送る
printf '\a' > /dev/tty 2>/dev/null || true
