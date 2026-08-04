# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

個人の dotfiles 管理リポジトリ。Neovim、WezTerm、Ghostty、herdr、hunk、Zed、Cursor、zsh、inshellisense、Claude Code の設定を管理している。

## ブランチ運用

**基本的に `main` ブランチで直接作業してコミットする。** 作業用ブランチや PR は作らない。個人リポジトリでレビュアーがいないため、ブランチを切っても手動でマージし直す手間が増えるだけになる（実際の履歴も一貫して `main` への直接コミット）。

ブランチを切るのは、複数の変更を並行して試したい場合や、後で丸ごと捨てる可能性のある実験的な変更に限る。その場合も作業後は `main` に fast-forward マージし、ブランチは削除する。

なお複数の Claude Code セッションを並走させている場合、`git add .` や `git commit -a` で他セッションの差分を巻き込む事故が起きる。コミット対象は必ず明示的にパス指定する（`claude/skills/commit-my-changes` の `/commit-my-changes` がこれを自動化する）。

## セットアップ

```bash
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense
# WezTerm (通常モード。herdr 専用モードは herdr.app が WEZTERM_CONFIG_FILE で固定するため symlink は通常設定に向ける)
mkdir -p ~/.config/wezterm
ln -sf ~/dotfiles/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
# carapace (XDG_CONFIG_HOME=~/.config の設定が前提。zsh/.zshconfig で export している)
ln -sf ~/dotfiles/carapace ~/.config/carapace
# Ghostty (~/.config/ghostty が存在しない場合は先に作成)
mkdir -p ~/.config/ghostty
ln -sf ~/dotfiles/ghostty/config ~/.config/ghostty/config
ln -sf ~/dotfiles/ghostty/custom.icns ~/.config/ghostty/custom.icns
# herdr (~/.config/herdr が存在しない場合は先に作成)
mkdir -p ~/.config/herdr
ln -sf ~/dotfiles/herdr/config.toml ~/.config/herdr/config.toml
# herdr.app (WezTerm を herdr 専用ターミナルとしてラップした app を /Applications に生成)
bash ~/dotfiles/herdr/app/make.sh
# hunk (~/.config/hunk が存在しない場合は先に作成)
mkdir -p ~/.config/hunk
ln -sf ~/dotfiles/hunk/config.toml ~/.config/hunk/config.toml
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
ln -sf ~/dotfiles/claude/statusline_fable.sh ~/.claude/statusline_fable.sh
ln -sf ~/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/dotfiles/claude/notify.sh ~/.claude/notify.sh
ln -sf ~/dotfiles/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/dotfiles/claude/output-styles/amadeus.md ~/.claude/output-styles/amadeus.md
ln -sf ~/dotfiles/claude/output-styles/rockman-exe.md ~/.claude/output-styles/rockman-exe.md
ln -sf ~/dotfiles/claude/output-styles/fable-sato.md ~/.claude/output-styles/fable-sato.md
mkdir -p ~/.claude/skills
ln -sf ~/dotfiles/claude/skills/output-style ~/.claude/skills/output-style
ln -sf ~/dotfiles/claude/skills/commit-my-changes ~/.claude/skills/commit-my-changes
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

- `wezterm.lua` — 通常モード用の設定（WezTerm 単体をマルチプレクサとして使うときの構成）。`~/.config/wezterm/wezterm.lua` の symlink 先で、WezTerm.app を直接起動したときに使われる
- `wezterm_herdr.lua` — herdr 専用モードの設定。**herdr.app 経由の起動時のみ使われる**（herdr/app/make.sh が `LSEnvironment` の `WEZTERM_CONFIG_FILE` で固定するため、symlink の張り替えは不要）。タブバー非表示、`disable_default_key_bindings = true` にした上で必要なもの (Cmd+C/V/Q/N/=/-/0) だけ復活。Cmd+X は WezTerm 側で Ctrl+Alt+X に変換して pane へ送出し、herdr は `ctrl+alt+X` の direct binding で受ける（cmd/super 生送出は公式が「terminal 依存で不安定」と警告しているため経由しない）
- **herdr は手動起動運用**。当初は `default_prog` で自動起動する構成だったが、WezTerm 終了時に default_prog の子プロセスが絡んで `~/.local/share/wezterm/gui-sock-<pid>` の消し忘れが起き、次回 Dock/Finder 起動でクラッシュする事象があったため、`default_prog` は無効化してある。herdr.app 起動後にシェルから `herdr` を叩いてアタッチする。新規ウィンドウは Cmd+N で開ける（WezTerm ネイティブの SpawnWindow を残してある）

`~/.config/wezterm/` はディレクトリごとリンクせず、`~/.config/wezterm/wezterm.lua` をファイル単位で dotfiles 内の `.lua` ファイルに向ける方針（Ghostty / Zed / Cursor と同じ）。モードはアプリで分かれる: **WezTerm.app = 通常モード（symlink に従う）、herdr.app = herdr 専用モード（常に wezterm_herdr.lua）**。

## Ghostty 設定

`ghostty/` 以下の構成:

- `config` — Ghostty の設定ファイル。`key = value` 形式のシンプルなテキスト。デフォルト値とドキュメントは `ghostty +show-config --default --docs` で参照できる
- `custom.icns` — `macos-custom-icon` から参照する Dock 用アイコン。ソースになる画像 (jpg など) は dotfiles 管理外で、Pillow + `iconutil` で生成した icns だけを管理する

`~/.config/ghostty/` 配下に Ghostty 本体がキャッシュやテーマを自動生成する可能性があるため、ディレクトリごとリンクせずファイル単位でシンボリックリンクを張る方針（Zed / Cursor と同じ）。

## herdr 設定

`herdr/` 以下の構成:

- `config.toml` — herdr の設定ファイル。TOML 形式。デフォルト値とコメント付きテンプレートは `herdr --default-config` で参照できる。`HERDR_CONFIG_PATH` 環境変数で読み込み先を差し替えることもできる
- `app/make.sh` — `/Applications/herdr.app` を生成するスクリプト。中身は `/Applications/WezTerm.app` の複製（`ditto --arch arm64` で thin 化）で、アイコンを `herdr.icns` に差し替え、`CFBundleName` / `CFBundleIdentifier`（`com.masahosono.herdr`）を変更し、`LSEnvironment` で `WEZTERM_CONFIG_FILE` を `wezterm_herdr.lua` に固定したうえで ad-hoc 再署名する。**WezTerm.app を更新したら再実行が必要**
- `herdr.icns` — herdr.app 用のアプリアイコン。[公式ロゴ SVG](https://herdr.dev/assets/logo.svg) を qlmanage で 1024px に描画し、Pillow で macOS 標準の角丸グリッド（1024 キャンバスに 824 角丸矩形）に加工して iconutil で icns 化したもの。ソース画像は dotfiles 管理外で、生成済み icns だけを管理する（ghostty/custom.icns と同じ方針）

herdr.app は Dock / Spotlight から herdr 専用ターミナルを一発起動するための薄いラッパー。exec するだけのスクリプトバンドルでは GUI 接続時に Launch Services が実体パスから WezTerm.app として再登録してしまいアイコンが乗っ取られるため、バンドル丸ごと複製方式を採っている。`WEZTERM_CONFIG_FILE` を固定してあるので、`~/.config/wezterm/wezterm.lua` の symlink 先に関係なく常に herdr 専用モードで起動する（WezTerm.app 側は従来どおり symlink に従う）。なお LSEnvironment はシェルから `open` した場合は呼び出し元の環境変数が優先される点に注意

`~/.config/herdr/` 配下にはセッション状態 (`session.json`)・ローカルソケット・ログなど herdr 本体が実行時に生成するファイルが含まれるため、ディレクトリごとリンクせずファイル単位でシンボリックリンクを張る方針（Ghostty / Zed / Cursor と同じ）。

キーバインドは prefix (`ctrl+space`) を非常口として残しつつ、主要アクションは `prefix+X` と `ctrl+alt+X` の dual binding にしてある。WezTerm (`wezterm_herdr.lua`) 側で Cmd+X を Ctrl+Alt+X に変換して送出しているため、ユーザー打鍵 Cmd+X 一発で herdr のアクションが発火する構成。cmd/super の直送出は公式が「terminal 依存で不安定」と警告しているためこの経路は採らない。

## hunk 設定

`hunk/` 以下の構成:

- `config.toml` — hunk の設定ファイル。TOML 形式。設定可能なキー（`theme` / `mode` / `vcs` / `watch` / `exclude_untracked` / `line_numbers` / `wrap_lines` / `menu_bar` / `agent_notes` / `transparent_background` / カスタムテーマ）は [modem-dev/hunk の README](https://github.com/modem-dev/hunk#config) を参照。初期状態は空ファイル（hunk 側のデフォルトで動作する）

`~/.config/hunk/` 配下には hunk 本体が実行時に生成する `state.json` が含まれるため、ディレクトリごとリンクせずファイル単位でシンボリックリンクを張る方針（Ghostty / herdr / Zed / Cursor と同じ）。

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
- `statusline.sh` — ステータスライン用シェルスクリプト。`settings.json` の `statusLine.command` から参照される。1〜4 行目 (ヘッダー / Context / Session / Weekly) を担当し、モデル別の週次枠の実装だけは `statusline_fable.sh` に切り出して source している
- `statusline_fable.sh` — モデル別の週次枠 (Fable など) を statusline に出す実装。`statusline.sh` から source される前提で、単体実行はしない。公開するのは `print_model_limits()` だけで、`bar()` / `color_for_pct()` / 色変数は呼び出し側に依存する。`statusline.sh` は `$(dirname "$0")/statusline_fable.sh` を source するので、**`statusline.sh` と同じように `~/.claude/statusline_fable.sh` にも symlink を張る必要がある** (`doctor.sh` のチェック対象に入れてあるので、張り忘れれば検出される)。読めなければ `print_model_limits` が未定義になり、その行が出ないだけで 1〜4 行目には影響しない。以下はこのファイルの実装メモ: モデル別の週次枠は statusline の入力 JSON に含まれない (本体が `anthropic-ratelimit-unified-{5h,7d}-*` レスポンスヘッダから `five_hour` / `seven_day` の 2 つだけを組み立てて渡している) ため、`/usage` コマンドと同じ内部 API `GET /api/oauth/usage` を自分のアクセストークンで直接叩き、`~/.cache/claude-statusline/` に 60 秒キャッシュしている。取得はバックグラウンドで行い描画はブロックしない (失敗が続いても叩き続けないよう試行間隔自体も 60 秒で絞ってある)。レスポンスの階層は決め打ちせず `kind: "weekly_scoped"` を含む配列を再帰的に探すため、構造が変わっても拾える (実測では `limits` は `rate_limits` の下ではなくトップレベルにあり、`resets_at` はマイクロ秒 + オフセット付き ISO 8601 で届く)。取得結果は同ディレクトリの `last-status` に 1 行だけ記録される (`<時刻>\t<OK|NG>\t<表示用の理由>\t<診断用の詳細>` の TSV)。これは単なるログではなく状態ファイルで、表示側もこれを読む。**取得に失敗したときは古い値を出さず `[--%] 取得失敗 (HTTP 401)` のように理由付きのプレースホルダーを出す** — 週次枠は数分の遅れなら問題ないが、取得が壊れ続けたときに何日も前の値を最新として見せると枠の残りを誤認するため。同時実行の防止と試行間隔の絞りは `attempt.lock` ディレクトリ 1 つで兼ねている (`mkdir` のアトミック性を使い、完了時に消さず TTL 経過後に奪う。完了時刻を基準にすると判定とマーカー作成の間に隙間ができて二重に走る)。ドキュメント化されていない API なのでフィールド名やパスが予告なく変わり得るが、どう失敗しても 1〜4 行目には影響しない設計
- `notify.sh` — 通知用シェルスクリプト。`settings.json` の `hooks.Notification` / `hooks.Stop` から参照される
- `output-styles/amadeus.md` — カスタム output style（アマデウス／AI 牧瀬紅莉栖口調）
- `output-styles/rockman-exe.md` — カスタム output style（ロックマン.EXE 口調）
- `output-styles/fable-sato.md` — カスタム output style（ザ・ファブル／佐藤明口調）
- `skills/output-style/SKILL.md` — `/output-style` スキル。output style を引数の部分一致または一覧選択で切り替える（反映は `/clear` か新セッションから）
- `skills/commit-my-changes/SKILL.md` — `/commit-my-changes` スキル。今のセッションで自分（Claude）が編集したファイルだけを明示パス指定でコミットする。複数の Claude セッション並走時に他セッションの差分を巻き込まないための対策

`~/.claude` 配下にはセッション履歴やキャッシュなど自動生成されるファイルが多いため、ディレクトリごとリンクせず、管理対象のファイル単位でシンボリックリンクを張る方針。
