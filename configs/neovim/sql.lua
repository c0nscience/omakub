local sql_ft = { "sql", "mysql", "plsql" }
local project_config = ".sqruff"
local default_config_dir = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "sqruff")

local function has_project_config(dir)
  return dir ~= nil and vim.uv.fs_stat(vim.fs.joinpath(dir, project_config)) ~= nil
end

return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "sqruff" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqruff = {
          filetypes = sql_ft,
          cmd = function(dispatchers, config)
            local config_dir = has_project_config(config.root_dir) and config.root_dir or default_config_dir
            return vim.lsp.rpc.start({ "sqruff", "lsp" }, dispatchers, { cwd = config_dir })
          end,
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters.sqruff = {
        prepend_args = function(_, ctx)
          if has_project_config(vim.fs.root(ctx.dirname, project_config)) then
            return {}
          end
          return { "--config", vim.fs.joinpath(default_config_dir, project_config) }
        end,
      }
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
