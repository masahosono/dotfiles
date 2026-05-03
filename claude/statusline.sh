#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CYAN='\033[36m'; GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; DIM='\033[2m'; RESET='\033[0m'
SEP="${DIM}·${RESET}"

# コンテキスト使用状況に基づいてバーの色を選択します
if [ "$PCT" -ge 90 ]; then BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10)); EMPTY=$((10 - FILLED))
printf -v FILL "%${FILLED}s"; printf -v PAD "%${EMPTY}s"
BAR="${FILL// /█}${PAD// /░}"

# Git
BRANCH_NAME=""
git rev-parse --git-dir > /dev/null 2>&1 && BRANCH_NAME=$(git branch --show-current 2>/dev/null)

# Cost
COST_FMT=$(printf '$%.2f' "$COST")

# Rate limits
FIVE_H_PCT=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
FIVE_H_RESET=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_D_PCT=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
SEVEN_D_RESET=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

RATE_LIMIT_STR=""
if [ -n "$FIVE_H_PCT" ]; then
  FIVE_H_PCT_INT=$(printf '%.0f' "$FIVE_H_PCT")
  NOW=$(date +%s)
  RESET_STR=""
  if [ -n "$FIVE_H_RESET" ]; then
    DIFF=$((FIVE_H_RESET - NOW))
    if [ "$DIFF" -gt 0 ]; then
      RESET_H=$((DIFF / 3600))
      RESET_M=$(((DIFF % 3600) / 60))
      if [ "$RESET_H" -gt 0 ]; then
        RESET_STR=" (${RESET_H}h ${RESET_M}m)"
      else
        RESET_STR=" (${RESET_M}m)"
      fi
    fi
  fi
  RATE_LIMIT_STR="5h: ${FIVE_H_PCT_INT}%${RESET_STR}"
  if [ -n "$SEVEN_D_PCT" ]; then
    SEVEN_D_PCT_INT=$(printf '%.0f' "$SEVEN_D_PCT")
    SEVEN_D_RESET_STR=""
    if [ -n "$SEVEN_D_RESET" ]; then
      DIFF7=$((SEVEN_D_RESET - NOW))
      if [ "$DIFF7" -gt 0 ]; then
        RESET7_D=$((DIFF7 / 86400))
        RESET7_H=$(((DIFF7 % 86400) / 3600))
        RESET7_M=$(((DIFF7 % 3600) / 60))
        if [ "$RESET7_D" -gt 0 ]; then
          SEVEN_D_RESET_STR=" (${RESET7_D}d ${RESET7_H}h)"
        elif [ "$RESET7_H" -gt 0 ]; then
          SEVEN_D_RESET_STR=" (${RESET7_H}h ${RESET7_M}m)"
        else
          SEVEN_D_RESET_STR=" (${RESET7_M}m)"
        fi
      fi
    fi
    RATE_LIMIT_STR="${RATE_LIMIT_STR} ${SEP} 7d: ${SEVEN_D_PCT_INT}%${SEVEN_D_RESET_STR}"
  fi
fi

# GitHub リポジトリ・ブランチへのクリック可能なリンク (OSC 8)
REMOTE=$(git remote get-url origin 2>/dev/null | sed 's/git@github.com:/https:\/\/github.com\//' | sed 's/\.git$//')
if [ -n "$REMOTE" ]; then
  DIR_LINK="\e]8;;${REMOTE}\a${DIR##*/}\e]8;;\a"
else
  DIR_LINK="${DIR##*/}"
fi

BRANCH=""
if [ -n "$BRANCH_NAME" ]; then
  if [ -n "$REMOTE" ]; then
    BRANCH=" ${SEP} \e]8;;${REMOTE}/tree/${BRANCH_NAME}\a${BRANCH_NAME}\e]8;;\a"
  else
    BRANCH=" ${SEP} ${BRANCH_NAME}"
  fi
fi

# Prompt
printf '%b\n' "${CYAN}[$MODEL]${RESET} ${SEP} ${DIR_LINK}$BRANCH"
if [ -n "$RATE_LIMIT_STR" ]; then
  echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% ${SEP} ${YELLOW}${COST_FMT}${RESET} ${SEP} $RATE_LIMIT_STR"
else
  echo -e "${BAR_COLOR}${BAR}${RESET} ${PCT}% ${SEP} ${YELLOW}${COST_FMT}${RESET}"
fi
