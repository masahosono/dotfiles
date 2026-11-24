// new-space-in-home: ホームディレクトリで新しいスペースを開く。
//
// keys.json の "space.new:<value>" は最初の引数 (name) しか埋められず、
// オブジェクト形式で folder を渡すと絶対パスを書くことになりマシンごとに変わる。
// そこでこの mod から home() を folder に渡す。
//
// keys.json からは "mod.open:new-space-in-home" で呼ぶ。"<mod>.<command>" は
// レイアウトに置かれて画面に出ているコピーにしか届かず、レイアウトごとに
// ブロックを足す必要があったため、overlay として一瞬だけ開いて仕事をし、
// すぐ閉じる使い捨て方式にしている。これならどのレイアウトでも動く。
import { View, div } from "gpui-kit";
import { closeOverlay, home, props, run } from "herdr";

export default class NewSpaceInHome extends View {
  init(_props, _cx) {
    closeOverlay(props().overlay);
    run("space.new", { folder: home() });
  }

  render() {
    return div();
  }
}
