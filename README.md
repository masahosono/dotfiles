# dotfiles

個人の設定ファイル管理用リポジトリ

## 含まれる設定

- **Neovim** (`nvim/`) — lazy.nvim + gruvbox + telescope + neo-tree
- **WezTerm** (`wezterm/`) — ターミナルエミュレータ設定

## セットアップ

```bash
# リポジトリをクローン
git clone git@github.com:masahosono/dotfiles.git ~/dotfiles

# シンボリックリンクを作成
ln -sf ~/dotfiles/nvim ~/.config/nvim
ln -sf ~/dotfiles/wezterm ~/.config/wezterm
```
