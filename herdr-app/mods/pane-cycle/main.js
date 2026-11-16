// pane-cycle: 今のタブのペインを分割の向きに関係なく順番に回る。
//
// Herdr app には herdr の cycle_pane_next/previous にあたるコマンドがなく、
// pane.go は left/right/up/down しか受けないため、上下分割では
// pane.go:right/left に割り当てたキーが効かない。そこで keys.json から
// "pane-cycle.next" / "pane-cycle.prev" を受け、panes() の並び順で
// 次/前のペインに pane.focus する。
//
// keys.json の "<mod>.<command>" は「画面に出ている」コピーにしか届かないので、
// このモッドはレイアウトに表示サイズ 0 のブロックとして常駐させる前提。
import { View, div } from "gpui-kit";
import { focused, nextCommand, panes, run } from "herdr";

export default class PaneCycle extends View {
  init(_props, cx) {
    cx.spawn(async (cx) => {
      for (;;) {
        const command = await nextCommand();
        if (command === "next") this.cycle(1);
        else if (command === "prev") this.cycle(-1);
      }
    });
  }

  cycle(step) {
    const f = focused();
    if (!f) return;
    const list = panes().filter((p) => p.tab === f.tab);
    if (list.length < 2) return;
    // ズーム中は他のペインが見えていないので、見えないペインに移らないよう何もしない。
    if (list.some((p) => p.zoomed)) return;
    // レイアウトのターミナルブロックにフォーカスがあるとき focused().pane は null。
    // そのときは先頭 (next) / 末尾 (prev) から入る。
    const current = list.findIndex((p) => p.pane === f.pane);
    const index =
      current < 0
        ? (step > 0 ? 0 : list.length - 1)
        : (current + step + list.length) % list.length;
    run("pane.focus", { pane: list[index].pane });
  }

  render() {
    return div();
  }
}
