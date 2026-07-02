local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

-- ============================================================
-- 一般
-- ============================================================
config.default_cwd = wezterm.home_dir
config.window_close_confirmation = 'AlwaysPrompt'
config.scrollback_lines = 100000

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

-- ============================================================
-- カーソル
-- ============================================================
-- 点滅ブロック。点滅周期(ms)。フェード演出は WebGpu バックエンドで有効
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = 'EaseOut'
config.cursor_blink_ease_out = 'EaseOut'

-- ============================================================
-- 配色
-- ============================================================
config.color_scheme = 'GruvboxDarkHard'

-- ============================================================
-- 分割ユーティリティ
-- ============================================================
-- WezTerm デフォルトの Split は「現在のペインを 50/50 に分ける」ため、n 枚
-- 目のペインは 1/2^n の幅になってしまう。同じ行/列にあるペイン全てを均等な
-- サイズに揃えたいので、分割前に境界を動かして active ペインが (2*T + 1)
-- セル分になるよう調整し、そのあと size = { Cells = T } で分割することで、
-- 分割後に全ペインが T セル幅で並ぶようにする。
local function split_equal(axis)
  local is_h = axis == 'horizontal'
  local ctor = is_h and act.SplitHorizontal or act.SplitVertical
  local plus_dir = is_h and 'Right' or 'Down'
  local minus_dir = is_h and 'Left' or 'Up'

  return wezterm.action_callback(function(window, pane)
    local default_action = ctor { domain = 'CurrentPaneDomain' }
    local tab = pane:tab()
    if not tab then
      window:perform_action(default_action, pane)
      return
    end

    local all_panes = tab:panes_with_info()
    local ref
    for _, p in ipairs(all_panes) do
      if p.is_active then ref = p; break end
    end
    if not ref then
      window:perform_action(default_action, pane)
      return
    end

    -- horizontal 分割なら同じ top/height、vertical 分割なら同じ left/width
    -- を持つペインが 1 本の行/列を成す。それ以外はツリー上の別枝
    local peers = {}
    for _, p in ipairs(all_panes) do
      local same_line
      if is_h then
        same_line = p.top == ref.top and p.height == ref.height
      else
        same_line = p.left == ref.left and p.width == ref.width
      end
      if same_line then
        table.insert(peers, p)
      end
    end
    table.sort(peers, function(a, b)
      if is_h then return a.left < b.left end
      return a.top < b.top
    end)

    local n = #peers
    local total = 0
    for _, p in ipairs(peers) do
      total = total + (is_h and p.width or p.height)
    end

    -- 分割後は (n+1) 枚のペイン + n 個の区切りで元の総セル数を分け合う
    local target = math.floor((total - 1) / (n + 1))
    if target < 2 then
      window:perform_action(default_action, pane)
      return
    end

    local active_idx
    for i, p in ipairs(peers) do
      if p.is_active then active_idx = i; break end
    end

    -- 境界 i (i = 1..n-1) を左から順に動かす。累積目標と累積現在幅の差分を
    -- 境界 i の移動量とする。境界 i の位置は先行する境界移動の影響を受けな
    -- いため、原初の幅からの累積で計算できる
    local cum_target, cum_cur = 0, 0
    for i = 1, n - 1 do
      cum_target = cum_target + ((i == active_idx) and (2 * target + 1) or target)
      cum_cur = cum_cur + (is_h and peers[i].width or peers[i].height)
      local delta = cum_target - cum_cur
      if delta > 0 then
        window:perform_action(act.AdjustPaneSize { plus_dir, delta }, peers[i].pane)
      elseif delta < 0 then
        window:perform_action(act.AdjustPaneSize { minus_dir, -delta }, peers[i].pane)
      end
    end

    -- 事前調整済みの active ペイン (2*target+1 セル) を target セルで分割
    window:perform_action(
      ctor { domain = 'CurrentPaneDomain', size = { Cells = target } },
      pane
    )
  end)
end

-- ============================================================
-- キーバインド
-- ============================================================
config.keys = {
  -- Cmd+t: 新しいタブをホームディレクトリで開く
  { key = 't', mods = 'SUPER', action = act.SpawnCommandInNewTab { cwd = wezterm.home_dir } },
  -- Cmd+d: 右に分割, Cmd+Shift+d: 下に分割 (カレントディレクトリを引き継ぐ)
  -- 分割後は同じ行/列のペインが均等な幅/高さになるように再配分する
  { key = 'd', mods = 'SUPER', action = split_equal('horizontal') },
  { key = 'd', mods = 'SUPER|SHIFT', action = split_equal('vertical') },
  -- Cmd+[ / Cmd+]: ペイン間移動
  { key = '[', mods = 'SUPER', action = act.ActivatePaneDirection 'Prev' },
  { key = ']', mods = 'SUPER', action = act.ActivatePaneDirection 'Next' },
  -- Cmd+Shift+[ / Cmd+Shift+]: 現在のタブを左/右に移動
  -- OS が Shift+[ を '{' として通知するケースがあり、その場合 WezTerm の
  -- デフォルト(ActivateTabRelative)が発火してしまうため両方バインドする
  { key = '[', mods = 'SUPER|SHIFT', action = act.MoveTabRelative(-1) },
  { key = ']', mods = 'SUPER|SHIFT', action = act.MoveTabRelative(1) },
  { key = '{', mods = 'SUPER|SHIFT', action = act.MoveTabRelative(-1) },
  { key = '}', mods = 'SUPER|SHIFT', action = act.MoveTabRelative(1) },
  -- Cmd+w: 確認なしでペインを閉じる
  { key = 'w', mods = 'SUPER', action = act.CloseCurrentPane { confirm = false } },
  -- Cmd+Enter: 全画面切り替え
  { key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen },
  -- Cmd+k: 画面とスクロールバックをクリア
  { key = 'k', mods = 'SUPER', action = act.ClearScrollback 'ScrollbackAndViewport' },
  -- Cmd+y: コピーモード(yank)に入る
  { key = 'y', mods = 'SUPER', action = act.ActivateCopyMode },
}

-- ============================================================
-- タブ表示
-- ============================================================
config.show_new_tab_button_in_tab_bar = false
config.show_close_tab_button_in_tabs = false
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.tab_max_width = 32

local TAB_BAR_BG = '#0a0f1f'
local ACTIVE_BG = '#fe8019'
local ACTIVE_FG = '#1d2021'
local INACTIVE_BG = '#3c3836'
local INACTIVE_FG = '#a89984'
local HOVER_BG = '#504945'
local HOVER_FG = '#ebdbb2'

local TAB_LEFT_EDGE = utf8.char(0xe0b6)
local TAB_RIGHT_EDGE = utf8.char(0xe0b4)

-- cwd(Url オブジェクト or file:// 文字列)からディレクトリ名を取り出す。
-- cwd はシェルが OSC 7 で通知するもの(zsh/.zshconfig 参照)。
local function cwd_dir_name(cwd)
  if not cwd then return nil end
  local path = type(cwd) == 'string' and cwd or cwd.file_path
  if not path then return nil end
  path = path:gsub('^file://[^/]*', '') -- 文字列形式なら file://host を除去
  path = path:gsub('/+$', '')           -- 末尾スラッシュを除去
  if path == '' or path == wezterm.home_dir then return '~' end
  return path:match('([^/]+)$') or path
end

wezterm.on('format-tab-title', function(tab, tabs, panes, cfg, hover, max_width)
  local bg = INACTIVE_BG
  local fg = INACTIVE_FG
  if tab.is_active then
    bg = ACTIVE_BG
    fg = ACTIVE_FG
  elseif hover then
    bg = HOVER_BG
    fg = HOVER_FG
  end

  local index = tab.tab_index + 1
  local title = cwd_dir_name(tab.active_pane.current_working_dir) or tab.active_pane.title
  local label = ' ' .. index .. ': ' .. wezterm.truncate_right(title, max_width - 6) .. ' '

  return {
    { Background = { Color = TAB_BAR_BG } },
    { Foreground = { Color = bg } },
    { Text = TAB_LEFT_EDGE },
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = label },
    { Background = { Color = TAB_BAR_BG } },
    { Foreground = { Color = bg } },
    { Text = TAB_RIGHT_EDGE },
  }
end)

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
  tab_bar = {
    background = TAB_BAR_BG,
  },
}
return config
