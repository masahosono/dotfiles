return {
  -- 括弧・クォートの操作 (cs'" で ' を " に変換など)
  {
    "kylechui/nvim-surround",
    version = "*",
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },

  -- 括弧の自動補完
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
}
