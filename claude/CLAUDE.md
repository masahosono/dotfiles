# Claude Code Settings

全プロジェクト共通の Claude Code 向けグローバル指示。
`~/.claude/CLAUDE.md` から symlink する想定。

## 言語

- 常に日本語で応答すること (Always respond in Japanese)

## ツール利用ルール

- `AskUserQuestion` ツールは使わない。インタラクティブな選択肢 UI を表示するとターミナルの表示が崩れる。
- ユーザーに選択を求める場合は、通常のテキスト出力で番号付き一覧として選択肢と各オプションの説明を提示し、ユーザーの返答を待つこと。プランモードでの選択肢提示も同様。
