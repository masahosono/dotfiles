// 動作確認用のサンプルスペック。
// シェルで `hello-is ` まで打って TAB を押すと候補が出れば成功。
// 不要になったら index.js の配列からも消した上でこのファイルを削除する。

const spec = {
  name: "hello-is",
  description: "inshellisense local-spec loading sample",
  subcommands: [
    {
      name: "greet",
      description: "挨拶を表示する",
      args: {
        name: "name",
        description: "挨拶する相手の名前",
        isOptional: true,
      },
    },
    {
      name: "version",
      description: "バージョンを表示する",
    },
  ],
  options: [
    {
      name: ["-v", "--verbose"],
      description: "詳細ログを出力する",
    },
    {
      name: ["-h", "--help"],
      description: "ヘルプを表示する",
    },
  ],
};

export default spec;
