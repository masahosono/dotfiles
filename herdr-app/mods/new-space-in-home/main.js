// new-space-in-home: ホームディレクトリで新しいスペースを開く。
//
// keys.json の "space.new:<value>" は最初の引数 (name) しか埋められず、
// オブジェクト形式で folder を渡すと絶対パスを書くことになりマシンごとに変わる。
// そこで keys.json から "new-space-in-home.open" を受け、home() を folder に渡す。
//
// keys.json の "<mod>.<command>" は「画面に出ている」コピーにしか届かないので、
// このモッドはレイアウトに表示サイズ 0 のブロックとして常駐させる前提。
import { View, div } from "gpui-kit";
import { home, nextCommand, run } from "herdr";

export default class NewSpaceInHome extends View {
  init(_props, cx) {
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === "open") run("space.new", { folder: home() });
      }
    });
  }

  render() {
    return div();
  }
}
