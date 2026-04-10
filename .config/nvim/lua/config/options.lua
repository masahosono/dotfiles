local opt = vim.opt

-- 行番号
opt.number = true
opt.relativenumber = false

-- インデント
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- 検索
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- 表示
opt.termguicolors = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.wrap = false

-- ファイル
opt.swapfile = false
opt.backup = false
opt.undofile = true

-- 分割
opt.splitbelow = true
opt.splitright = true

-- クリップボード (macOS)
opt.clipboard = "unnamedplus"

-- 補完メニュー
opt.completeopt = { "menu", "menuone", "noselect" }

-- 更新時間 (gitgutterなどの反応速度)
opt.updatetime = 250
opt.timeoutlen = 300

-- 不可視文字の表示
opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
