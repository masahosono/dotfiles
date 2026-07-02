# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

個人の dotfiles 管理リポジトリ。Neovim、WezTerm、Ghostty、herdr、Zed、Cursor、zsh、inshellisense、Claude Code の設定を管理している。

## セットアップ

```bash
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/wezterm ~/.config/wezterm
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense
# carapace (XDG_CONFIG_HOME=~/.config の設定が前提。zsh/.zshconfig で export している)
ln -sf ~/dotfiles/carapace ~/.config/carapace
# Ghostty (~/.config/ghostty が存在しない場合は先に作成)
mkdir -p ~/.config/ghostty
ln -sf ~/dotfiles/ghostty/config ~/.config/ghostty/config
ln -sf ~/dotfiles/ghostty/custom.icns ~/.config/ghostty/custom.icns
# herdr (~/.config/herdr が存在しない場合は先に作成)
mkdir -p ~/.config/herdr
ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
mkdir -p ~/.config/zed
ln -sf ~/dotfiles/zed/settings.json ~/.config/zed/settings.json
ln -sf ~/dotfiles/zed/keymap.json ~/.config/zed/keymap.json
ln -sf ~/dotfiles/zed/tasks.json ~/.config/zed/tasks.json
# Cursor (macOS。パスにスペースが含まれるため必ずクオートする)
ln -sf ~/dotfiles/cursor/settings.json "$HOME/Library/Application Support/Cursor/User/settings.json"
ln -sf ~/dotfiles/cursor/keybindings.json "$HOME/Library/Application Support/Cursor/User/keybindings.json"
ln -sf ~/dotfiles/zsh/.zshconfig ~/.zshconfig
ln -sf ~/dotfiles/zsh/.zshprompt ~/.zshprompt
ln -sf ~/dotfiles/zsh/.zshalias ~/.zshalias
# ~/.zshrc は環境ごとに各自作成し、上記3ファイルを source する
# PATH 等の環境依存設定は ~/.zshrc に直接書く
# Claude Code 設定
mkdir -p ~/.claude/output-styles
ln -sf ~/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -sf ~/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/dotfiles/claude/notify.sh ~/.claude/notify.sh
ln -sf ~/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/dotfiles/claude/output-styles/amadeus.md ~/.claude/output-styles/amadeus.md
ln -sf ~/dotfiles/claude/output-styles/rockman-exe.md ~/.claude/output-styles/rockman-exe.md
ln -sf ~/dotfiles/claude/output-styles/fable-sato.md ~/.claude/output-styles/fable-sato.md
mkdir -p ~/.claude/skills
ln -sf ~/dotfiles/claude/skills/output-style ~/.claude/skills/output-style
```

プラグインは Neovim 初回起動時に lazy.nvim が自動インストールする。

## 動作確認

シンボリックリンクが期待通りに張られているかは `doctor.sh` で検証する:

```bash
bash ~/dotfiles/doctor.sh
```

全項目 OK なら終了コード 0、NG があれば 1。新しく管理対象のシンボリックリンクを追加した場合は `doctor.sh` のチェック対象にも追加すること。`claude/output-styles/*.md` だけはディレクトリ内の `*.md` を自動でスキャンするため、output style を追加・リネームしたときの doctor.sh 更新は不要。

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

- `.zshconfig` — XDG_CONFIG_HOME・補完・シェルオプション・ヒストリー・キーバインド・TIMEFMT などの汎用的な対話設定
- `.zshprompt` — プロンプト表示（`vcs_info` を使った Git ブランチ表示、GitHub リモートのリンク化を含む）
- `.zshalias` — 環境に依存しない汎用エイリアス

`~/.zshrc` 本体は dotfiles 管理対象外。環境ごとに各自作成し、その中で次のように source する想定:

```zsh
[[ -f ~/.zshconfig ]] && source ~/.zshconfig
[[ -f ~/.zshprompt ]] && source ~/.zshprompt
[[ -f ~/.zshalias ]] && source ~/.zshalias
```

PATH や API キーなど環境固有の設定は各自の `~/.zshrc` に直接書く。

## WezTerm 設定

`wezterm/` 以下の構成:

- `wezterm.lua` — メイン設定ファイル（ウィンドウサイズ、フォントサイズ、カラースキームなど）

## Ghostty 設定

`ghostty/` 以下の構成:

- `config` — Ghostty の設定ファイル。`key = value` 形式のシンプルなテキスト。デフォルト値とドキュメントは `ghostty +show-config --default --docs` で参照できる
- `custom.icns` — `macos-custom-icon` から参照する Dock 用アイコン。ソースになる画像 (jpg など) は dotfiles 管理外で、Pillow + `iconutil` で生成した icns だけを管理する

`~/.config/ghostty/` 配下に Ghostty 本体がキャッシュやテーマを自動生成する可能性があるため、ディレクトリごとリンクせずファイル単位でシンボリックリンクを張る方針（Zed / Cursor と同じ）。

## herdr 設定

`herdr/` 以下の構成:

- `config.toml` — herdr の設定ファイル。TOML 形式。デフォルト値とコメント付きテンプレートは `herdr --default-config` で参照できる。`HERDR_CONFIG_PATH` 環境変数で読み込み先を差し替えることもできる

`~/.config/herdr/` 配下にはセッション状態 (`session.json`)・ローカルソケット・ログなど herdr 本体が実行時に生成するファイルが含まれるため、ディレクトリごとリンクせずファイル単位でシンボリックリンクを張る方針（Ghostty / Zed / Cursor と同じ）。

## Zed 設定

`zed/` 以下の構成:

- `settings.json` — Zed エディタの設定ファイル（テーマ、フォント、ターミナル、エージェント等）
- `keymap.json` — キーバインド定義
- `tasks.json` — Zed Task 定義。ラベル付きでターミナルを起動するために利用（Zed のターミナルタブは OSC 2 を受けないので、Task の `label` をタブ名として使う）

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

## carapace 設定

`carapace/` 以下の構成:

- `specs/` — 自作の補完定義（carapace-spec 形式の YAML）を置く
- `overlays/` — 既存補完への追加・上書き定義（spec と同形式）を置く
- `styles.json` — 補完候補の色・装飾。`carapace --style 'carapace.Value=bold,magenta'` の実行で carapace 自身が書き込む
- `choices/` — 同名補完が複数あるときの優先バリアント指定。`carapace --choice sed@bsd` の実行で 1 行テキストとして生成される

carapace は全 OS で `XDG_CONFIG_HOME` を尊重するため、`zsh/.zshconfig` で `XDG_CONFIG_HOME=~/.config` を export して設定ディレクトリを `~/.config/carapace` に固定している（未設定だと macOS では `~/Library/Application Support/carapace` になる）。キャッシュは `~/Library/Caches/carapace` と別の場所にあり、設定ディレクトリには管理対象のファイルしか置かれないため、Neovim と同様にディレクトリごとシンボリックリンクを張る方針。`styles.json` や `choices/` は carapace 自身が書き込むファイルだが、ディレクトリごとリンクしてあるので自動的に dotfiles 管理下に入る。

ブリッジ経由の補完リストはキャッシュされるため、新しいシェルやコマンドを追加したのに補完が出ないときは `carapace --clear-cache` を実行する。シェルへの組み込み（`CARAPACE_BRIDGES` の export と `source <(carapace _carapace)`）は各自の `~/.zshrc` に書く。

## Claude Code 設定

`claude/` 以下の構成:

- `CLAUDE.md` — 全プロジェクト共通のグローバル指示（応答言語、ツール利用ルール等）。`~/.claude/CLAUDE.md` から symlink する
- `settings.json` — Claude Code のグローバル設定（permissions / model / hooks / statusLine 等）
- `statusline.sh` — ステータスライン用シェルスクリプト。`settings.json` の `statusLine.command` から参照される
- `notify.sh` — 通知用シェルスクリプト。`settings.json` の `hooks.Notification` / `hooks.Stop` から参照される
- `output-styles/amadeus.md` — カスタム output style（アマデウス／AI 牧瀬紅莉栖口調）
- `output-styles/rockman-exe.md` — カスタム output style（ロックマン.EXE 口調）
- `output-styles/fable-sato.md` — カスタム output style（ザ・ファブル／佐藤明口調）
- `skills/output-style/SKILL.md` — `/output-style` スキル。output style を引数の部分一致または一覧選択で切り替える（反映は `/clear` か新セッションから）

`~/.claude` 配下にはセッション履歴やキャッシュなど自動生成されるファイルが多いため、ディレクトリごとリンクせず、管理対象のファイル単位でシンボリックリンクを張る方針。
