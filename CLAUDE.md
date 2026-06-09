# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

個人の dotfiles 管理リポジトリ。Neovim、WezTerm、Zed、Cursor、zsh、inshellisense、Claude Code の設定を管理している。

## セットアップ

```bash
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/wezterm ~/.config/wezterm
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense
mkdir -p ~/.config/zed
ln -sf ~/dotfiles/zed/settings.json ~/.config/zed/settings.json
ln -sf ~/dotfiles/zed/keymap.json ~/.config/zed/keymap.json
# Cursor (macOS。パスにスペースが含まれるため必ずクオートする)
ln -sf ~/dotfiles/cursor/settings.json "$HOME/Library/Application Support/Cursor/User/settings.json"
ln -sf ~/dotfiles/cursor/keybindings.json "$HOME/Library/Application Support/Cursor/User/keybindings.json"
ln -sf ~/dotfiles/zsh/.zshconfig ~/.zshconfig
ln -sf ~/dotfiles/zsh/.zshprompt ~/.zshprompt
# ~/.zshrc は環境ごとに各自作成し、上記2ファイルを source する
# PATH・エイリアス等の環境依存設定は ~/.zshrc に直接書く
# Claude Code 設定
mkdir -p ~/.claude/output-styles
ln -sf ~/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -sf ~/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/dotfiles/claude/notify.sh ~/.claude/notify.sh
ln -sf ~/dotfiles/claude/output-styles/amadeus.md ~/.claude/output-styles/amadeus.md
ln -sf ~/dotfiles/claude/output-styles/rockman-exe.md ~/.claude/output-styles/rockman-exe.md
```

プラグインは Neovim 初回起動時に lazy.nvim が自動インストールする。

## Neovim 設定のアーキテクチャ

`nvim/` 以下の構成:

- `init.lua` — エントリポイント。Leader キー(Space)の設定、lazy.nvim のブートストラップ、`lua/config/` と `lua/plugins/` の読み込み
- `lua/config/options.lua` — エディタ設定(2スペースインデント、スマートケース検索、macOS クリップボード連携など)
- `lua/config/keymaps.lua` — キーバインド定義
- `lua/config/autocmds.lua` — 自動コマンド(ヤンクハイライト、カーソル位置復元、末尾スペース除去)
- `lua/plugins/*.lua` — 各プラグインの lazy.nvim スペック(colorscheme, telescope, neo-tree, lualine, treesitter, editing, git)
- `lazy-lock.json` — プラグインのバージョンロックファイル

## 設定変更時の注意

- プラグインを追加・変更する場合は `lua/plugins/` に個別ファイルとして配置する（lazy.nvim が自動で読み込む）
- `lazy-lock.json` は lazy.nvim が自動管理するため、手動編集しない
- キーマップの名前空間: `Leader+f` = Telescope, `Leader+e/o` = Neo-tree, `Leader+g` = Git 操作

## zsh 設定

`zsh/` 以下の構成:

- `.zshconfig` — 補完・シェルオプション・ヒストリー・キーバインド・TIMEFMT などの汎用的な対話設定
- `.zshprompt` — プロンプト表示（`vcs_info` を使った Git ブランチ表示、GitHub リモートのリンク化を含む）

`~/.zshrc` 本体は dotfiles 管理対象外。環境ごとに各自作成し、その中で次のように source する想定:

```zsh
[[ -f ~/.zshconfig ]] && source ~/.zshconfig
[[ -f ~/.zshprompt ]] && source ~/.zshprompt
```

PATH 設定、エイリアスその他の環境依存設定は各自の `~/.zshrc` に直接書く。

## WezTerm 設定

`wezterm/` 以下の構成:

- `wezterm.lua` — メイン設定ファイル（ウィンドウサイズ、フォントサイズ、カラースキームなど）

## Zed 設定

`zed/` 以下の構成:

- `settings.json` — Zed エディタの設定ファイル（テーマ、フォント、ターミナル、エージェント等）
- `keymap.json` — キーバインド定義

`~/.config/zed` 配下には `prompts/`（内部 DB）など自動生成されるファイルがあるため、ディレクトリごとリンクせず管理対象のファイル単位でシンボリックリンクを張る方針。

## Cursor 設定

`cursor/` 以下の構成:

- `settings.json` — Cursor のユーザー設定（テーマ、ターミナル、Cursor 固有のフラグ等）。VS Code フォークのため JSONC
- `keybindings.json` — キーバインド定義（VS Code 互換）

`~/Library/Application Support/Cursor/User/` 配下には `globalStorage/`・`History/`・`workspaceStorage/`・`snapshots/` などセッション履歴やキャッシュが含まれるため、ディレクトリごとリンクせずファイル単位でシンボリックリンクを張る方針。

`~/.cursor/mcp.json` には API キーが含まれる可能性があるため dotfiles 管理対象外。拡張機能本体（`~/.cursor/extensions/`）もマシン依存・バイナリ込みで肥大化するため管理しない。

macOS 限定パス。Linux なら `~/.config/Cursor/User/`、Windows なら `%APPDATA%\Cursor\User\` に差し替える必要がある。

## inshellisense 設定

`inshellisense/` 以下の構成:

- `rc.toml` — inshellisense の設定ファイル（エイリアス利用、Nerd Font、補完候補数など）

## Claude Code 設定

`claude/` 以下の構成:

- `settings.json` — Claude Code のグローバル設定（permissions / model / hooks / statusLine 等）
- `statusline.sh` — ステータスライン用シェルスクリプト。`settings.json` の `statusLine.command` から参照される
- `notify.sh` — 通知用シェルスクリプト。`settings.json` の `hooks.Notification` / `hooks.Stop` から参照される
- `output-styles/amadeus.md` — カスタム output style（アマデウス／AI 牧瀬紅莉栖口調）
- `output-styles/rockman-exe.md` — カスタム output style（ロックマン.EXE 口調）

`~/.claude` 配下にはセッション履歴やキャッシュなど自動生成されるファイルが多いため、ディレクトリごとリンクせず、管理対象のファイル単位でシンボリックリンクを張る方針。
