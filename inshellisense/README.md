# inshellisense

[inshellisense](https://github.com/microsoft/inshellisense) は、コマンド仕様ベースの IDE 風インライン補完を提供するツール。`is` コマンドで起動する。

## ファイル

- `rc.toml` — inshellisense の設定（エイリアス利用・Nerd Font・補完候補数）。`~/.config/inshellisense/rc.toml` にシンボリックリンクする

## シェル起動時の自動起動

`is` が利用可能なら zsh 起動時に自動でセッションを開始させたい。`~/.zshrc` の末尾（`mise activate` など `is` が PATH に乗る処理の後）に次の1行を置く:

```zsh
# inshellisense（is があれば起動）。内側シェルでは ISTERM が立ち is が即 0 を返すため、
# ガードしないと && exit が誤発火して内側シェルが落ちる。
[[ -z "$ISTERM" ]] && command -v is >/dev/null 2>&1 && is -s zsh && exit
```

`~/.zshrc` は環境ごとに各自作成する dotfiles 管理外のファイルなので、この記述もリポジトリには含まれない。`is` を自動起動したい環境では各自で上記を追記する。

### 各条件の役割

| 条件 | 役割 | 外すとどうなるか |
|------|------|------------------|
| `[[ -z "$ISTERM" ]]` | `is` セッション内（内側シェル）では起動しない | `is` が起動する内側シェルは `~/.zshrc` を再読込する。そこで `ISTERM` が立った状態で `is -s zsh` を呼ぶと `is` は即 `0` を返すため、続く `&& exit` が誤発火して内側シェルが落ちる。さらに毎回 `inshellisense session [live]` が表示される |
| `command -v is >/dev/null 2>&1` | `is` が入っていない環境では何もしない | `is` 未導入の環境でコマンドエラーになる |
| `is -s zsh` | zsh セッションとして inshellisense を起動 | — |
| `&& exit` | `is` 終了時に外側シェルごと終了し、ターミナルを閉じる | `is` を抜けると素の zsh プロンプトに戻る |

> **補足:** ネスト自体は `is` が `ISTERM` で防いでいるため、`ISTERM` ガードが無くても無限再起動はしない。ガードの主目的は上表のとおり「`&& exit` の誤発火」と「冗長メッセージ」の抑制。

### 配置位置の注意

`is` を mise などのバージョン管理ツール経由で導入している場合、`is` は `mise activate` 後に初めて PATH に乗る。そのため上記の行は **`mise activate` より後**（`~/.zshrc` の末尾付近）に置くこと。先頭で読み込まれる `.zshconfig` などに置くと `command -v is` が失敗して起動しない。

## セットアップ

```bash
ln -sf ~/dotfiles/inshellisense ~/.config/inshellisense
```
