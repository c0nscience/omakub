return {
  -- Cut the per-keystroke request fan-out for Java. Measured with an LspRequest/
  -- LspNotify tally: every didChange flush also fired textDocument/foldingRange
  -- (LazyVim sets foldexpr to vim.lsp.foldexpr) and textDocument/inlayHint, both
  -- whole-document requests. On a warm server each answers in ~ms; on a server
  -- that is importing or partially paged out they queue and the editor feels
  -- dead. Java gets treesitter folds (same fold quality, zero server traffic)
  -- and no inlay hints; every other language keeps LazyVim defaults.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = opts.inlay_hints or {}
      opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
      table.insert(opts.inlay_hints.exclude, "java")
    end,
  },

  {
  "mfussenegger/nvim-jdtls",
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function()
        vim.opt_local.foldmethod = "expr"
        vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      end,
    })
  end,
  opts = {
    jdtls = function(config)
      -- Never let :w block on the server. nvim core sends willSaveWaitUntil
      -- SYNCHRONOUSLY from BufWritePre (runtime lsp.lua:927 request_sync,
      -- 1s cap per save) when the server declares the capability. Measured on
      -- 2026-07-30 14:40 via perf.log: jdtls, busy after a test run, answered
      -- after 34.6s - the save timed out, the error popup mounted mid-storm and
      -- the editor froze. jdtls only uses willSaveWaitUntil to return
      -- java.saveActions edits (organize imports on save - off here), so
      -- dropping the client capability costs nothing and the server then never
      -- registers the request.
      config.capabilities = vim.tbl_deep_extend("force", config.capabilities or {}, {
        textDocument = {
          synchronization = {
            willSaveWaitUntil = false,
          },
        },
      })

      -- NOTE: jdt_uri_timeout_ms is deliberately left at its 5000ms default.
      -- Lowering it looks tempting because open_classfile vim.waits on it per
      -- jdt:// buffer (jdtls.lua:1282) and snacks' picker bufloads every jdt://
      -- result. But vim.wait does pump the scheduled callback queue even nested
      -- inside another LSP handler (verified with a stub server: a nested request
      -- answered in 201ms, not the timeout), so a full burn means the server did
      -- not answer java/classFileContents at all - which a shorter timeout cannot
      -- fix. It would only trade the freeze for blank picker rows and an empty
      -- buffer, and it also gates the wait-for-client-attach at jdtls.lua:1247,
      -- where expiring early hard-errors the BufReadCmd via assert(client).
      -- The real trigger was source attachment; see maven/eclipse downloadSources
      -- below. If library-heavy pickers freeze again, fix the picker path (skip
      -- the wait when the buffer is not displayed) rather than the timeout.

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
      -- ~7x/s. Must live on the config, not LspAttach: nvim captures the debounce
      -- at didOpen - before LspAttach fires - and thereafter only ever lowers it.
      -- Two limits worth knowing (_changetracking.lua:47-52, 137):
      -- change tracking is grouped by sync-kind + position-encoding ACROSS clients,
      -- and the group takes the MINIMUM debounce, so as soon as any default-flags
      -- server (lua_ls, jsonls, ...) attaches anywhere in the session the group
      -- drops back to 150ms for jdtls too - and until then this 300ms throttles
      -- those other clients as well. Also, every outgoing request force-flushes
      -- pending changes (client.lua:731), so completion can never read stale text
      -- and each new completion context bypasses the debounce anyway; the only
      -- cost here is up to +150ms of diagnostic/inlay-hint lag.
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

      -- jdtls contributes several generate actions TWICE: once as an Eclipse
      -- quick assist (kind "quickassist") and once as a VS Code source action
      -- (kind "source.*"). VS Code shows only one set because it groups the menu
      -- by kind; nvim requests no kind filter and renders the response flat, so
      -- each of those appeared twice in the picker.
      -- Drop the quickassist copy only when a same-titled source action carries
      -- an IDENTICAL command: that holds for the constructors, toString,
      -- hashCodeEquals, overrideMethods and delegateMethods families, where both
      -- copies just invoke the same java.action.* and the duplicate is pure noise.
      -- Matching on the title ALONE over-reaches: the accessors family
      -- ("Generate Getters"/"Setters"/"Getters and Setters") carries no command
      -- (resolve-only) and its two copies are NOT equivalent - the quickassist is
      -- scoped to the SELECTED fields while the source action covers the whole
      -- type. Verified via codeAction/resolve on a selection of 2 of 3 fields:
      -- quickassist -> getB()+getC(), source action -> getA()+getB()+getC().
      -- Those stay duplicated on purpose; collapsing them would silently widen
      -- the edit and make the selection-scoped action unreachable.
      -- Done at the response level because code_action's own `filter` sees one
      -- action at a time and therefore cannot know whether a twin exists.
      if not client.omakub_dedup_code_actions then
        client.omakub_dedup_code_actions = true
        local unpack = table.unpack or unpack
        local request = client.request

        local function dedup(result)
          if type(result) ~= "table" then
            return result
          end
          local twin = {}
          for _, action in ipairs(result) do
            if action.title and action.kind and action.kind ~= "quickassist" and type(action.command) == "table" then
              twin[action.title] = action.command
            end
          end
          return vim.tbl_filter(function(action)
            return not (
              action.kind == "quickassist"
              and type(action.command) == "table"
              and vim.deep_equal(action.command, twin[action.title])
            )
          end, result)
        end

        -- Both call forms have to survive: nvim core uses client:request(...),
        -- while nvim-jdtls' own util.lua still uses the deprecated no-self
        -- client.request(...), so the method is either the 1st or 2nd argument.
        client.request = function(...)
          local argc = select("#", ...)
          local argv = { ... }
          local base = type(argv[1]) == "string" and 0 or 1
          if argv[base + 1] == "textDocument/codeAction" and type(argv[base + 3]) == "function" then
            local handler = argv[base + 3]
            argv[base + 3] = function(err, result, ctx, config)
              return handler(err, dedup(result), ctx, config)
            end
          end
          return request(unpack(argv, 1, argc))
        end
      end
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
          -- The server's default cap of 50 marks every list incomplete, so the
          -- client re-ran a full codeComplete pass per keystroke (and the
          -- resulting store churn caused the "Invalid completion proposal"
          -- SEVERE flood). 0 (= unlimited, the VS Code default) fixed that but
          -- had no ceiling at all: perf.log 2026-07-30 16:10 caught a generic
          -- context in a god-class serializing the whole 338-jar classpath -
          -- a 4.9s completion followed by a +5.4GB transient Lua spike, and
          -- LuaJIT arena memory never returns to the OS at that scale (that is
          -- where the recurring 6-8GB nvim processes came from; heap collapses
          -- back to ~80MB, RSS stays). 2000 keeps virtually every real context
          -- below the cap (single pass, isIncomplete=false, stable store) while
          -- bounding the pathological ones at a few MB instead of gigabytes.
          maxResults = 2000,
          lazyResolveTextEdit = { enabled = true },
          -- Server default matches case-insensitively; firstLetter (the VS Code
          -- default) keeps the list smaller and better ranked.
          matchCase = "firstLetter",
          -- Caveat of maxResults=0: there is then NO server-side cap, so a
          -- one-letter prefix against a large classpath returns everything in one
          -- multi-MB response. Still cheaper than a full ECJ pass per keystroke,
          -- but set a finite limit here if huge unprefixed completions ever hitch.
        },
        -- Server default is ON (VS Code ships false): any future codelens refresh
        -- would run a workspace reference search per method. Parity guard.
        referencesCodeLens = { enabled = false },
        -- Shrinks per-request server compute, but NOT the cadence: nvim re-requests
        -- hints for the WHOLE document on every didChange flush (inlay_hint.lua:93,
        -- 266) and LazyVim enables hints for every filetype. If per-keystroke cost
        -- ever needs to go further, `opts.inlay_hints.exclude = { "java" }` on the
        -- LazyVim lsp spec drops the request entirely - stronger, at the price of
        -- having no Java inlay hints at all.
        inlayHints = {
          parameterNames = { enabled = "literals" },
        },
        -- NOTE: no forceBuildBeforeLaunch here on purpose. It is a vscode-java-debug
        -- CLIENT setting (VS Code calls the java.buildWorkspace command itself), not
        -- a jdt.ls preference - absent from Preferences and from java-debug's
        -- DebugSettings, so sending it does nothing. nvim-jdtls never builds before
        -- launch either, so a test started right after an edit races the async
        -- autobuild and can run stale classes. Wire require("jdtls").compile() into
        -- the test keymaps if that ever bites.
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
  },
}
