# inshellisense

[inshellisense](https://github.com/microsoft/inshellisense) は、コマンド仕様ベースの IDE 風インライン補完を提供するツール。`is` コマンドで起動する。

## ファイル

- `rc.toml` — inshellisense の設定（エイリアス利用・Nerd Font・補完候補数）。`~/.config/inshellisense/rc.toml` にシンボリックリンクする

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
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense
```
