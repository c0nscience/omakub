local sql_ft = { "sql", "mysql", "plsql" }

return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "sleek" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqruff = { enabled = false },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters.sleek_until_stable = {
        command = "bash",
        args = { "-c", "set -o pipefail; sleek | sleek" },
        stdin = true,
      }
      for _, ft in ipairs(sql_ft) do
        opts.formatters_by_ft[ft] = { "sleek_until_stable" }
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
