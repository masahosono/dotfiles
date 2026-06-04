![dotfiles](assets/dotfiles.png)

# dotfiles

個人の設定ファイル管理用リポジトリ

## 含まれる設定

- **Neovim** (`nvim/`) — lazy.nvim + gruvbox + telescope + neo-tree
- **WezTerm** (`wezterm/`) — ターミナルエミュレータ設定
- **Zed** (`zed/`) — Zed エディタの `settings.json`
- **zsh** (`zsh/`) — 汎用設定 (`.zshconfig`) とプロンプト表示 (`.zshprompt`) のみ。`~/.zshrc` 本体は環境ごとに各自作成し、これらを source する
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

ln -sf ~/dotfiles/zsh/.zshconfig ~/.zshconfig
ln -sf ~/dotfiles/zsh/.zshprompt ~/.zshprompt

# ~/.zshrc は環境ごとに各自作成し、末尾あたりで以下を追記する：
#   [[ -f ~/.zshconfig ]] && source ~/.zshconfig
#   [[ -f ~/.zshprompt ]] && source ~/.zshprompt
# PATH・エイリアス等の環境依存設定は各自の ~/.zshrc に書く

# Claude Code 設定（~/.claude が存在しない場合は先に作成）
mkdir -p ~/.claude/output-styles
ln -sf ~/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
ln -sf ~/dotfiles/claude/settings.json ~/.claude/settings.json
ln -sf ~/dotfiles/claude/notify.sh ~/.claude/notify.sh
ln -sf ~/dotfiles/claude/output-styles/kurisu.md ~/.claude/output-styles/kurisu.md
```

## ライセンス

[MIT License](LICENSE)
