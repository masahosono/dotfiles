return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      vim.treesitter.language.register("bash", "zsh")

      vim.api.nvim_create_autocmd("FileType", {
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })

      -- 言語パーサーの自動インストール
      local ensure_installed = {
        "bash", "c", "css", "diff", "go", "html", "javascript",
        "json", "lua", "markdown", "python", "rust", "toml",
        "typescript", "vim", "vimdoc", "yaml",
      }
      for _, lang in ipairs(ensure_installed) do
        pcall(function()
          vim.treesitter.language.add(lang)
        end)
      end
    end,
  },
}
