# dotfiles

![dotfiles](assets/hero.png)

個人の設定ファイル管理用リポジトリ

## 含まれる設定

- **Neovim** (`nvim/`) — lazy.nvim + gruvbox + telescope + neo-tree
- **WezTerm** (`wezterm/`) — ターミナルエミュレータ設定
- **zsh** (`zsh/`) — プロンプト表示部分のみ（`prompt.zsh`）。`~/.zshrc` 本体は環境ごとに各自作成し、本ファイルを source する
- **inshellisense** (`inshellisense/`) — シェル補完ツールの設定
- **Claude Code** (`claude/`) — Claude Code 関連の設定スクリプト

## セットアップ

```bash
# リポジトリをクローン
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles

# シンボリックリンクを作成（zsh はリンクしない）
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/wezterm ~/.config/wezterm
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense

# ~/.zshrc は環境ごとに各自作成し、末尾あたりで以下を追記する
#   source ~/dotfiles/zsh/prompt.zsh
# 補完・キーバインド・エイリアス・PATH などの環境依存設定は各自の ~/.zshrc に書く

# Claude Code 設定（~/.claude が存在しない場合は先に作成）
mkdir -p ~/.claude
ln -sf ~/dotfiles/claude/statusline.sh ~/.claude/statusline.sh
```
