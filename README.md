# dotfiles

個人の設定ファイル管理用リポジトリ

## 含まれる設定

- **Neovim** (`nvim/`) — lazy.nvim + gruvbox + telescope + neo-tree
- **WezTerm** (`wezterm/`) — ターミナルエミュレータ設定
- **zsh** (`zsh/`) — シェル設定（環境変数、プロンプト、エイリアス等）

## セットアップ

```bash
# リポジトリをクローン
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles

# シンボリックリンクを作成
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/wezterm ~/.config/wezterm
ln -sf ~/dotfiles/zsh/.zshenv ~/.zshenv
ln -sf ~/dotfiles/zsh/.zshrc ~/.zshrc

# 秘密情報がある場合は zsh/.zshsecret を作成して記述
```
