![dotfiles](assets/dotfiles.png)

# dotfiles

個人の設定ファイル管理用リポジトリ

## 含まれる設定

- **Neovim** (`nvim/`) — lazy.nvim + gruvbox + telescope + neo-tree
- **WezTerm** (`wezterm/`) — ターミナルエミュレータ設定
- **Zed** (`zed/`) — Zed エディタの `settings.json` / `keymap.json`
- **zsh** (`zsh/`) — 汎用設定 (`.zshconfig`)、プロンプト表示 (`.zshprompt`)、汎用エイリアス (`.zshalias`) のみ。`~/.zshrc` 本体は環境ごとに各自作成し、これらを source する
- **inshellisense** (`inshellisense/`) — シェル補完ツールの設定
- **Claude Code** (`claude/`) — Claude Code 関連の設定スクリプト

## セットアップ

```bash
# リポジトリをクローン
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles

# シンボリックリンクを作成
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/wezterm ~/.config/wezterm
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense

# Zed 設定（~/.config/zed が存在しない場合は先に作成）
mkdir -p ~/.config/zed
ln -sf ~/dotfiles/zed/settings.json ~/.config/zed/settings.json
ln -sf ~/dotfiles/zed/keymap.json ~/.config/zed/keymap.json
ln -sf ~/dotfiles/zed/tasks.json ~/.config/zed/tasks.json

# zsh
ln -sf ~/dotfiles/zsh/.zshconfig ~/.zshconfig
ln -sf ~/dotfiles/zsh/.zshprompt ~/.zshprompt
ln -sf ~/dotfiles/zsh/.zshalias ~/.zshalias

# ~/.zshrc は環境ごとに各自作成し、末尾あたりで以下を追記する：
#   [[ -f ~/.zshconfig ]] && source ~/.zshconfig
#   [[ -f ~/.zshprompt ]] && source ~/.zshprompt
#   [[ -f ~/.zshalias ]] && source ~/.zshalias
# PATH や API キーなど環境固有の設定は各自の ~/.zshrc に書く

# Claude Code 設定（~/.claude が存在しない場合は先に作成）
mkdir -p ~/.claude/output-styles
ln -sf ~/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -sf ~/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/dotfiles/claude/notify.sh ~/.claude/notify.sh
ln -sf ~/dotfiles/claude/output-styles/amadeus.md ~/.claude/output-styles/amadeus.md
ln -sf ~/dotfiles/claude/output-styles/rockman-exe.md ~/.claude/output-styles/rockman-exe.md
ln -sf ~/dotfiles/claude/output-styles/fable-sato.md ~/.claude/output-styles/fable-sato.md
mkdir -p ~/.claude/skills
ln -sf ~/dotfiles/claude/skills/output-style ~/.claude/skills/output-style
```

## 動作確認

セットアップ後、シンボリックリンクが正しく張られているかは `scripts/doctor.sh` で検証できる:

```bash
bash ~/dotfiles/scripts/doctor.sh
```

全項目 OK なら終了コード 0、1 つでも NG があれば 1 を返す。

## ライセンス

[MIT License](LICENSE)
