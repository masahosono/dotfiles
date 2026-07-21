#!/bin/bash
# herdr.app を生成する。
#
# 中身は /Applications/WezTerm.app の複製 (arm64 thin)。
#   - アイコンを herdr.icns に差し替え
#   - CFBundleName / CFBundleIdentifier を herdr に変更
#   - LSEnvironment で WEZTERM_CONFIG_FILE を wezterm_herdr.lua に固定
#     (herdr.app は ~/.config/wezterm/wezterm.lua の symlink 先に関係なく常に herdr 専用モード)
#   - Info.plist を書き換えるため ad-hoc で再署名
#
# 使い方: bash make.sh [出力先.app]   (省略時 /Applications/herdr.app)
# WezTerm.app を更新したら再実行すること。
set -euo pipefail

SRC="/Applications/WezTerm.app"
DST="${1:-/Applications/herdr.app}"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ICNS="$REPO_ROOT/herdr/app/herdr.icns"
# LSEnvironment は $HOME を展開しないため、ここで絶対パスに解決して埋め込む
CONFIG="$REPO_ROOT/wezterm/wezterm_herdr.lua"

[[ -d "$SRC" ]] || { echo "NG: WezTerm.app が見つからない: $SRC" >&2; exit 1; }
[[ -f "$ICNS" ]] || { echo "NG: アイコンが見つからない: $ICNS" >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "NG: 設定が見つからない: $CONFIG" >&2; exit 1; }
if pgrep -qf "herdr.app/Contents/MacOS/wezterm-gui"; then
  echo "NG: herdr.app が起動中。終了してから再実行すること" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# universal binary を arm64 だけに間引きつつ複製
ditto --arch arm64 "$SRC" "$WORK/herdr.app"

cp "$ICNS" "$WORK/herdr.app/Contents/Resources/terminal.icns"

PLIST="$WORK/herdr.app/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
"$PB" -c "Set :CFBundleIdentifier com.masahosono.herdr" "$PLIST"
"$PB" -c "Set :CFBundleName herdr" "$PLIST"
"$PB" -c "Add :CFBundleDisplayName string herdr" "$PLIST" 2>/dev/null ||
  "$PB" -c "Set :CFBundleDisplayName herdr" "$PLIST"
"$PB" -c "Add :LSEnvironment dict" "$PLIST" 2>/dev/null || true
"$PB" -c "Add :LSEnvironment:WEZTERM_CONFIG_FILE string $CONFIG" "$PLIST" 2>/dev/null ||
  "$PB" -c "Set :LSEnvironment:WEZTERM_CONFIG_FILE $CONFIG" "$PLIST"

# 拡張属性が残っていると codesign が detritus エラーで落ちるため除去
xattr -cr "$WORK/herdr.app"

# Info.plist 書き換えで元の署名が無効になるため ad-hoc で再署名
codesign --force --deep --sign - "$WORK/herdr.app"

rm -rf "$DST"
ditto "$WORK/herdr.app" "$DST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DST" >/dev/null

echo "OK: $DST を生成した"
