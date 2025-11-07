return {
  -- Configure LSP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        puppet = {
          -- Optional: Add custom settings here
          settings = {
            puppet = {
              validate = true,
            },
          },
        },
      },
    },
  },

  -- Ensure Mason installs the Puppet LSP
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "puppet-editor-services",
      },
    },
  },

  -- Optional: Add Tree-sitter support for better syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "puppet",
      },
    },
  },
}
