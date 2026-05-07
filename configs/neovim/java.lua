return {
  "mfussenegger/nvim-jdtls",
  opts = {
    -- The java binary that runs jdtls itself
    cmd = { vim.fn.expand("~/.local/share/mise/installs/java/zulu-21/bin/java") },

    settings = {
      java = {
        configuration = {
          runtimes = {
            {
              name = "JavaSE-17",
              path = vim.fn.expand("~/.local/share/mise/installs/java/zulu-17/bin/java"),
            },
            {
              name = "JavaSE-21",
              path = vim.fn.expand("~/.local/share/mise/installs/java/zulu-21/bin/java"),
            },
          },
        },
      },
    },
  },
}
