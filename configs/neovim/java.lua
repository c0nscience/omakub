return {
  "mfussenegger/nvim-jdtls",
  opts = {
    jdtls = function(config)
      -- G1 (low-pause) with a 2g heap. Heap is deliberately NOT raised: several
      -- jdtls JVMs run at once (one per open project) and the box is RAM-bound.
      -- The vscode-java ParallelGC-era knobs (GCTimeRatio/AdaptiveSizePolicyWeight/
      -- disableMemoryMapping) were removed: they fight G1 and disabling mmap stops
      -- the OS page cache from sharing dependency jars across the parallel servers.
      vim.list_extend(config.cmd, {
        "--jvm-arg=-Xmx2g",
        "--jvm-arg=-XX:+UseG1GC",
      })

      -- LazyVim's `$MASON/share/java-test/*.jar` glob feeds jdtls two non-OSGi jars
      -- that its bundle loader rejects on every startup ("Failed to load extension
      -- bundles"). Drop them so the test/debug bundles load cleanly.
      if config.init_options and config.init_options.bundles then
        config.init_options.bundles = vim.tbl_filter(function(jar)
          return not (jar:match("jacocoagent") or jar:match("runner%-jar%-with%-dependencies"))
        end, config.init_options.bundles)
      end

      return config
    end,

    -- Don't hot-swap classes on every save while debugging (rebuild+redefine over
    -- JDWP stalls each save). Restart the session to pick up edits, IntelliJ-style.
    dap = { hotcodereplace = "off" },
    dap_main = false,

    settings = {
      java = {
        contentProvider = { preferred = "fernflower" },
        -- Attaching sources triggers synchronous Maven Central lookups that time
        -- out and block indexing/navigation; fernflower decompilation covers it.
        maven = { downloadSources = false },
        eclipse = { downloadSources = false },
        -- Full "all" hints recompute over RPC behind the reconcile queue on big files.
        inlayHints = {
          parameterNames = { enabled = "literals" },
        },
        -- Skip the synchronous ECJ build before every debug/test launch; autobuild
        -- (enabled by default) keeps compiled classes fresh on save.
        debug = {
          settings = {
            forceBuildBeforeLaunch = false,
          },
        },
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
