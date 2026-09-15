-- jdtls (eclipse.jdt.ls) on top of LazyVim's java extra.
--
-- Everything jdtls-specific lives in this one file, in four blocks. A new tweak
-- goes into one of them or does not go in:
--   1. JVM args         - how the server process is launched
--   2. settings         - what the server is told (vscode-java parity + this machine)
--   3. capabilities     - what the client claims it can do
--   4. client-side cuts - nvim traffic that jdt.ls handles badly
-- Request-level hacks (code-action dedup, test-command cache) are deliberately
-- NOT here: see plugin/jdtls-experimental.lua. perflog.lua is the instrument.
--
-- Background for block 2: jdt.ls is developed against vscode-java, which sends
-- its entire java.* settings section, defaults included. nvim-jdtls sends only
-- the keys set here and by LazyVim's java extra, so every other key is the
-- server's own constructor default (Preferences.java), and those differ from
-- what VS Code users get in a handful of places. Block 2 lists the ones that
-- matter. The extra itself contributes only inlayHints.parameterNames.enabled
-- = "all" (server default: literals), moot while Java is excluded from inlay
-- hints below.

return {
  -- 4. No inlay hints for Java: nvim re-requests hints for the whole document
  -- on every didChange flush, and LazyVim enables them for every filetype.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = opts.inlay_hints or {}
      opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
      table.insert(opts.inlay_hints.exclude, "java")
    end,
  },

  -- 4. jdt.ls emits a $/progress job for EVERY per-file validation and
  -- diagnostics publish - one toast per keystroke flush. Skip those two; real
  -- long-running progress (import, build) still shows.
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      for _, title in ipairs({ "Validate documents", "Publish Diagnostics" }) do
        table.insert(opts.routes, {
          filter = { event = "lsp", kind = "progress", find = title },
          opts = { skip = true },
        })
      end
    end,
  },

  {
    "mfussenegger/nvim-jdtls",
    -- 4. Treesitter folds for Java: jdt.ls registers foldingRange statically
    -- and nvim re-requests it for the whole document on every didChange flush.
    -- Same fold quality, zero server traffic.
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
        -- 1. JVM args. Several servers run at once (one per open project) on a
        -- RAM-bound box: cap the heap (unbounded, each grows toward 1/4 of
        -- RAM) and let idle servers give memory back (periodic GC, JEP 346;
        -- G1 is the JDK 21 default). mason's launcher hardcodes -Xms1G and a
        -- later flag wins. The shared jar index stops every workspace from
        -- re-indexing the same dependency jars (~1.7GB duplicated before).
        -- The last three are what vscode-java passes by default: a stray JVM
        -- log line on stdout would corrupt the JSON-RPC stream; skip the VM
        -- installation scan at startup; breadth-first Maven dependency
        -- collector (same result, faster).
        local shared_index = vim.fn.expand("~/.cache/jdtls-shared-index")
        vim.fn.mkdir(shared_index, "p")
        vim.list_extend(config.cmd, {
          "--jvm-arg=-Xmx2g",
          "--jvm-arg=-Xms256m",
          "--jvm-arg=-XX:G1PeriodicGCInterval=300000",
          "--jvm-arg=-Djdt.core.sharedIndexLocation=" .. shared_index,
          "--jvm-arg=-Xlog:disable",
          "--jvm-arg=-DDetectVMInstallationsJob.disabled=true",
          "--jvm-arg=-Daether.dependencyCollector.impl=bf",
        })

        -- 3. capabilities.
        config.capabilities = vim.tbl_deep_extend("force", config.capabilities or {}, {
          textDocument = {
            synchronization = {
              -- Never let :w block on the server: nvim sends willSaveWaitUntil
              -- synchronously from BufWritePre (1s cap) when the server declares
              -- it. Measured 2026-07-30: a busy jdtls answered after 34.6s and
              -- the editor froze. jdt.ls only uses it for java.saveActions (off
              -- here), so dropping it costs nothing.
              willSaveWaitUntil = false,
            },
          },
          workspace = {
            -- File watching. nvim on Linux does not advertise this (runtime
            -- lsp/protocol.lua), so jdt.ls registers no watchers and never
            -- learns about git checkouts, Maven-generated sources or pom edits
            -- made outside the buffer being edited; only a save in a module
            -- (m2e then refreshes that module) or :JdtUpdateConfig re-reads the
            -- disk. Enabled only with inotify-tools installed: nvim's libuv
            -- fallback applies the server's file globs to directories, so it
            -- would miss pom.xml, .classpath and target/generated-sources
            -- entirely. nvim fixes its backend the first time its watcher
            -- module loads, so restart nvim after installing inotify-tools;
            -- :checkhealth vim.lsp shows the active backend. No omakub
            -- installer ships the package yet (BACKLOG "jdtls follow-ups").
            didChangeWatchedFiles = {
              dynamicRegistration = vim.fn.executable("inotifywait") == 1,
            },
          },
        })
        -- jdt.ls sends RelativePattern watchers for three things: a
        -- Delete-only watcher per project whose baseUri is the project's PARENT
        -- directory, in-project CPE_LIBRARY jars (lib/*.jar checked into the
        -- repo; m2e container deps never take this path) and the files behind
        -- java.format.settings.url / java.settings.url (unset here). Only the
        -- first occurs on a Maven setup, and it is harmful: nvim spawns a
        -- recursive inotifywait per distinct baseUri, so for a repo whose
        -- parent holds many other repos that would watch the entire parent
        -- (tens of thousands of directories against the 65536 inotify watch
        -- limit), and the pattern can never match anyway (uri_to_fname keeps
        -- the trailing slash, so nvim builds '<parent>//<repo>'). Drop every
        -- RelativePattern; keep the string globs, which nvim applies to
        -- root_dir. Until inotify-tools lands somewhere this has only run
        -- against synthetic registrations, never a live server.
        config.handlers = vim.tbl_extend("force", config.handlers or {}, {
          ["client/registerCapability"] = function(err, params, ctx)
            for _, reg in ipairs(params.registrations or {}) do
              local ro = reg.method == "workspace/didChangeWatchedFiles" and reg.registerOptions
              if type(ro) == "table" and ro.watchers then
                ro.watchers = vim.tbl_filter(function(w)
                  return type(w.globPattern) == "string"
                end, ro.watchers)
              end
            end
            return vim.lsp.handlers["client/registerCapability"](err, params, ctx)
          end,
        })

        -- 4. jdt.ls asks the client to run this after reloading bundles and
        -- expects the list of bundles to reload; VS Code returns an empty list.
        -- Without it every start answers "Command not supported on client".
        config.commands = vim.tbl_extend("force", config.commands or {}, {
          ["_java.reloadBundles.command"] = function()
            return {}
          end,
        })
        -- 4. LazyVim's `$MASON/share/java-test/*.jar` glob feeds jdtls two
        -- non-OSGi jars its bundle loader rejects on every startup ("Failed to
        -- load extension bundles"); the nvim-jdtls README says to exclude them.
        if config.init_options and config.init_options.bundles then
          config.init_options.bundles = vim.tbl_filter(function(jar)
            return not (jar:match("jacocoagent") or jar:match("runner%-jar%-with%-dependencies"))
          end, config.init_options.bundles)
        end

        return config
      end,

      -- 4. No semantic tokens from jdtls: nvim re-requests full-document tokens
      -- on every didChange flush (jdt.ls has no delta support), a whole-file
      -- AST walk that mostly dies mid-typing and is recomputed. Treesitter
      -- already highlights Java; only semantic modifiers are lost.
      on_attach = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if client then
          vim.lsp.semantic_tokens.enable(false, { client_id = client.id })
        end
      end,

      -- Don't hot-swap classes on every save while debugging (rebuild+redefine
      -- over JDWP stalls each save); restart the session to pick up edits.
      dap = { hotcodereplace = "off" },
      -- The main-class scan is a performance killer on large projects.
      dap_main = false,

      -- 2. settings.
      settings = {
        java = {
          -- vscode-java parity: keys the reference client sends by default
          -- where jdt.ls's own default differs.
          -- nvim cannot register signature help dynamically, so jdt.ls always
          -- advertises it; this decides whether the handler answers (AST
          -- lookup, codeComplete fallback) or returns empty. noice already
          -- requests it on every "(" and ","; <c-k> asks on demand. If those
          -- trigger requests ever hitch, the one lever is noice's
          -- lsp.signature.auto_open.trigger = false, not this key.
          signatureHelp = { enabled = true },
          -- Server default re-validates EVERY open buffer on each change: that
          -- was the "every keystroke checks multiple files" lag.
          edit = { validateAllOpenBuffersOnChanges = false },
          completion = {
            -- Server default caps at 50 and marks every list incomplete, so the
            -- client re-ran a full completion pass per keystroke. VS Code uses
            -- 0 (unlimited); 2000 keeps virtually every real context in one
            -- pass while bounding pathological ones (perf.log 2026-07-30: one
            -- unbounded generic context serialized the whole 338-jar classpath,
            -- 4.9s and a +5.4GB transient Lua spike that never returned).
            maxResults = 2000,
            lazyResolveTextEdit = { enabled = true },
            matchCase = "firstLetter",
            guessMethodArguments = "insertBestGuessedArguments",
            importOrder = { "#", "java", "javax", "org", "com", "" },
            favoriteStaticMembers = {
              "org.junit.Assert.*",
              "org.junit.Assume.*",
              "org.junit.jupiter.api.Assertions.*",
              "org.junit.jupiter.api.Assumptions.*",
              "org.junit.jupiter.api.DynamicContainer.*",
              "org.junit.jupiter.api.DynamicTest.*",
              "org.mockito.Mockito.*",
              "org.mockito.ArgumentMatchers.*",
              "org.mockito.Answers.*",
            },
          },

          -- This machine.
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
          -- The server's four defaults plus build output dirs, so project
          -- discovery never picks up poms copied into build/ or target/.
          -- The list replaces the default, it does not merge with it.
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
