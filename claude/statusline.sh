#!/bin/bash
input=$(cat)

# CLAUDE_STATUSLINE_DEBUG=1 で入力 JSON を /tmp にダンプし、フィールド調査に使えます
[ -n "$CLAUDE_STATUSLINE_DEBUG" ] && printf '%s\n' "$input" > /tmp/claude-statusline-input.json

# === 入力 JSON から値を取り出す ===
MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')

COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CTX_TOTAL=$(echo "$input" | jq -r '.context_window.total_tokens // 0')

FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

MODE=$(echo "$input" | jq -r '.permission_mode // empty')

# reasoning effort はフィールド名が公式に明記されていないため、よく使われる候補を順に試します
# 値はオブジェクト {"level": "xhigh"} か文字列のどちらでも届くので両方に対応します
EFFORT=$(echo "$input" | jq -r '
  ( .effort // .reasoning_effort // .thinking_effort // .thinking.effort // .thinking // .model.effort // .config.effort )
  | (.level? // .name? // .)
  | if type == "string" then . else empty end
')
[ -z "$EFFORT" ] && EFFORT="${CLAUDE_EFFORT:-}"

# === 色定義 ===
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'
BLUE='\033[34m'; MAGENTA='\033[35m'; DIM='\033[2m'; BOLD='\033[1m'; RESET='\033[0m'
SEP="${DIM}·${RESET}"

# === ヘルパ ===
# 横幅 width のプログレスバーを使用率 pct (0-100) で生成します
bar() {
  local width=$1 pct=$2 color=$3
  local filled=$((pct * width / 100))
  [ "$filled" -gt "$width" ] && filled=$width
  [ "$filled" -lt 0 ] && filled=0
  local empty=$((width - filled))
  local f e
  printf -v f "%${filled}s" ""; f="${f// /█}"
  printf -v e "%${empty}s" ""; e="${e// /░}"
  printf '%b%s%b%s%b' "$color" "$f" "$DIM" "$e" "$RESET"
}

# 使用率に応じた色を返します
color_for_pct() {
  local pct=$1
  if [ "$pct" -ge 90 ]; then printf '%s' "$RED"
  elif [ "$pct" -ge 70 ]; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

# === コンテキスト上限ラベル (1M / 200K) ===
CTX_TOTAL_LABEL=""
if [ "$CTX_TOTAL" -ge 1000000 ]; then
  CTX_TOTAL_LABEL="$((CTX_TOTAL / 1000000))M"
elif [ "$CTX_TOTAL" -ge 1000 ]; then
  CTX_TOTAL_LABEL="$((CTX_TOTAL / 1000))K"
fi

# === Git ===
BRANCH_NAME=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH_NAME=$(git branch --show-current 2>/dev/null)
REMOTE=$(git remote get-url origin 2>/dev/null | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')

# === OSC 8 ハイパーリンク ===
if [ -n "$REMOTE" ]; then
  DIR_LINK="\e]8;;${REMOTE}\a${DIR##*/}\e]8;;\a"
else
  DIR_LINK="${DIR##*/}"
fi
BRANCH_LINK=""
if [ -n "$BRANCH_NAME" ]; then
  if [ -n "$REMOTE" ]; then
    BRANCH_LINK="\e]8;;${REMOTE}/tree/${BRANCH_NAME}\a${BRANCH_NAME}\e]8;;\a"
  else
    BRANCH_LINK="${BRANCH_NAME}"
  fi
fi

# === 各種フォーマット ===
COST_FMT=$(printf '$%.2f' "$COST")
DIFF_FMT="${GREEN}+${ADDED}${RESET}/${RED}-${REMOVED}${RESET}"

# === 1行目: ヘッダー ===
MODEL_LABEL="[$MODEL"
[ -n "$CTX_TOTAL_LABEL" ] && MODEL_LABEL="${MODEL_LABEL}(${CTX_TOTAL_LABEL})"
MODEL_LABEL="${MODEL_LABEL}]"

HEADER="${CYAN}${BOLD}${MODEL_LABEL}${RESET}"
[ -n "$BRANCH_LINK" ] && HEADER="${HEADER} ${SEP} ${GREEN}🌿${RESET} ${BRANCH_LINK}"
HEADER="${HEADER} ${SEP} 📁 ${DIR_LINK}"
if [ "$ADDED" -gt 0 ] || [ "$REMOVED" -gt 0 ]; then
  HEADER="${HEADER} ${SEP} ${DIFF_FMT}"
fi

printf '%b\n' "$HEADER"

# === 2行目: Context ===
CTX_BAR=$(bar 15 "$CTX_PCT" "$(color_for_pct "$CTX_PCT")")
EFFORT_LABEL=""
[ -n "$EFFORT" ] && EFFORT_LABEL=" ${DIM}[${EFFORT}]${RESET}"
printf '%b\n' "${DIM}Context:${RESET} ${CTX_BAR} ${DIM}[${CTX_PCT}%]${RESET}${EFFORT_LABEL} ${SEP} ${YELLOW}${COST_FMT}${RESET}"

# === 3行目: Session (5h レートリミット) ===
if [ -n "$FIVE_H_PCT" ]; then
  S_PCT=$(printf '%.0f' "$FIVE_H_PCT")
  S_BAR=$(bar 15 "$S_PCT" "$(color_for_pct "$S_PCT")")
  S_REMAIN=""
  if [ -n "$FIVE_H_RESET" ]; then
    NOW_EPOCH=$(date +%s)
    DIFF5=$((FIVE_H_RESET - NOW_EPOCH))
    if [ "$DIFF5" -gt 0 ]; then
      SH=$((DIFF5 / 3600))
      SM=$(((DIFF5 % 3600) / 60))
      S_REMAIN=" ${DIM}${SH}h${SM}m${RESET}"
    fi
  fi
  printf '%b\n' "${DIM}Session:${RESET} ${S_BAR} ${DIM}[${S_PCT}%]${RESET}${S_REMAIN}"
fi

# === 4行目: Weekly (7d レートリミット) ===
if [ -n "$SEVEN_D_PCT" ]; then
  W_PCT=$(printf '%.0f' "$SEVEN_D_PCT")
  W_BAR=$(bar 15 "$W_PCT" "$(color_for_pct "$W_PCT")")
  W_REMAIN=""
  if [ -n "$SEVEN_D_RESET" ]; then
    NOW_EPOCH=$(date +%s)
    DIFF7=$((SEVEN_D_RESET - NOW_EPOCH))
    if [ "$DIFF7" -gt 0 ]; then
      RD=$((DIFF7 / 86400))
      RH=$(((DIFF7 % 86400) / 3600))
      RM=$(((DIFF7 % 3600) / 60))
      W_REMAIN=" ${DIM}${RD}d${RH}h${RM}m${RESET}"
    fi
  fi
  printf '%b\n' "${DIM}Weekly: ${RESET} ${W_BAR} ${DIM}[${W_PCT}%]${RESET}${W_REMAIN}"
fi

# === 5行目: パーミッションモード ===
if [ -n "$MODE" ]; then
  printf '%b\n' "${DIM}▶▶ ${MODE} ${DIM}(shift+tab to cycle)${RESET}"
fi
