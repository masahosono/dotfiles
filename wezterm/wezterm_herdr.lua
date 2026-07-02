-- WezTerm 設定 (herdr 専用モード)。
-- 通常モードは wezterm.lua を参照。切替は ~/.config/wezterm/wezterm.lua の
-- symlink 先を差し替えることで行う。
--
-- 方針:
--   * herdr を default_prog として自動起動し、WezTerm はキャンバスに徹する
--   * タブ・分割・移動は全て herdr に任せ、WezTerm のタブバーは非表示
--   * ユーザー打鍵 Cmd+X はそのまま。WezTerm 側で Ctrl+Alt+X に変換して pane に送出し、
--     herdr は ctrl+alt+X の direct binding で受ける (herdr 公式推奨方式。
--     cmd/super 生送出は terminal 依存で不安定と公式が警告している)
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

-- ============================================================
-- 一般
-- ============================================================
config.default_cwd = wezterm.home_dir
-- herdr が detach 確認を出すので WezTerm 側の二重確認は不要
config.window_close_confirmation = 'NeverPrompt'
config.scrollback_lines = 100000

-- herdr の自動起動は一旦取り下げる。
-- default_prog で herdr を起動すると、wezterm の終了フロー時に socket 消し忘れが
-- 起き、次回 Dock 起動でクラッシュする事象を確認したため。
-- 起動後にシェルから `herdr` を手動起動する運用にする。
-- config.default_prog = { 'zsh', '-lc', 'exec herdr' }

-- WezTerm の mux server を無効化する。
-- デフォルトでは "default" という unix domain が自動で作られ、これに紐づく
-- multiplexer / cli 機能が動く。herdr 専用モードでは不要なので切る。
config.unix_domains = {}

-- Dock/Finder から再起動したとき、既存 wezterm-gui プロセスに spawn 要求を投げず
-- 新規プロセスとして GUI を立ち上げる。これをやらないと `~/.local/share/wezterm/
-- gui-sock-<pid>` 経由で既存インスタンスに接続を試み、Broken pipe を起こして
-- 新規ウィンドウが出ないまま落ちる (=見た目クラッシュ) 事象が発生する。
config.default_gui_startup_args = { 'start', '--always-new-process' }

-- ============================================================
-- レンダラ
-- ============================================================
-- macOS のスリープ復帰時に NSOpenGLContext 経由でクラッシュする既知の問題を
-- 回避するため Metal(WebGpu)バックエンドを使用する
config.front_end = 'WebGpu'
config.webgpu_power_preference = 'LowPower'

-- ============================================================
-- ウィンドウ
-- ============================================================
config.initial_cols = 180
config.initial_rows = 42
config.window_background_opacity = 0.80
config.macos_window_background_blur = 15
config.native_macos_fullscreen_mode = true
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.4,
}

-- ============================================================
-- フォント
-- ============================================================
config.font = wezterm.font_with_fallback {
  'Menlo',
  'ヒラギノ丸ゴ ProN',
}
config.font_size = 12
config.use_ime = true
config.macos_forward_to_ime_modifier_mask = 'SHIFT|CTRL'

-- macOS の Option (Alt) を「composed character 入力」ではなく生の Alt 修飾子として
-- 送出する。デフォルトだと Option+t が † などの特殊文字に化け、Ctrl+Alt+t が
-- herdr に `ctrl+alt+t` として届かない
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- modifier 付きキーをレガシーな "ESC + Ctrl+t" (Meta prefix + control char) ではなく
-- kitty keyboard protocol の CSI シーケンスで送出する。これがないと Ctrl+Alt+t が
-- ESC + Ctrl+T として届き、herdr は `ctrl+alt+t` として解釈できない。
config.enable_kitty_keyboard = true

-- ============================================================
-- カーソル
-- ============================================================
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = 'EaseOut'
config.cursor_blink_ease_out = 'EaseOut'

-- ============================================================
-- 配色
-- ============================================================
config.color_scheme = 'GruvboxDarkHard'
config.colors = {
  background = '#0f1629',
  -- Gruvbox の yellow は緑寄りで green と判別しづらいため orange に差し替える
  ansi = {
    '#1d2021', '#cc241d', '#98971a', '#fe8019',
    '#458588', '#b16286', '#689d6a', '#a89984',
  },
  brights = {
    '#928374', '#fb4934', '#b8bb26', '#fe8019',
    '#83a598', '#d3869b', '#8ec07c', '#ebdbb2',
  },
}

-- ============================================================
-- タブバー
-- ============================================================
-- herdr がマルチプレクサとして UI を持つため WezTerm 側のタブは不要
config.enable_tab_bar = false

-- ============================================================
-- キーバインド
-- ============================================================
-- WezTerm のデフォルトを全部落として、必要なものだけ明示バインドする。
-- これにより herdr 側の直接ショートカット (ctrl+alt+X) と将来的にぶつかる余地を消す。
config.disable_default_key_bindings = true

-- Cmd+X を kitty keyboard の CSI-u シーケンスで直接 pane に送る。
-- SendKey (合成キーイベント) は wezterm の内部で kitty モードを尊重せず legacy
-- 送出 (ESC + Ctrl+t) してしまい herdr が ctrl+alt+t として認識できなかったため、
-- SendString で CSI-u を直接送出する方式に切り替える。
-- CSI-u modifier: Shift=1, Alt=2, Ctrl=4 の合計 + 1 が送出値。
--   Ctrl+Alt (6+1)       = 7
--   Ctrl+Alt+Shift (7+1) = 8
local function csi_u(key, mods, char_code, csi_mods)
  return {
    key = key,
    mods = mods,
    action = act.SendString(string.format('\x1b[%d;%du', char_code, csi_mods)),
  }
end

config.keys = {
  -- ---- herdr へ CSI-u シーケンス (= ctrl+alt+X 相当) として送出 ----
  -- Cmd+T: 新しいタブ (herdr new_tab). 't' = 0x74 = 116
  csi_u('t', 'SUPER', 116, 7),
  -- Cmd+D: 左右分割 (herdr split_vertical) / Cmd+Shift+D: 上下分割 (herdr split_horizontal)
  -- WezTerm と herdr で vertical/horizontal の呼び方が逆なので注意。'd' = 100
  csi_u('d', 'SUPER', 100, 7),
  csi_u('d', 'SUPER|SHIFT', 100, 8),
  -- Cmd+[ / Cmd+]: ペイン循環 (herdr cycle_pane_previous/next). '[' = 91, ']' = 93
  csi_u('[', 'SUPER', 91, 7),
  csi_u(']', 'SUPER', 93, 7),
  -- Cmd+Shift+[ / Cmd+Shift+]: タブ切替 (herdr previous_tab/next_tab)
  -- macOS が Shift+[ を '{' として通知するケースがあるので両方にバインド
  csi_u('[', 'SUPER|SHIFT', 91, 8),
  csi_u(']', 'SUPER|SHIFT', 93, 8),
  csi_u('{', 'SUPER|SHIFT', 91, 8),
  csi_u('}', 'SUPER|SHIFT', 93, 8),
  -- Cmd+W: 現在のペインを閉じる (herdr close_pane). 'w' = 119
  csi_u('w', 'SUPER', 119, 7),
  -- Cmd+Y: スクロールバック編集 (herdr edit_scrollback). 'y' = 121
  csi_u('y', 'SUPER', 121, 7),

  -- ---- WezTerm 側で完結させる ----
  -- Cmd+Enter: 全画面切替
  { key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen },
  -- Cmd+K: 画面とスクロールバックをクリア (WezTerm ネイティブ。herdr 内 pane の
  -- 独自スクロールバックには効かない可能性あり)
  { key = 'k', mods = 'SUPER', action = act.ClearScrollback 'ScrollbackAndViewport' },

  -- ---- WezTerm デフォルトから復活させる標準操作 ----
  { key = 'c', mods = 'SUPER', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'SUPER', action = act.PasteFrom 'Clipboard' },
  { key = 'q', mods = 'SUPER', action = act.QuitApplication },
  -- Cmd+N: 新規 WezTerm ウィンドウ。Cmd+Q で完全 quit した後、Dock から起動すると
  -- gui-sock ゾンビが残っている場合にクラッシュすることがある。× でウィンドウを
  -- 閉じてもプロセスは生きるので、Cmd+N で新規ウィンドウを開ける方が安定する
  { key = 'n', mods = 'SUPER', action = act.SpawnWindow },
  { key = '=', mods = 'SUPER', action = act.IncreaseFontSize },
  { key = '-', mods = 'SUPER', action = act.DecreaseFontSize },
  { key = '0', mods = 'SUPER', action = act.ResetFontSize },
}

return config
