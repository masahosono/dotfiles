# Claude Code 設定

Claude Code 関連の設定ファイル群。

- `settings.json` — Claude Code のグローバル設定（permissions / model / hooks / statusLine 等）
- `statusline.sh` — ステータスライン表示用シェルスクリプト
- `notify.sh` — 通知用シェルスクリプト
- `output-styles/kurisu.md` — カスタム output style

セットアップ手順はリポジトリ直下の [`README.md`](../README.md) を参照。

## `settings.json` の差分ノイズについて

Claude Code は起動中・操作中に `settings.json` を自動で書き換える（`voice`, `enabledPlugins`, `tui`, `voiceEnabled`, `agentPushNotifEnabled` などのキーが書き換わる）。symlink 経由で dotfiles に繋いでいると、`git status` に常に差分が出てしまうため `skip-worktree` フラグで追跡を抑止する運用にしている。

### 差分を抑止する

```bash
git update-index --skip-worktree claude/settings.json
```

### 意図した変更をコミットしたいとき

`skip-worktree` を付けている間は `git status` に差分が出ないので、一時的に解除して編集する。

```bash
git update-index --no-skip-worktree claude/settings.json
# 編集 → git add / commit
git update-index --skip-worktree claude/settings.json
```

### 現在のフラグ状態を確認する

```bash
git ls-files -v claude/settings.json
```

先頭が `S` なら skip-worktree 有効、`H` なら通常追跡。
