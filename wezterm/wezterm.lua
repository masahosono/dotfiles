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
  'ヒラギノ角ゴシック',
}
config.font_size = 12
config.use_ime = true
config.macos_forward_to_ime_modifier_mask = 'SHIFT|CTRL'

-- ============================================================
-- 配色
-- ============================================================
config.color_scheme = 'GruvboxDarkHard'

-- ============================================================
-- キーバインド
-- ============================================================
config.keys = {
  -- Cmd+t: 新しいタブをホームディレクトリで開く
  { key = 't', mods = 'SUPER', action = act.SpawnCommandInNewTab { cwd = wezterm.home_dir } },
  -- Cmd+d: 右に分割, Cmd+Shift+d: 下に分割 (カレントディレクトリを引き継ぐ)
  { key = 'd', mods = 'SUPER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'SUPER|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
  -- Cmd+[ / Cmd+]: ペイン間移動
  { key = '[', mods = 'SUPER', action = act.ActivatePaneDirection 'Prev' },
  { key = ']', mods = 'SUPER', action = act.ActivatePaneDirection 'Next' },
  -- Cmd+w: 確認なしでペインを閉じる
  { key = 'w', mods = 'SUPER', action = act.CloseCurrentPane { confirm = false } },
  -- Cmd+Enter: 全画面切り替え
  { key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen },
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
local ACTIVE_BG = '#ae8b2d'
local ACTIVE_FG = '#1d2021'
local INACTIVE_BG = '#3c3836'
local INACTIVE_FG = '#a89984'
local HOVER_BG = '#504945'
local HOVER_FG = '#ebdbb2'

local SOLID_RIGHT_ARROW = utf8.char(0xe0b0)
local SOLID_LEFT_ARROW = utf8.char(0xe0b2)

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
  local cwd_uri = tab.active_pane.current_working_dir
  local title
  if cwd_uri then
    local path = cwd_uri.file_path or ''
    title = path:match('([^/]+)/?$') or path
    if title == wezterm.home_dir:match('([^/]+)/?$') then
      title = '~'
    end
  else
    title = tab.active_pane.title
  end
  local label = ' ' .. index .. ': ' .. wezterm.truncate_right(title, max_width - 6) .. ' '

  return {
    { Background = { Color = TAB_BAR_BG } },
    { Foreground = { Color = bg } },
    { Text = SOLID_LEFT_ARROW },
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = label },
    { Background = { Color = TAB_BAR_BG } },
    { Foreground = { Color = bg } },
    { Text = SOLID_RIGHT_ARROW },
  }
end)

config.colors = {
  background = '#0f1629',
  tab_bar = {
    background = TAB_BAR_BG,
  },
}
return config
