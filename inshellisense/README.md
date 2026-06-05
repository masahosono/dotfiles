# inshellisense

[inshellisense](https://github.com/microsoft/inshellisense) は、コマンド仕様ベースの IDE 風インライン補完を提供するツール。`is` コマンドで起動する。

## ファイル

- `rc.toml` — inshellisense の設定（エイリアス利用・Nerd Font・補完候補数）。`~/.config/inshellisense/rc.toml` にシンボリックリンクする
- `specs/` — 同梱されていないコマンドの補完を追加するためのローカルスペック置き場（[Fig autocomplete spec 形式](https://fig.io/docs)）。`~/.fig/autocomplete/build` にシンボリックリンクする
- `scripts/` — スペック生成ユーティリティ（ドキュメントから自動生成するもの）

## ローカルスペック（既定外コマンドの補完追加）

inshellisense は、起動時に `~/.fig/autocomplete/build/index.js` を自動でローカルスペックとして読み込む仕様になっている（[`src/utils/config.ts`](https://github.com/microsoft/inshellisense/blob/main/src/utils/config.ts) の `globalConfig.specs` を参照）。そこへ dotfiles 配下の `specs/` をリンクすることで、`rc.toml` を一切触らずにスペックを dotfiles で管理できる。

### スペックの追加手順

1. `specs/<コマンド名>.js` を作る（[Fig spec 形式](https://fig.io/docs) の ESM）
2. `specs/index.js` の `default` 配列に `<コマンド名>` を追記
3. 新しいシェルを開けば反映される（既存セッションでは `is specs list` で確認可）

サンプルとして `hello-is` スペックが入っている。動作確認後に削除するか、自分用のスペックに置き換える。

### スペックの書き方の最小例

```js
// specs/mytool.js
export default {
  name: "mytool",
  description: "短い説明",
  subcommands: [
    { name: "build", description: "ビルドする" },
  ],
  options: [
    { name: ["-v", "--verbose"], description: "詳細ログ" },
    { name: "--output", description: "出力先",
      args: { name: "path", template: "filepaths" } },
  ],
};
```

動的補完（コマンド実行結果に応じた候補）は `generators` を使う。詳しくは [Fig autocomplete のドキュメント](https://fig.io/docs/getting-started/first-spec) を参照。

### ドキュメントから自動生成しているスペック

`scripts/` に置いた生成スクリプトで、公式ドキュメント（マークダウン）からスペックを生成しているコマンドがある。ドキュメントが更新されたら都度叩いて再生成する想定で、自動化（cron / CI）は組んでいない。

| スペック | 生成元 | 生成スクリプト |
|---|---|---|
| `claude` | <https://code.claude.com/docs/en/cli-reference.md> | `scripts/gen-claude-spec.js` |

#### 再生成手順（`claude` の例）

```bash
# 公式ドキュメントを取りに行って specs/claude.js を上書きする
node ~/dotfiles/inshellisense/scripts/gen-claude-spec.js

# オフライン / 別の md を入力にしたい場合
node ~/dotfiles/inshellisense/scripts/gen-claude-spec.js --input ./cli-reference.md
```

生成スクリプトはマークダウンの2つのテーブル（`## CLI commands` と `## CLI flags`）をパースし、`subcommands` / `options` を組み立てる。値を取るフラグかどうかは Example 列のヒューリスティック（直後のトークンが非フラグなら値ありとみなす、ただし `"query"` プレースホルダだけは positional 扱い）で判定している。

`specs/claude.js` 先頭にコメントで生成元 URL と注意書きを入れているので、手で編集せず再生成すること。ドキュメントの章構造（テーブル位置）が変わるとスクリプトが落ちるので、その場合は生成スクリプトの方を修正する。

### なぜ `~/.fig/autocomplete/build` か

- inshellisense は当該パスを設定不要でデフォルトのスペックパスに加えるため、`rc.toml` に `specs.path` を書く必要がない
- `rc.toml` の `specs.path` は絶対パスしか受け付けず（`~` も `$HOME` も展開されない）、dotfiles の可搬性が崩れるため避けたい
- リンクで参照させれば、リポジトリ実体は `~/dotfiles/inshellisense/specs/` のまま git 管理できる

## シェル起動時の自動起動

`is` が利用可能なら zsh 起動時に自動でセッションを開始させたい。`~/.zshrc` の末尾（`mise activate` など `is` が PATH に乗る処理の後）に次を置く:

```zsh
# inshellisense（is があれば公式 init 方式で起動）
if command -v is > /dev/null 2>&1; then
  eval "$(is init zsh)"
fi
```

`~/.zshrc` は環境ごとに各自作成する dotfiles 管理外のファイルなので、この記述もリポジトリには含まれない。`is` を自動起動したい環境では各自で上記を追記する。

### `is init zsh` の仕組み

`is init zsh` は **実行すべきシェルコードを標準出力に印字するだけ**で、それ自体は何も起動しない。`eval "$(...)"` でラップして初めて評価・実行される（`mise activate` や `starship init` と同じ慣用パターン）。

`is init zsh` が吐くのは次の1行で、生成済みの初期化スクリプトを source するもの:

```zsh
[[ -f ~/.inshellisense/init/zsh/init.zsh ]] && source ~/.inshellisense/init/zsh/init.zsh
```

source される `init.zsh` の中身（`is` が自動生成・メンテする）:

```zsh
if [[ -z "${ISTERM}" && $- = *i* && $- != *c* && -z "${VSCODE_RESOLVING_ENVIRONMENT}" ]]; then
  if [[ -o login ]]; then
    is -s zsh --login ; exit
  else
    is -s zsh ; exit
  fi
fi
```

### 各ガード条件の役割

| 条件 | 役割 |
|------|------|
| `[[ -z "${ISTERM}" ]]` | `is` セッション内（内側シェル）では再起動しない。内側シェルは `~/.zshrc` を再読込するため、このガードが無いと冗長メッセージやネスト関連の不具合につながる |
| `$- = *i*` | 対話シェルのときだけ起動（スクリプト等の非対話シェルで誤起動しない） |
| `$- != *c*` | `zsh -c "..."` のコマンドモードでは起動しない |
| `-z "${VSCODE_RESOLVING_ENVIRONMENT}"` | VSCode の環境解決プロセスでは起動しない |
| `[[ -o login ]] → --login` | ログインシェルなら `--login` 付きで内側シェルを起動する |
| `is -s zsh ; exit` | zsh セッションとして inshellisense を起動し、終了時に外側シェルごと閉じる。区切りが `;`（`&&` ではない）なので、`is` の終了コードに関わらず確実に `exit` する |

> **補足:** 手書きで `is -s zsh && exit` と書く起動方式もあるが、`is init zsh` 方式なら上記のガードを公式が生成・メンテするため、`is` のバージョンアップにも追従でき堅牢。特別な理由が無ければ公式 init 方式を使う。

### 配置位置の注意

`is` を mise などのバージョン管理ツール経由で導入している場合、`is` は `mise activate` 後に初めて PATH に乗る。そのため上記の記述は **`mise activate` より後**（`~/.zshrc` の末尾付近）に置くこと。先頭で読み込まれる `.zshconfig` などに置くと `command -v is` が失敗して起動しない。

### 起動速度を詰めたい場合（任意）

`eval "$(is init zsh)"` は zsh 起動のたびに `is`（node プロセス）を1回起動する。生成済みの `init.zsh` を直接 source すれば、この起動コストを省ける:

```zsh
[[ -f ~/.inshellisense/init/zsh/init.zsh ]] && source ~/.inshellisense/init/zsh/init.zsh
```

挙動は `eval "$(is init zsh)"` と同一だが、`init.zsh` が生成済みであることが前提になるため可搬性は下がる。一長一短。

## セットアップ

```bash
# 設定（rc.toml）を ~/.config/inshellisense として参照させる
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense

# ローカルスペックを inshellisense のデフォルト読込パスへリンクする
mkdir -p ~/.fig/autocomplete
ln -sf ~/dotfiles/inshellisense/specs ~/.fig/autocomplete/build
```

セットアップ後、新しいシェルを開いて `is specs list | tr ',' '\n' | grep hello-is` で `hello-is` が出ればローカルスペックの読み込みは成功。
