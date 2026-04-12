local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

-- ============================================================
-- 一般
-- ============================================================
config.default_cwd = wezterm.home_dir
config.window_close_confirmation = 'NeverPrompt'
config.scrollback_lines = 100000

-- ============================================================
-- ウィンドウ
-- ============================================================
config.initial_cols = 120
config.initial_rows = 28
config.window_background_opacity = 0.88
config.macos_window_background_blur = 25
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
  -- Cmd+d: 右に分割, Cmd+Shift+d: 下に分割
  { key = 'd', mods = 'SUPER', action = act.SplitHorizontal { cwd = wezterm.home_dir } },
  { key = 'd', mods = 'SUPER|SHIFT', action = act.SplitVertical { cwd = wezterm.home_dir } },
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

local TAB_BAR_BG = '#1d2021'
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
  local title = tab.active_pane.title
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
  tab_bar = {
    background = TAB_BAR_BG,
  },
}
return config
