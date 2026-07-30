return {
  "mfussenegger/nvim-jdtls",
  opts = {
    jdtls = function(config)
      -- open_classfile blocks the main loop per jdt:// buffer via vim.wait, and
      -- when triggered from inside an LSP callback (snacks picker results that
      -- contain library classes) the decompile response can never arrive during
      -- the wait — every library hit burns the FULL timeout with the UI frozen.
      -- 500ms caps a 40-hit references list at ~4s instead of ~200s.
      require("jdtls").settings.jdt_uri_timeout_ms = 500

      -- One shared jar index across all project workspaces: the same dependency
      -- jars were being re-indexed (~1.7GB duplicated) once per workspace, and
      -- page-cached once per running server. jdtls does not create the dir itself.
      local shared_index = vim.fn.expand("~/.cache/jdtls-shared-index")
      vim.fn.mkdir(shared_index, "p")

      -- G1 (low-pause) with a 2g heap. Heap is deliberately NOT raised: several
      -- jdtls JVMs run at once (one per open project) and the box is RAM-bound.
      -- On JDK 21 G1 is already the ergonomic default — -Xmx2g is the load-bearing
      -- flag (unbounded, each server grows toward 1/4 of RAM).
      -- The vscode-java ParallelGC-era knobs (GCTimeRatio/AdaptiveSizePolicyWeight/
      -- disableMemoryMapping) were removed: they fight G1 and disabling mmap stops
      -- the OS page cache from sharing dependency jars across the parallel servers.
      vim.list_extend(config.cmd, {
        "--jvm-arg=-Xmx2g",
        "--jvm-arg=-XX:+UseG1GC",
        -- mason's launcher hardcodes -Xms1G (later flag wins). A low floor plus
        -- periodic GC (JEP 346) lets idle servers uncommit heap back to the OS —
        -- the biggest RAM lever across parallel servers without touching -Xmx.
        "--jvm-arg=-Xms256m",
        "--jvm-arg=-XX:G1PeriodicGCInterval=300000",
        "--jvm-arg=-XX:+UseStringDeduplication",
        -- Guard, not a saving: converts a pathological classloader leak into a
        -- contained OOME of one server instead of box-wide swap thrash.
        "--jvm-arg=-XX:MaxMetaspaceSize=512m",
        -- vscode-java ships this: a stray JVM unified-logging line on stdout
        -- would corrupt the LSP JSON-RPC stream.
        "--jvm-arg=-Xlog:disable",
        -- vscode-java defaults: skip the VM-installation filesystem scan on every
        -- start; breadth-first Maven dependency collector (same result, faster).
        "--jvm-arg=-DDetectVMInstallationsJob.disabled=true",
        "--jvm-arg=-Daether.dependencyCollector.impl=bf",
        "--jvm-arg=-Djdt.core.sharedIndexLocation=" .. shared_index,
      })

      -- LazyVim's `$MASON/share/java-test/*.jar` glob feeds jdtls two non-OSGi jars
      -- that its bundle loader rejects on every startup ("Failed to load extension
      -- bundles"). Drop them so the test/debug bundles load cleanly.
      if config.init_options and config.init_options.bundles then
        config.init_options.bundles = vim.tbl_filter(function(jar)
          return not (jar:match("jacocoagent") or jar:match("runner%-jar%-with%-dependencies"))
        end, config.init_options.bundles)
      end

      -- Throttle textDocument/didChange from nvim's 150ms default so sustained
      -- typing drives the reconcile/diagnostics/inlay-hint chain ~3x/s instead of
      -- ~7x/s (a lone keystroke after a pause still flushes at once). Must live on
      -- the config, not LspAttach: nvim captures the debounce at didOpen — before
      -- LspAttach fires — and thereafter only ever lowers it. Lower to 150 if
      -- completion feels stale.
      config.flags = vim.tbl_deep_extend("force", config.flags or {}, {
        debounce_text_changes = 300,
      })

      return config
    end,

    -- Invoked by LazyVim's java extra from its jdtls-guarded LspAttach handler.
    on_attach = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if not client then
        return
      end
      -- Drop semantic tokens for jdtls only: nvim re-requests full-document tokens
      -- on every didChange flush (jdtls has no delta support), a whole-file AST
      -- walk that mostly dies as -32801 mid-typing and is recomputed. Treesitter
      -- already highlights Java; only semantic modifiers are lost.
      vim.lsp.semantic_tokens.enable(false, { client_id = client.id })
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
        -- eclipse.jdt.ls's server-side default re-validates EVERY open Java buffer
        -- on each change (constructor default = true; VS Code overrides to false,
        -- but nvim-jdtls only sends keys we set here, so unset = true). That is the
        -- "every keystroke checks multiple files" lag — one edit validated 2-4
        -- dependent units at 100-180ms each. Scope validation to the edited buffer.
        edit = {
          validateAllOpenBuffersOnChanges = false,
        },
        completion = {
          -- The server caps proposals at 50 and marks the list incomplete, so the
          -- client re-runs a full codeComplete pass on EVERY keystroke while the
          -- menu is open. 0 = unlimited + isIncomplete=false: one server pass per
          -- context, then pure client-side filtering. Only sane together with
          -- lazyResolveTextEdit (VS Code ships the same pair): text edits are
          -- computed at resolve/accept instead of eagerly for every proposal.
          -- A stable proposal store also ends the "Invalid completion proposal"
          -- SEVERE flood — those were resolves racing a store that the
          -- per-keystroke re-requests kept clearing.
          maxResults = 0,
          lazyResolveTextEdit = { enabled = true },
          -- Server default matches case-insensitively; firstLetter (the VS Code
          -- default) keeps the list smaller and better ranked.
          matchCase = "firstLetter",
        },
        -- Server default is ON (VS Code ships false): any future codelens refresh
        -- would run a workspace reference search per method. Parity guard.
        referencesCodeLens = { enabled = false },
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
