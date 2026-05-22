return {
  "mfussenegger/nvim-jdtls",
  opts = {
    jdtls = function(config)
      vim.list_extend(config.cmd, {
        "--jvm-arg=-Xms1g",
        "--jvm-arg=-Xmx4g",
        "--jvm-arg=-XX:+UseG1GC",
        "--jvm-arg=-XX:GCTimeRatio=4",
        "--jvm-arg=-XX:AdaptiveSizePolicyWeight=90",
        "--jvm-arg=-Dsun.zip.disableMemoryMapping=true",
      })
      return config
    end,

    dap_main = false,

    settings = {
      java = {
        contentProvider = { preferred = "fernflower" },
        maven = { downloadSources = true },
        eclipse = { downloadSources = true },
        configuration = {
          runtimes = {
            {
              name = "JavaSE-17",
              path = vim.fn.expand("~/.local/share/mise/installs/java/zulu-17"),
            },
            {
              name = "JavaSE-21",
              path = vim.fn.expand("~/.local/share/mise/installs/java/zulu-21"),
            },
          },
        },
        import = {
          exclusions = {
            "**/node_modules/**",
            "**/.metadata/**",
            "**/archetype-resources/**",
            "**/META-INF/maven/**",
            "**/build/**",
            "**/target/**",
          },
        },
      },
    },
  },
}
