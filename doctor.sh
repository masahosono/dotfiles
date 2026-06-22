#!/bin/bash
# dotfiles doctor — セットアップ手順 (CLAUDE.md / README.md) のシンボリックリンクが
# 正しく張られているかを検証する。
#
# 使い方:
#   bash ~/dotfiles/doctor.sh

set -u

# このスクリプト自身の位置を基準にして dotfiles ディレクトリを特定する。
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for arg in "$@"; do
  case "$arg" in
    -h|--help)
      sed -n '2,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$arg" >&2
      exit 2
      ;;
  esac
done

# 端末対応していれば色を付ける。
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
  C_OK="$(tput setaf 2)"
  C_NG="$(tput setaf 1)"
  C_WARN="$(tput setaf 3)"
  C_DIM="$(tput dim)"
  C_RESET="$(tput sgr0)"
else
  C_OK=""; C_NG=""; C_WARN=""; C_DIM=""; C_RESET=""
fi

PASS=0
FAIL=0
WARN=0

log_ok()   { printf '  %sOK%s   %s\n' "$C_OK" "$C_RESET" "$1"; }
log_ng()   { printf '  %sNG%s   %s\n' "$C_NG" "$C_RESET" "$1"; [ -n "${2:-}" ] && printf '       %s%s%s\n' "$C_DIM" "$2" "$C_RESET"; }
log_warn() { printf '  %sWARN%s %s\n' "$C_WARN" "$C_RESET" "$1"; [ -n "${2:-}" ] && printf '       %s%s%s\n' "$C_DIM" "$2" "$C_RESET"; }

section() { printf '\n%s\n' "$1"; }

# $1: シンボリックリンクのパス
# $2: 期待するリンク先(dotfiles 内の絶対パス)
check_symlink() {
  local link="$1"
  local expected="$2"
  local label="${link/#$HOME/~}"

  if [ ! -e "$expected" ] && [ ! -L "$expected" ]; then
    log_warn "$label" "リンク先 $expected が dotfiles 内に存在しません(手順 or リポジトリ不整合)"
    WARN=$((WARN + 1))
    return
  fi

  if [ ! -L "$link" ]; then
    if [ -e "$link" ]; then
      log_ng "$label" "シンボリックリンクではなく実体ファイル/ディレクトリが存在します"
    else
      log_ng "$label" "存在しません (期待: -> $expected)"
    fi
    FAIL=$((FAIL + 1))
    return
  fi

  local actual
  actual="$(readlink "$link")"
  if [ "$actual" != "$expected" ]; then
    log_ng "$label" "リンク先が期待と異なります (期待: $expected / 実際: $actual)"
    FAIL=$((FAIL + 1))
    return
  fi

  # readlink はそのまま返すだけなので、リンク先が実在するかも確認する。
  if [ ! -e "$link" ]; then
    log_ng "$label" "リンクは張られていますが、リンク先 $actual が存在しません(リンク切れ)"
    FAIL=$((FAIL + 1))
    return
  fi

  log_ok "$label"
  PASS=$((PASS + 1))
}

section "Neovim / WezTerm / inshellisense"
check_symlink "$HOME/.config/nvim"           "$DOTFILES_DIR/nvim"
check_symlink "$HOME/.config/wezterm"        "$DOTFILES_DIR/wezterm"
check_symlink "$HOME/.config/inshellisense"  "$DOTFILES_DIR/inshellisense"

section "Zed"
check_symlink "$HOME/.config/zed/settings.json" "$DOTFILES_DIR/zed/settings.json"
check_symlink "$HOME/.config/zed/keymap.json"   "$DOTFILES_DIR/zed/keymap.json"
check_symlink "$HOME/.config/zed/tasks.json"    "$DOTFILES_DIR/zed/tasks.json"

section "Cursor (macOS)"
if [ "$(uname -s)" = "Darwin" ]; then
  CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
  check_symlink "$CURSOR_USER_DIR/settings.json"    "$DOTFILES_DIR/cursor/settings.json"
  check_symlink "$CURSOR_USER_DIR/keybindings.json" "$DOTFILES_DIR/cursor/keybindings.json"
else
  log_warn "Cursor" "macOS 以外の OS のため Cursor のチェックはスキップします"
  WARN=$((WARN + 1))
fi

section "zsh"
check_symlink "$HOME/.zshconfig" "$DOTFILES_DIR/zsh/.zshconfig"
check_symlink "$HOME/.zshprompt" "$DOTFILES_DIR/zsh/.zshprompt"
check_symlink "$HOME/.zshalias"  "$DOTFILES_DIR/zsh/.zshalias"

# ~/.zshrc は dotfiles 管理対象外だが、3 つの設定ファイルを source していないと反映されない。
if [ -f "$HOME/.zshrc" ]; then
  missing=()
  for f in .zshconfig .zshprompt .zshalias; do
    if ! grep -qE "source[[:space:]]+.*$f|\\.[[:space:]]+.*$f" "$HOME/.zshrc"; then
      missing+=("$f")
    fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then
    log_ok "~/.zshrc が .zshconfig / .zshprompt / .zshalias を source している"
    PASS=$((PASS + 1))
  else
    log_warn "~/.zshrc" "次のファイルを source していない可能性があります: ${missing[*]}"
    WARN=$((WARN + 1))
  fi
else
  log_warn "~/.zshrc" "存在しません。環境ごとに各自作成し .zshconfig / .zshprompt / .zshalias を source してください"
  WARN=$((WARN + 1))
fi

section "Claude Code"
check_symlink "$HOME/.claude/statusline.sh"  "$DOTFILES_DIR/claude/statusline.sh"
check_symlink "$HOME/.claude/settings.json"  "$DOTFILES_DIR/claude/settings.json"
check_symlink "$HOME/.claude/notify.sh"      "$DOTFILES_DIR/claude/notify.sh"

# output-styles 配下は dotfiles/claude/output-styles に存在するファイル全てを対象にする。
if [ -d "$DOTFILES_DIR/claude/output-styles" ]; then
  for src in "$DOTFILES_DIR/claude/output-styles"/*.md; do
    [ -e "$src" ] || continue
    name="$(basename "$src")"
    check_symlink "$HOME/.claude/output-styles/$name" "$src"
  done
fi

check_symlink "$HOME/.claude/skills/output-style" "$DOTFILES_DIR/claude/skills/output-style"

# サマリ
TOTAL=$((PASS + FAIL + WARN))
section "結果"
printf '  合計: %d  |  %sOK%s: %d  |  %sNG%s: %d  |  %sWARN%s: %d\n' \
  "$TOTAL" "$C_OK" "$C_RESET" "$PASS" "$C_NG" "$C_RESET" "$FAIL" "$C_WARN" "$C_RESET" "$WARN"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
