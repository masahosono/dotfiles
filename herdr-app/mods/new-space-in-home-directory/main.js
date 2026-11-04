import { View, div, svg } from "gpui-kit";
import { h_flex } from "gpui-base";
import { run, theme, home, nextCommand } from "herdr";

// ホームディレクトリで新しいスペースを作る。
// keys.json の "space.new:<値>" は第 1 引数 (name) しか埋められず folder を渡せないため、
// mod から run("space.new", { folder }) を呼ぶ。cmd-n は keys.json の layout:custom で
// "new-space-in-home-directory.new" に割り当てている。
// <mod>.<command> は画面に表示されている mod にしか届かないので、サイドバーに
// クリックでも同じ動作をするボタンとして常に表示しておく。
function newHomeSpace() {
  run("space.new", { folder: home() });
}

export default class NewSpaceInHomeDirectory extends View {
  init(_props, cx) {
    cx.spawn(async (cx) => {
      for (;;) {
        const c = String(await nextCommand()).split(".").pop();
        if (c === "new") newHomeSpace();
        cx.notify();
      }
    });
  }

  render() {
    const t = theme();
    return h_flex().size_full().bg(t.chrome).px(8).items_center()
      .child(h_flex().id("new-space-in-home-directory").h(26).flex_1().px(8).gap(7).items_center().rounded(7)
        .text_size(12).text_color(t.dim).cursor_pointer()
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click(() => newHomeSpace())
        .child(svg("mods/workspace-chrome/plus.svg").size(12).flex_none())
        .child(div().flex_1().truncate().child("New space in ~")));
  }
}
