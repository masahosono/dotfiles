# hunk

[modem-dev/hunk](https://github.com/modem-dev/hunk) の設定ファイル。

hunk は `git diff` の出力をリッチな TUI で閲覧できるページャ。ファイルツリー、シンタックスハイライト、agent notes 表示などに対応している。

## インストール

macOS (Homebrew):

```bash
brew install modem-dev/tap/hunk
```

その他のインストール方法・ビルド方法は [公式 README](https://github.com/modem-dev/hunk#installation) を参照。

## 設定ファイル

`config.toml` を `~/.config/hunk/config.toml` にシンボリックリンクする。

```bash
mkdir -p ~/.config/hunk
ln -sf ~/dotfiles/hunk/config.toml ~/.config/hunk/config.toml
```

設定可能なキー (`theme` / `mode` / `vcs` / `watch` / `exclude_untracked` / `line_numbers` / `wrap_lines` / `menu_bar` / `agent_notes` / `transparent_background` / カスタムテーマ) は [公式 README の Config セクション](https://github.com/modem-dev/hunk#config) を参照。

## git diff のエイリアス設定

`git diff` の出力を hunk に流し込むエイリアスを登録しておくと便利。

```bash
git config --global alias.d '!hunk'
```

これで `git d` と打つと hunk が起動してカレントリポジトリの diff を閲覧できる。

エイリアスを解除する場合は次のコマンドを実行する:

```bash
git config --global --unset alias.d
```

現在登録されている内容を確認したい場合は `git config --global --get alias.d` で表示できる。

## 関連ファイル

- `config.toml` — 現在の設定。`theme = "auto"`（ターミナル背景に合わせて自動切り替え）と `agent_notes = true`（AI エージェントのメモ表示を有効化）を有効にしている
