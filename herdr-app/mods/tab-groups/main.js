// Chrome の Vertical tabs のようなサイドバー。スペースは 1 つだけ使い、そのタブを
// 色付きのグループ（Chrome のタブグループ）に束ねて縦に並べる。上部のタブバーの代わり。
//
// - 使うスペースは「このコンピュータの最初のスペース」(primary)。Herdr にはタブを
//   別スペースへ移す API がないため、ほかのスペースがあれば「Other spaces」として
//   下に出すだけにする（閉じるボタン付き）。この mod 自身はスペースを作らない
//   （スペースが 1 つもないときの新規タブだけは space.new で作る）。
// - グループは Herdr の概念ではないので、この mod が覚える:
//   ~/.config/herdr-tab-groups.json に { list: [{ id, name, color, folded }], of: { tabId: groupId }, at }。
//   実行中は shared("tab-groups") に持ち、メニューや編集ダイアログ（同じ mod の overlay）と共有する。
// - グループは Chrome と同じく中のタブがまとまって並ぶ。タブをグループに入れる・出すときは
//   tab.move でグループの末尾の隣へ動かし、Herdr のタブ順でも連続した状態を保つ。
// - ドラッグ: タブは行の上半分なら前、下半分なら後ろへ（その行のグループに入る）。
//   グループ見出しに重ねるとそのグループの末尾へ。見出しのドラッグでグループごと動かす。
// - 右クリック: タブは「Add to new group / Move to <group> / Remove from group / Rename / Close」、
//   グループは色・New tab in group・Rename・Ungroup・Close group。
// - keys.json の layout:custom から tab-groups.new（~ で新しいタブ）、tab-groups.next / .prev
//   （表示順で次・前のタブ。折りたたんだグループは飛ばす）を呼ぶ。
// - 上部のタブバー（tabs mod）が持っていた Files / Changes パネルの開閉ボタンも見出しに置く。

import { View, div, svg, image } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { spaces, panes, run, openOverlay, closeOverlay, props, exec, theme, shared, setShared, layout, home, nextCommand, machines } from "herdr";

const FILE = "~/.config/herdr-tab-groups.json";
const KEY = "tab-groups";
const groups = () => shared(KEY) ?? { list: [], of: {}, at: 0 };

// Chrome のタブグループの配色（space-folders の GROUP と同じ）。"" はグレー。
const GROUP = { "": "#dadce0", ansi4: "#8ab4f8", ansi1: "#ff8bcb", ansi3: "#fcad70", ansi2: "#81c995", ansi5: "#c58af9", ansi6: "#78d9ec" };
const COLORS = ["ansi4", "ansi1", "ansi3", "ansi2", "ansi5", "ansi6", ""];
const GROUP_INK = "#202124";
const groupColor = (color) => GROUP[color ?? ""] ?? color;

const ICON = (name) => `mods/workspace-chrome/${name}.svg`;

function save(data) {
  const next = { list: data.list, of: data.of, at: Date.now() };
  setShared(KEY, next);
  exec("sh", ["-c", `mkdir -p ~/.config && printf '%s\\n' "$1" > ${FILE}.tmp && mv ${FILE}.tmp ${FILE}`, "sh", JSON.stringify(next)])
    .catch(() => null);
}

async function load() {
  const r = await exec("sh", ["-c", `cat ${FILE} 2>/dev/null`]).catch(() => null);
  try {
    const d = JSON.parse(r?.stdout ?? "");
    return { list: d.list ?? [], of: d.of ?? {}, at: d.at ?? 0 };
  } catch { return null; }
}

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

// サイドバーが細い（レール）ときはアイコンだけにする。
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;

// 使うスペース: このコンピュータの最初のスペース。
const primary = () => spaces().find((s) => !s.machine) ?? null;

const groupOf = (tabId) => {
  const g = groups(), id = g.of[tabId];
  return id && g.list.some((x) => x.id === id) ? id : null;
};

// タブを代表するペイン: エージェントがいればそれ、いなければフォーカス中、なければ最初。
function mainPane(tab, ps) {
  const mine = ps.filter((p) => p.tab === tab.id);
  return mine.find((p) => p.program?.agent) ?? mine.find((p) => p.focused) ?? mine[0] ?? null;
}

const dirName = (cwd) => {
  if (!cwd) return null;
  if (cwd === home()) return "~";
  return cwd.replace(/\/+$/, "").split("/").pop() || "/";
};

// Chrome のページタイトルの代わり: 名前を付けたタブはその名前、なければ
// エージェントのタイトル、シェル以外のプログラムは「名前 · フォルダ」、シェルはフォルダ名。
function label(tab, p) {
  if (tab.named) return tab.name;
  if (!p) return "Terminal";
  if (p.mod) return p.title || p.mod;
  const dir = dirName(p.cwd);
  if (p.program?.agent) return p.title || p.program.name;
  if (p.program && !p.program.shell) return [p.program.name, dir].filter(Boolean).join(" · ");
  return dir ?? p.program?.name ?? "Terminal";
}

const icon = (p, size, color) => !p?.program?.icon ? div().size(size).flex_none()
  : p.program.tint ? svg(p.program.icon).size(size).flex_none().text_color(color) : image(p.program.icon).w(size).h(size).flex_none();
const termName = (p) => ((p.program?.agent || p.program?.shell) && p.program.name) || p.title || p.program?.name || "shell";

function statusMark(el, status, t, ink) {
  return el
    .when(status === "working", (e) => e.child(svg(ICON("spinner")).size(11).flex_none().text_color(ink ?? t.working).spin(900)))
    .when(status === "blocked" || status === "done", (e) => e.child(div().size(7).flex_none().rounded(4).bg(t[status])));
}

// `ids`（この順）のタブをまとめて、タブ `to` の前（after なら後ろ）へ動かす。
// 上から順に、行き先がずれているものだけ tab.move する。
function moveTabs(space, ids, to, after) {
  const order = (space?.tabs ?? []).map((c) => c.id), set = new Set(ids);
  if (!ids.length || set.has(to) || !order.includes(to)) return;
  const rest = order.filter((id) => !set.has(id)), at = rest.indexOf(to) + (after ? 1 : 0);
  const want = [...rest.slice(0, at), ...ids, ...rest.slice(at)], now = [...order];
  for (let k = 0; k < want.length; k++) {
    if (now[k] === want[k]) continue;
    now.splice(k, 0, ...now.splice(now.indexOf(want[k]), 1));
    run("tab.move", { id: want[k], index: k + 1 });
  }
}

// タブをグループに入れる（null で出す）。Chrome と同じく、入れるときはグループの
// 末尾の隣へ、出すときはグループのすぐ後ろへ動かして、グループを連続に保つ。
function assign(tabId, gid, g = groups()) {
  if (gid && !g.list.some((x) => x.id === gid)) return;
  const from = g.of[tabId] ?? null;
  const of = { ...g.of };
  if (gid) of[tabId] = gid; else delete of[tabId];
  save({ ...g, of });
  huddle(tabId, gid, from, of);
}

// `of`: 保存したばかりの割り当て（shared の反映を待たずに使う）。
function huddle(tabId, gid, from, of) {
  const space = primary();
  if (!space) return;
  const order = space.tabs.map((c) => c.id);
  if (gid) {
    const others = order.filter((id) => id !== tabId && of[id] === gid);
    if (others.length) moveTabs(space, [tabId], others.at(-1), true);
  } else if (from) {
    const others = order.filter((id) => id !== tabId && of[id] === from);
    if (others.length) moveTabs(space, [tabId], others.at(-1), true);
  }
}

// 新しいタブ（Herdr は作ったタブの id を返さないので、次に現れたタブを拾う。adopt を参照）。
function newTab({ folder = home(), group = null } = {}) {
  const space = primary();
  if (!space) { run("space.new", folder ? { folder } : {}); return; }
  if (group) setShared(`${KEY}.new`, { group, before: space.tabs.map((c) => c.id), until: Date.now() + 30000 });
  run("tab.new", { space: space.id, ...(folder ? { folder } : {}) });
}

function selectTab(space, tab) {
  if (!space.active) run("space.select", { id: space.id });
  run("tab.select", { id: tab.id });
}

const pause = () => exec("sleep", ["0.15"]).catch(() => null);
async function until(test, ms = 6000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (test()) return true; await pause(); }
  return false;
}

// space-folders で入っていたフォルダ（あれば）。メインへ移すとき同じ名前・色のグループにする。
function folderOfSpace(s) {
  const sf = shared("space-folders")?.[""], id = sf?.of?.[s.id];
  return id ? sf.list?.find((x) => x.id === id) ?? null : null;
}

// ほかのスペースのタブを、動いたままメインのスペースへ移す: ターミナルを
// ペインから外し（terminal.park）、メインで 1 つ目を新しいタブに、残りをその右に
// 戻す（terminal.keep）。分割の向きは右に揃う。空になったスペースは Herdr が消す。
async function mergeSpace(s) {
  const main = primary();
  if (!main || s.id === main.id) return;
  const folder = folderOfSpace(s);
  for (const tab of s.tabs ?? []) {
    const ts = panes().filter((p) => p.tab === tab.id && p.terminal).map((p) => p.terminal);
    if (!ts.length) continue;
    for (const t of ts) run("terminal.park", { terminal: t });
    if (!(await until(() => !panes().some((p) => ts.includes(p.terminal))))) return;
    const target = primary();
    if (!target) return;
    if (!target.active) run("space.select", { id: target.id });
    const before = new Set(target.tabs.map((c) => c.id));
    run("terminal.keep", { terminal: ts[0], place: "tab" });
    await until(() => (primary()?.tabs ?? []).some((c) => !before.has(c.id)));
    const fresh = (primary()?.tabs ?? []).find((c) => !before.has(c.id));
    for (const t of ts.slice(1)) {
      run("terminal.keep", { terminal: t, place: "right" });
      await until(() => panes().some((p) => p.terminal === t));
    }
    if (!fresh) continue;
    // スペースの名前（リポジトリ名など）を、タブが 1 つだけならタブの名前として引き継ぐ。
    if (tab.named) run("tab.rename", { id: fresh.id, name: tab.name });
    else if (s.tabs.length === 1) run("tab.rename", { id: fresh.id, name: s.name });
    if (folder) {
      const g = groups();
      let gr = g.list.find((x) => x.from === folder.id);
      const list = gr ? g.list : [...g.list, (gr = { id: `g${Date.now().toString(36)}`, name: folder.name ?? "", color: folder.color ?? nextColor(g.list), folded: false, from: folder.id })];
      assign(fresh.id, gr.id, { ...g, list });
    }
  }
}

function nextColor(list) {
  const uses = (c) => list.filter((x) => (x.color ?? "") === c).length;
  return COLORS.slice(0, -1).reduce((best, c) => (uses(c) < uses(best) ? c : best));
}

export default class TabGroups extends View {
  init(_props, cx) {
    const { groupMenu, tabMenu, edit, tab = null, fresh = false, overlay } = props() ?? {};
    if (groupMenu) { this.groupMenu = { id: groupMenu, overlay }; return; }
    if (tabMenu) { this.tabMenu = { id: tabMenu, overlay }; return; }
    if (edit) {
      const g = groups().list.find((x) => x.id === edit);
      this.editing = { id: edit, fresh, overlay, tab };
      this.name = InputState.new({ value: g?.name ?? "", placeholder: "Name this group" });
      this.name.on("submit", () => this.saveGroup());
      this.name.focus();
      cx.timer.after(300, () => this.name.focus());
      return;
    }
    this.pressed = null; // ドラッグ中のタブ id
    this.overRow = null; // 重なっている行: { id, group }
    this.after = false; // 行の下半分: その行の後ろ
    this.overGroup = null; // 重なっているグループ見出し
    this.moving = null; // ドラッグ中のグループ: { id, ids }
    this.overMove = null; // そのグループの行き先: k 番目のブロックの前
    this.units = [];
    this.seen = []; // 表示順のタブ（折りたたみ中は shown: false）。next / prev 用
    this.lived = new Set(); // この実行中にタブを持っていたグループ。空になったら消す
    cx.spawn(async (cx) => {
      const read = await load(), now = shared(KEY);
      if (read && (!now || read.at > (now.at ?? 0))) setShared(KEY, read);
      cx.notify();
    });
    cx.timer.every(250, (cx) => this.tick(cx));
    cx.spawn(async (cx) => {
      for (;;) {
        const c = String(await nextCommand()).split(".").pop();
        if (c === "new") newTab();
        else if (c === "next" || c === "prev") this.step(c === "next" ? 1 : -1);
        cx.notify();
      }
    });
  }

  // グループから作ったタブをそのグループへ。消えたタブの記録と、空になったグループを片付ける。
  tick(cx) {
    const space = primary();
    const want = shared(`${KEY}.new`);
    if (want && space) {
      const before = new Set(want.before), fresh = space.tabs.find((c) => !before.has(c.id));
      if (fresh || Date.now() > want.until) setShared(`${KEY}.new`, null);
      if (fresh) assign(fresh.id, want.group);
    }
    const ready = machines().find((m) => m.name === null)?.layout === "ready";
    if (!ready || !space) return;
    const g = groups(), live = new Set(spaces().flatMap((s) => (s.tabs ?? []).map((c) => c.id)));
    const of = Object.fromEntries(Object.entries(g.of).filter(([id]) => live.has(id)));
    const used = new Set(Object.values(of));
    for (const id of used) this.lived.add(id);
    const list = g.list.filter((x) => used.has(x.id) || !this.lived.has(x.id));
    if (Object.keys(of).length !== Object.keys(g.of).length || list.length !== g.list.length) {
      save({ ...g, list, of });
      cx.notify();
    }
  }

  step(dir) {
    const seen = this.seen.filter((s) => s.shown), len = seen.length;
    if (!len) return;
    const space = primary(), active = space?.tabs.find((c) => c.active)?.id;
    const at = seen.findIndex((s) => s.id === active);
    const from = at >= 0 ? at : dir > 0 ? -1 : len;
    const s = seen[(((from + dir) % len) + len) % len];
    if (space) selectTab(space, { id: s.id });
  }

  // ---- グループ ----

  newGroup(tab = null) {
    const id = `g${Date.now().toString(36)}`;
    openOverlay({ mod: "tab-groups", kind: "dialog", width: 380, props: { edit: id, fresh: true, tab } });
  }

  saveGroup() {
    const { id, fresh, overlay, tab } = this.editing, g = groups();
    const name = this.name.value().trim();
    const list = fresh && !g.list.some((x) => x.id === id) ? [...g.list, { id, name, color: nextColor(g.list), folded: false }] : g.list;
    // グループを作ったタブ（Add to new group）は同じ保存で入れる。
    const from = tab ? groupOf(tab) : null;
    const of = tab ? { ...g.of, [tab]: id } : g.of;
    save({ list: list.map((x) => (x.id === id ? { ...x, name } : x)), of });
    closeOverlay(overlay);
    if (tab) huddle(tab, id, from, of);
  }

  patch(id, change) {
    const g = groups();
    save({ ...g, list: g.list.map((x) => (x.id === id ? { ...x, ...change } : x)) });
  }

  ungroup(id) {
    const g = groups();
    save({ list: g.list.filter((x) => x.id !== id), of: Object.fromEntries(Object.entries(g.of).filter(([, v]) => v !== id)) });
  }

  // ---- ドラッグ ----

  finishDrag() {
    const space = primary();
    if (space && this.moving && this.overMove !== null) this.placeGroup(space, this.overMove);
    else if (space && this.pressed) {
      const id = this.pressed;
      if (this.overGroup) assign(id, this.overGroup);
      else if (this.overRow && this.overRow.id !== id) {
        const g = groups(), of = { ...g.of };
        if (this.overRow.group) of[id] = this.overRow.group; else delete of[id];
        save({ ...g, of });
        moveTabs(space, [id], this.overRow.id, this.after);
      }
    }
    this.endDrag();
  }

  endDrag() {
    this.pressed = null; this.overRow = null; this.overGroup = null; this.moving = null; this.overMove = null;
  }

  // ドラッグ中のグループを k 番目のブロックの前へ（k = ブロック数なら末尾）。
  placeGroup(space, k) {
    const units = this.units, mine = units.findIndex((u) => u.group === this.moving.id), ids = this.moving.ids;
    if (mine < 0 || k === mine || k === mine + 1 || !ids.length) return;
    if (k < units.length) moveTabs(space, ids, units[k].ids[0], false);
    else moveTabs(space, ids, units.at(-1).ids.at(-1), true);
  }

  // ---- 描画 ----

  // primary のタブを表示順のブロックに分ける: グループは最初のタブの位置に、
  // 中のタブをまとめて出す（Chrome のタブグループと同じ）。
  blocks(space) {
    const tabs = space?.tabs ?? [], g = groups(), units = [], done = new Set();
    for (const c of tabs) {
      const gid = groupOf(c.id);
      if (!gid) { units.push({ group: null, ids: [c.id], tabs: [c] }); continue; }
      if (done.has(gid)) continue;
      done.add(gid);
      const mine = tabs.filter((x) => groupOf(x.id) === gid);
      units.push({ group: gid, info: g.list.find((x) => x.id === gid), ids: mine.map((x) => x.id), tabs: mine });
    }
    return units;
  }

  row(space, c, gid, ps, t, collapsed) {
    const p = mainPane(c, ps), on = space.active && c.active;
    const dragging = this.pressed !== null;
    const base = h_flex().relative().id(`tab-${c.id}`).h(30).flex_none().items_center().rounded(8)
      .when(on, (el) => el.bg(t.selected))
      .when(!on, (el) => el.hover((s) => s.bg(t.hover)))
      .when(this.pressed === c.id && this.overRow?.id !== c.id, (el) => el.opacity(0.5))
      .when(dragging && this.overRow?.id === c.id && this.pressed !== c.id, (el) => el.child(
        div().absolute().left(0).right(0).h(2).bg(t.accent).when(this.after, (l) => l.bottom(0)).when(!this.after, (l) => l.top(0))))
      .on_mouse_down("left", () => {
        this.endDrag();
        this.fresh = true;
        if (space.id === primary()?.id) { this.pressed = c.id; this.overRow = { id: c.id, group: gid }; }
      })
      .on_mouse_move((e, cx) => {
        if (this.pressed === null || space.id !== primary()?.id) return;
        const after = Boolean(e.bounds) && e.local_position.y >= e.bounds.height / 2;
        if (this.overRow?.id !== c.id || this.overGroup !== null || this.after !== after) {
          this.overRow = { id: c.id, group: gid }; this.overGroup = null; this.after = after; cx.notify();
        }
      })
      .on_mouse_up("left", () => {
        if (this.pressed === null || (this.pressed === c.id && this.overRow?.id === c.id)) selectTab(space, c);
      })
      .on_mouse_down("right", () => openOverlay({ mod: "tab-groups", kind: "popup", width: 230, height: 360, props: { tabMenu: c.id } }));
    if (collapsed) return base.justify_center().child(icon(p, 15, on ? t.foreground : t.muted));
    const close = div().id(`tab-close-${c.id}`).size(20).flex_none().flex().items_center().justify_center().rounded(5)
      .text_color(t.dim).hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: c.id }); })
      .child(svg(ICON("x")).size(12));
    return statusMark(base.pl(10).pr(6).gap(8)
      .child(icon(p, 15, on ? t.foreground : t.muted))
      .child(div().flex_1().min_w(0).truncate().text_color(on ? t.foreground : t.muted).child(c.zoomed ? `${label(c, p)} (zoomed)` : label(c, p))), c.status, t)
      .when(on, (el) => el.child(close));
  }

  // ペインが 2 つ以上あるタブは、その中のターミナルを木で出す（クリックでそのペインへ）。
  paneRows(space, c, ps, t) {
    if (c.panes < 2) return [];
    const mine = ps.filter((p) => p.tab === c.id);
    return mine.map((p, n) => {
      const on = space.active && c.active && p.focused;
      return statusMark(h_flex().id(`tab-pane-${p.pane}`).h(24).flex_none().pl(16).pr(8).gap(6).items_center().rounded(6).text_size(12)
        .when(on, (el) => el.bg(t.hover)).when(!on, (el) => el.hover((s) => s.bg(t.hover)))
        .on_click(() => { selectTab(space, c); run("pane.focus", { pane: p.pane }); })
        .child(div().w(14).flex_none().text_color(t.dim).child(n === mine.length - 1 ? "└" : "├"))
        .child(icon(p, 13, t.dim))
        .child(div().flex_1().min_w(0).truncate().text_color(on ? t.foreground : t.muted).child(p.mod ? p.title || p.mod : termName(p))), p.status, t);
    });
  }

  head(u, t, collapsed) {
    const f = u.info, fill = groupColor(f.color);
    const status = ["blocked", "done", "working"].find((s) => u.tabs.some((c) => c.status === s));
    const target = this.pressed !== null && this.overGroup === f.id;
    const menu = () => openOverlay({ mod: "tab-groups", kind: "popup", width: 220, height: 260, props: { groupMenu: f.id } });
    const el = h_flex().relative().id(`group-${f.id}`).h(26).flex_none().mt(4).gap(6).items_center().rounded(8).cursor_pointer()
      .bg(fill).text_color(GROUP_INK).hover((s) => s.opacity(0.9))
      .when(target, (e) => e.border_2().border_color(t.accent))
      .when(Boolean(this.moving) && this.moving.id === f.id && this.overMove !== null, (e) => e.opacity(0.5))
      .on_mouse_down("left", () => { this.endDrag(); this.fresh = true; this.moving = { id: f.id, ids: u.ids }; })
      .on_mouse_move((_e, cx) => {
        if (this.pressed !== null && this.overGroup !== f.id) { this.overGroup = f.id; this.overRow = null; cx.notify(); }
      })
      .on_click(() => this.patch(f.id, { folded: !f.folded }))
      .on_mouse_down("right", menu);
    if (collapsed) return el.justify_center().child(div().text_size(11).font_bold().child(String(u.tabs.length)));
    const knob = h_flex().id(`group-more-${f.id}`).size(20).flex_none().items_center().justify_center().rounded(5)
      .hover((s) => s.bg("#00000014")).on_mouse_down("left", (_e, cx) => cx.stop_propagation())
      .on_click((_e, cx) => { cx.stop_propagation(); menu(); }).child(div().text_size(15).font_bold().child("⋮"));
    return el.pl(10).pr(4)
      .child(div().flex_1().min_w(0).truncate().text_size(12.5).font_semibold().child(f.name || ""))
      .when(f.folded, (e) => e.child(div().flex_none().text_size(11.5).child(String(u.tabs.length))))
      .when(f.folded && status === "working", (e) => e.child(svg(ICON("spinner")).size(11).flex_none().text_color(GROUP_INK).spin(900)))
      .when(f.folded && Boolean(status) && status !== "working", (e) => e.child(div().size(7).flex_none().rounded(4).bg(t[status])))
      .child(knob)
      .child(svg(ICON(`chevron-${f.folded ? "right" : "down"}`)).size(12).flex_none().mr(4));
  }

  list(space, t, collapsed) {
    const ps = panes(), seen = [];
    const units = this.blocks(space);
    this.units = units;
    const els = units.map((u, k) => {
      let body;
      if (!u.group) {
        const c = u.tabs[0];
        seen.push({ id: c.id, shown: true });
        body = [this.row(space, c, null, ps, t, collapsed), ...(collapsed ? [] : this.paneRows(space, c, ps, t))];
      } else {
        const f = u.info;
        for (const c of u.tabs) seen.push({ id: c.id, shown: !f.folded || c.active });
        const rows = f.folded ? [] : u.tabs.flatMap((c) => [this.row(space, c, f.id, ps, t, collapsed), ...(collapsed ? [] : this.paneRows(space, c, ps, t))]);
        body = [this.head(u, t, collapsed),
          ...(rows.length ? [v_flex().flex_none().ml(collapsed ? 0 : 6).mt(2).mb(2).pl(collapsed ? 0 : 4).border_l_2().border_color(groupColor(f.color)).children(rows)] : [])];
      }
      const line = () => div().absolute().left(0).right(0).h(2).bg(t.accent);
      return v_flex().relative().id(`block-${u.group ?? u.ids[0]}`).flex_none().children(body)
        .when(Boolean(this.moving) && this.overMove === k, (el) => el.child(line().top(0)))
        .when(Boolean(this.moving) && this.overMove === units.length && k === units.length - 1, (el) => el.child(line().bottom(0)))
        .on_mouse_move((e, cx) => {
          if (!this.moving || !e.bounds) return;
          const at = e.local_position.y < Math.min(15, e.bounds.height / 2) ? k : k + 1;
          if (this.overMove !== at) { this.overMove = at; cx.notify(); }
        });
    });
    this.seen = seen;
    return els;
  }

  // 1 つずつ順にメインへ移す（移している間はボタンを止める）。
  merge(list, cx) {
    if (this.merging) return;
    this.merging = true;
    cx.notify();
    cx.spawn(async (cx) => {
      try { for (const s of list) await mergeSpace(s); }
      finally { this.merging = false; cx.notify(); }
    });
  }

  // ほかのスペース: タブを動いたままメインへ移す（Move here）か、閉じる。
  // リモートのマシンのスペースは移せない（ターミナルがそのマシンにある）ので閉じるだけ。
  others(t, collapsed) {
    const main = primary(), rest = spaces().filter((s) => s.id !== main?.id);
    if (!rest.length || collapsed || !main) return [];
    const ps = panes(), local = rest.filter((s) => !s.machine);
    const action = (id, label, run_) => div().id(id).flex_none().px(6).h(20).flex().items_center().rounded(5)
      .text_color(this.merging ? t.dim : t.muted).hover((e) => e.bg(t.hover).text_color(t.foreground))
      .on_click((_e, cx) => { if (!this.merging) run_(cx); }).child(label);
    return [h_flex().mt(12).mb(2).pl(8).pr(2).h(22).items_center().text_size(11).text_color(t.dim)
      .child(div().flex_1().child(this.merging ? "Other spaces (moving…)" : "Other spaces"))
      .when(local.length > 0, (el) => el.child(action("other-merge-all", "Move all here", (cx) => this.merge(local, cx)))),
      ...rest.flatMap((s) => [
        h_flex().id(`other-${s.id}`).h(24).flex_none().pl(8).pr(2).gap(4).items_center().text_size(11.5).text_color(t.muted)
          .child(div().flex_1().min_w(0).truncate().child(s.machine ? `${s.machine}: ${s.name}` : s.name))
          .when(!s.machine, (el) => el.child(action(`other-merge-${s.id}`, "Move here", (cx) => this.merge([s], cx))))
          .child(div().id(`other-close-${s.id}`).size(20).flex_none().flex().items_center().justify_center().rounded(5)
            .hover((e) => e.bg(t.hover).text_color(t.foreground)).on_click(() => run("space.close", { id: s.id }))
            .child(svg(ICON("x")).size(12))),
        ...(s.tabs ?? []).map((c) => this.row(s, c, null, ps, t, false)),
      ])];
  }

  groupMenuView(t) {
    const { id, overlay } = this.groupMenu;
    const f = groups().list.find((x) => x.id === id);
    if (!f) return div();
    const item = (key, label, action) => div().id(key).h(30).px(10).flex().items_center().rounded(6).cursor_pointer()
      .hover((s) => s.bg(t.hover)).on_click(() => { closeOverlay(overlay); action(); }).child(label);
    const swatch = (color) => div().id(`group-color-${color || "grey"}`).size(20).flex_none().rounded(10).cursor_pointer()
      .bg(groupColor(color)).border_2().border_color(color === (f.color ?? "") ? t.foreground : t.popover)
      .hover((s) => s.border_color(t.muted)).on_click(() => { this.patch(id, { color }); closeOverlay(overlay); });
    const ids = (primary()?.tabs ?? []).map((c) => c.id).filter((x) => groupOf(x) === id);
    return v_flex().id("group-menu").size_full().p(5).gap(1).bg(t.popover).text_color(t.foreground).text_size(12.5)
      .child(h_flex().px(8).pt(6).pb(8).gap(6).items_center().children(COLORS.map(swatch)))
      .child(item("group-new-tab", "New tab in group", () => newTab({ folder: null, group: id })))
      .child(item("group-rename", "Rename group…", () => openOverlay({ mod: "tab-groups", kind: "dialog", width: 380, props: { edit: id } })))
      .child(item("group-ungroup", "Ungroup", () => this.ungroup(id)))
      .child(item("group-close", "Close group", () => { this.ungroup(id); for (const x of ids) run("tab.close", { id: x }); }));
  }

  tabMenuView(t) {
    const { id, overlay } = this.tabMenu;
    const inMain = (primary()?.tabs ?? []).some((c) => c.id === id);
    const current = groupOf(id), list = groups().list;
    const line = () => div().mx(7).my(4).h(1).bg(t.border);
    const item = (key, label, lead, action) => h_flex().id(key).h(31).px(8).gap(9).rounded(7).items_center().cursor_pointer()
      .text_color(t.foreground).hover((el) => el.bg(t.hover))
      .on_click(() => { closeOverlay(overlay); action(); })
      .child(lead).child(div().flex_1().min_w(0).truncate().child(label));
    const glyph = (name) => svg(ICON(name)).size(14).flex_none().text_color(t.muted);
    const tile = (x) => div().size(12).mx(1).flex_none().rounded(6).bg(groupColor(x.color));
    return v_flex().id("tab-menu").w_full().min_h(0).p(5).bg(t.popover).text_size(12.8)
      .when(inMain, (el) => el
        .child(item("tab-group-new", "Add to new group", glyph("folder-plus"), () => this.newGroup(id)))
        .children(list.filter((x) => x.id !== current).map((x) => item(`tab-group-to-${x.id}`, `Move to ${x.name || "unnamed group"}`, tile(x), () => assign(id, x.id))))
        .when(Boolean(current), (e) => e.child(item("tab-group-out", "Remove from group", glyph("minus"), () => assign(id, null))))
        .child(line()))
      .child(item("tab-rename", "Rename", glyph("square-pen"), () => run("tab.rename", { id })))
      .child(line())
      .child(item("tab-close", "Close", glyph("x"), () => run("tab.close", { id })));
  }

  editView(t) {
    const { overlay, fresh } = this.editing;
    const button = (key, label, primaryBtn, action) => h_flex().id(key).h(32).px(14).flex_none().items_center().rounded(8).border_1()
      .border_color(primaryBtn ? t.solid : t.input).bg(primaryBtn ? t.solid : t.raised).text_color(primaryBtn ? t.solid_foreground : t.foreground)
      .text_size(12.5).font_medium().cursor_pointer().hover((s) => s.opacity(0.88)).on_click(action).child(label);
    return v_flex().id("group-edit").w_full().p(20).gap(14).bg(t.popover).text_color(t.foreground)
      .on_key_down((e, cx) => { if (e.key === "escape") { closeOverlay(overlay); cx.stop_propagation(); } })
      .child(div().text_size(15).font_semibold().child(fresh ? "New group" : "Rename group"))
      .child(div().h(34).px(10).flex().items_center().rounded(8).border_1().border_color(t.input).bg(t.background)
        .child(Input.new(this.name).w_full().text_size(13).text_color(t.foreground)))
      .child(h_flex().gap(8).justify_end()
        .child(button("group-cancel", "Cancel", false, () => closeOverlay(overlay)))
        .child(button("group-save", "Save", true, () => this.saveGroup())));
  }

  render() {
    const t = theme();
    if (this.groupMenu) return this.groupMenuView(t);
    if (this.tabMenu) return this.tabMenuView(t);
    if (this.editing) return this.editView(t);
    const collapsed = narrow(), space = primary();
    const root = layout(), panel = find(root, "panel"), body = find(root, "panel-body");
    const enabled = shared("workspace.panels") ?? ["files", "changes"];
    const button = (id, child, action, on = false) => div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6)
      .text_color(on ? t.foreground : t.dim).when(on, (el) => el.bg(t.selected))
      .hover((s) => s.bg(t.hover).text_color(t.foreground)).on_click(action).child(child);
    const panelButton = (id, ic) => {
      const on = Boolean(panel) && !panel.hidden && body?.active === id;
      return button(`panel-${id}`, svg(ic).size(14), () => {
        if (on) run("layout.hide", { id: "panel" });
        else { run("layout.select", { stack: "panel-body", child: id }); run("layout.show", { id: "panel" }); }
      }, on);
    };
    const newRow = h_flex().id("tab-new-row").h(30).flex_none().mt(2).px(10).gap(8).items_center().rounded(8)
      .text_size(12.5).text_color(t.dim).cursor_pointer().hover((s) => s.bg(t.hover).text_color(t.foreground))
      .on_click(() => newTab())
      .child(svg(ICON("plus")).size(13).flex_none())
      .when(!collapsed, (el) => el.child(div().flex_1().truncate().child("New tab")));
    return v_flex().size_full().min_h(0).bg(t.chrome).text_size(13)
      .on_mouse_up("left", (_e, cx) => { this.finishDrag(); cx.notify(); })
      // ブロックの外で離したドラッグは release が届かない: 次の押下で忘れる。
      .on_mouse_down("left", (_e, cx) => {
        if (!this.fresh && (this.pressed !== null || this.moving)) { this.endDrag(); cx.notify(); }
        this.fresh = false;
      })
      .when(!collapsed, (el) => el.child(h_flex().h(31).pl(16).pr(8).gap(2).items_center().text_size(11.5).text_color(t.dim)
        .child(div().flex_1().child("Tabs"))
        .when(enabled.includes("files"), (e) => e.child(panelButton("files", "mods/files/file.svg")))
        .when(enabled.includes("changes"), (e) => e.child(panelButton("changes", "mods/changes/changes.svg")))
        .child(button("tab-new", svg(ICON("plus")).size(14), () => newTab()))))
      .child(v_flex().flex_1().min_h(0).px(8).pb(14).overflow_y_scrollbar().mode("always")
        .on_mouse_up("left", (_e, cx) => { this.finishDrag(); cx.notify(); })
        .children(space ? this.list(space, t, collapsed) : [])
        .child(newRow)
        .children(this.others(t, collapsed)));
  }
}
