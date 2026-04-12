local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local act = wezterm.action

-- ============================================================
-- 一般
-- ============================================================
config.default_cwd = wezterm.home_dir

-- ============================================================
-- ウィンドウ
-- ============================================================
config.initial_cols = 120
config.initial_rows = 28
config.window_background_opacity = 0.85
config.macos_window_background_blur = 20
config.native_macos_fullscreen_mode = true

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
  -- Cmd+Enter: 全画面切り替え
  { key = 'Enter', mods = 'SUPER', action = act.ToggleFullScreen },
}

-- ============================================================
-- タブ表示
-- ============================================================
wezterm.on('format-tab-title', function(tab, tabs, panes, config, hover, max_width)
  local background = '#5c6d74'
  local foreground = '#FFFFFF'

  if tab.is_active then
    background = '#ae8b2d'
    foreground = '#FFFFFF'
  end

  local title = '   ' .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. '   '

  return {
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = title },
  }
end)

return config
