# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## リポジトリ概要

個人の dotfiles 管理リポジトリ。Neovim、WezTerm、zsh の設定を管理している。

## セットアップ

```bash
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/wezterm ~/.config/wezterm
ln -sf ~/dotfiles/zsh/.zshenv ~/.zshenv
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc
# 秘密情報がある場合は zsh/.zshsecret を作成して記述
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

- `.zshenv` — 環境変数・PATH の設定（すべてのシェルで読み込まれる）
- `.zshrc` — 対話シェル用設定（プロンプト、補完、キーバインド、シェルオプション、エイリアス）
- `.zshsecret` — 秘密情報（`.gitignore` で除外、Git 管理外）
### 秘密情報の管理

- API トークン等の秘密情報は `.zshsecret` に記述する
- `.zshsecret` は `.gitignore` で除外されているため、リポジトリにコミットされない
- `.zshrc` が `.zshsecret` の存在を検知して自動で source する

## WezTerm 設定

`wezterm/` 以下の構成:

- `wezterm.lua` — メイン設定ファイル（ウィンドウサイズ、フォントサイズ、カラースキームなど）
