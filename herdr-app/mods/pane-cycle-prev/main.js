// pane-cycle-prev: 今のタブの前のペインに移る (次に進むのは pane-cycle-next)。
//
// Herdr app には herdr の cycle_pane_next/previous にあたるコマンドがなく、
// pane.go は left/right/up/down しか受けないため、上下分割では
// pane.go:right/left に割り当てたキーが効かない。そこで panes() の並び順で
// 前のペインに pane.focus する。
//
// keys.json からは "mod.open:pane-cycle-prev" で呼ぶ。"<mod>.<command>" は
// レイアウトに置かれて画面に出ているコピーにしか届かず、レイアウトごとに
// ブロックを足す必要があったため、overlay として一瞬だけ開いて仕事をし、
// すぐ閉じる使い捨て方式にしている。これならどのレイアウトでも動く。
// mod.open は name しか受けないので、向きごとに mod を分けている。
import { View, div } from "gpui-kit";
import { closeOverlay, focused, panes, props, run } from "herdr";

const STEP = -1;

export default class PaneCyclePrev extends View {
  init(_props, _cx) {
    // 先に overlay を閉じてから動く。開いたままだとフォーカスが overlay に残る。
    closeOverlay(props().overlay);
    cycle(STEP);
  }

  render() {
    return div();
  }
}

function cycle(step) {
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
