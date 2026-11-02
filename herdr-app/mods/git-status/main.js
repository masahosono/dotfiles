import { View, div } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { exec, focused, theme, run } from "herdr";

// フォーカス中のペインの cwd について、ブランチ・ahead/behind・変更ファイル・直近コミットを出す。
// cwd の変化は 1 秒ごとに安く確認し、git の再取得は cwd が変わった時と 5 秒ごとに行う。
const CHECK_MS = 1000;
const REFRESH_MS = 5000;
const MAX_FILES = 30;

// porcelain v2 の XY を 1 文字の表示に寄せる（index 側を優先）
function mark(xy) {
  const [x, y] = xy;
  const c = x !== "." ? x : y;
  return c === "?" ? "?" : c;
}

function parse(stdout) {
  const s = { branch: null, oid: null, upstream: null, ahead: 0, behind: 0, files: [] };
  for (const line of stdout.split("\n")) {
    if (line.startsWith("# branch.head ")) s.branch = line.slice(14);
    else if (line.startsWith("# branch.oid ")) s.oid = line.slice(13);
    else if (line.startsWith("# branch.upstream ")) s.upstream = line.slice(18);
    else if (line.startsWith("# branch.ab ")) {
      const m = line.match(/\+(\d+) -(\d+)/);
      if (m) { s.ahead = +m[1]; s.behind = +m[2]; }
    } else if (line.startsWith("1 ")) {
      const p = line.split(" ");
      s.files.push({ mark: mark(p[1]), path: p.slice(8).join(" ") });
    } else if (line.startsWith("2 ")) {
      // rename/copy: "<path>\t<origPath>"
      const p = line.split(" ");
      s.files.push({ mark: "R", path: p.slice(9).join(" ").split("\t")[0] });
    } else if (line.startsWith("u ")) {
      const p = line.split(" ");
      s.files.push({ mark: "U", path: p.slice(10).join(" ") });
    } else if (line.startsWith("? ")) {
      s.files.push({ mark: "?", path: line.slice(2) });
    }
  }
  return s;
}

export default class GitStatus extends View {
  init(_props, cx) {
    this.cwd = undefined;
    this.state = null; // null: 未取得 / { repo: null }: git 管理外
    this.busy = false;
    cx.timer.every(CHECK_MS, (cx) => {
      if ((focused()?.cwd ?? null) !== this.cwd) this.refresh(cx);
    });
    cx.timer.every(REFRESH_MS, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    if (this.busy) return;
    this.busy = true;
    const cwd = focused()?.cwd ?? null;
    cx.spawn(async (cx) => {
      try {
        if (!cwd) {
          this.state = { repo: null };
        } else {
          const top = await exec("git", ["rev-parse", "--show-toplevel"], { cwd });
          if (top.code !== 0) {
            this.state = { repo: null };
          } else {
            const root = top.stdout.trim();
            const [st, log] = await Promise.all([
              exec("git", ["status", "--porcelain=v2", "--branch"], { cwd: root }),
              exec("git", ["log", "-1", "--format=%s"], { cwd: root }),
            ]);
            this.state = {
              repo: root.split("/").pop(),
              ...parse(st.stdout),
              subject: log.code === 0 ? log.stdout.trim() : "",
            };
          }
        }
      } catch (e) {
        this.state = { repo: null, error: String(e) };
      } finally {
        this.cwd = cwd;
        this.busy = false;
        cx.notify();
      }
    });
  }

  openChanges() {
    run("layout.show", { id: "panel" });
    run("layout.select", { stack: "panel-body", child: "changes" });
  }

  render() {
    const t = theme();
    const s = this.state;
    const color = { M: t.ansi3, A: t.ansi2, D: t.ansi1, R: t.ansi4, U: t.ansi1, "?": t.dim };

    const header = h_flex().h(28).px(16).items_center().justify_between().flex_none()
      .child(div().text_size(12).text_color(t.dim).child("Git"))
      .when(Boolean(s?.repo), (el) => el.child(div().text_size(11).text_color(t.dim).truncate().child(s.repo)));

    const root = v_flex().size_full().bg(t.chrome).text_size(13).child(header);

    if (!s || !s.repo) {
      return root.child(div().px(16).text_color(t.dim).child(s ? "Git リポジトリ外" : "…"));
    }

    const branch = s.branch === "(detached)" ? `detached ${s.oid?.slice(0, 7) ?? ""}` : s.branch;
    const sync = !s.upstream ? "no upstream"
      : s.ahead === 0 && s.behind === 0 ? "up to date"
      : [s.ahead ? `↑${s.ahead}` : null, s.behind ? `↓${s.behind}` : null].filter(Boolean).join(" ");

    const summary = v_flex().px(16).pb(6).gap(2).flex_none()
      .child(h_flex().gap(8).items_center()
        .child(div().flex_1().truncate().font_semibold().text_color(t.foreground).child(branch ?? "?"))
        .child(div().flex_none().text_size(12).text_color(s.ahead || s.behind ? t.accent : t.dim).child(sync)))
      .when(Boolean(s.subject), (el) => el.child(div().truncate().text_size(12).text_color(t.muted).child(s.subject)));

    const files = s.files.slice(0, MAX_FILES);
    const list = v_flex().id("git-files").flex_1().overflow_y_scrollbar().px(8).pb(8)
      .when(files.length === 0, (el) => el.child(div().px(8).text_size(12).text_color(t.dim).child("変更なし")))
      .children(files.map((f, i) =>
        h_flex().id(`f-${i}`).h(22).px(8).gap(8).items_center().rounded(6).cursor_pointer()
          .hover((st) => st.bg(t.hover))
          .on_click(() => this.openChanges())
          .child(div().w(10).flex_none().text_size(12).font_semibold().text_color(color[f.mark] ?? t.muted).child(f.mark))
          .child(div().flex_1().truncate().text_size(12).text_color(t.muted).child(f.path))))
      .when(s.files.length > MAX_FILES, (el) =>
        el.child(div().px(8).text_size(12).text_color(t.dim).child(`…ほか ${s.files.length - MAX_FILES} 件`)));

    return root.child(summary).child(list);
  }
}
