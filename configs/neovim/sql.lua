local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "sqruff" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqruff = { filetypes = sql_ft },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      for _, ft in ipairs(sql_ft) do
        opts.formatters_by_ft[ft] = { "sqruff" }
      end
    end,
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function(_, opts)
      for _, ft in ipairs(sql_ft) do
        opts.linters_by_ft[ft] = vim.tbl_filter(function(linter)
          return linter ~= "sqlfluff"
        end, opts.linters_by_ft[ft] or {})
      end
    end,
  },
}
