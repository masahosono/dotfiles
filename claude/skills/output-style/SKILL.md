---
name: output-style
description: Claude Code の output style を切り替える。引数にスタイル名（部分一致可。例 fable, amadeus, rockman, default）。省略時は一覧から選択。--global でグローバル設定を変更する
disable-model-invocation: true
argument-hint: "[スタイル名] [--global]"
---

Claude Code の output style を切り替える。引数: `$ARGUMENTS`

## 手順

### 1. 利用可能なスタイルを列挙する

- カスタムスタイル: `~/.claude/output-styles/*.md` を全て読み、各ファイルの frontmatter から `name` と `description` を取得する
- built-in: `default`（output style 無しの標準状態）
- **設定値に使うのは frontmatter の `name`**（例: `Fable Sato`）。ファイル名（`fable-sato`）ではない

### 2. 対象スタイルを決定する

- 引数にスタイル名があれば、大文字小文字を無視した部分一致で解決する
  - 例: `fable` → `Fable Sato`、`rock` → `Rockman.EXE`、`ama` → `Amadeus Kurisu`、`def` → `default`
- 引数が無い、またはマッチが 0 件・複数件の場合は AskUserQuestion で一覧から選んでもらう。各選択肢の description にはスタイルの frontmatter の description を一行で添える

### 3. 設定を書き込む

output style の設定は「プロジェクトの `.claude/settings.local.json`」が「グローバルの `~/.claude/settings.json`」より優先されることを踏まえて書き込み先を決める。

- **デフォルト**（`--global` 無し）: カレントプロジェクトの `.claude/settings.local.json` の `outputStyle` キーを更新する
  - ファイルが無ければ `{"outputStyle": "<name>"}` の内容で新規作成する
  - 既存ファイルがあれば `outputStyle` キーのみ変更し、他のキーは一切変更しない
- **`--global` 指定時**: `~/.claude/settings.json` の `outputStyle` キーを更新する
  - カレントプロジェクトの `.claude/settings.local.json` に `outputStyle` キーが存在する場合、そちらが優先されてグローバル変更が効かない旨を必ず警告する（ローカル設定を勝手に削除しない。削除するかはユーザーに確認する）

JSON 編集時は既存のフォーマット（インデント等）を保ち、他のキーを壊さないこと。

### 4. 結果を報告する

- どのファイルの `outputStyle` をどの値に変更したかを伝える
- output style はセッション開始時に system prompt へ読み込まれるため、**現在のセッションには反映されない**。`/clear` するか新しいセッションを開くと有効になることを必ず伝える
