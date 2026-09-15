-- jdtls request-level hacks. These are NOT configuration: each one wraps
-- client.request for the jdtls client and changes what nvim sends or shows.
-- They live here, apart from lua/plugins/java.lua, so the config file stays
-- config and each hack can be re-measured or dropped on its own. Delete this
-- file (or set vim.g.jdtls_experimental = false) to remove both.
--
--   1. code-action dedup: jdtls returns several generate actions twice
--      (quickassist + source.*); VS Code groups by kind, nvim shows a flat list.
--   2. test-command cache: serve the java-test launch commands from cache and
--      refresh in the background (4.1-24s per test start measured 2026-07-30).
if vim.g.jdtls_experimental == false then
  return
end

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("omakub_jdtls_experimental", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or client.name ~= "jdtls" then
      return
    end
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

      -- Measured 2026-07-30: every test start paid 4.1-24s inside jdt.ls's
      -- resolveJUnitLaunchArguments (plus findTestTypesAndMethods and
      -- getClasspaths), recomputing the 48-module classpath behind the build
      -- queue on EVERY run. The responses are pure functions of their
      -- arguments (the TestRunner port is substituted client-side per run,
      -- nvim-jdtls dap.lua:455), so serve them from cache instantly and
      -- refresh in the background: each run then waits only on the JVM and
      -- the test (~2-3s), and the recomputation happens off the critical
      -- path. A pom change is picked up one run late - self-healing.
      local TEST_CMD_CACHE = {
        ["vscode.java.test.findTestTypesAndMethods"] = true,
        ["vscode.java.test.search.codelens"] = true,
        ["vscode.java.test.junit.argument"] = true,
        ["java.project.getClasspaths"] = true,
      }
      local cache, cache_keys = {}, {}
      local perfpath = vim.fs.joinpath(vim.fn.stdpath("state"), "perf.log")
      local function perflog(line)
        local f = io.open(perfpath, "a")
        if f then
          f:write(os.date("%Y-%m-%dT%H:%M:%S") .. " TESTC " .. line .. "\n")
          f:close()
        end
      end

      -- Both call forms have to survive: nvim core uses client:request(...),
      -- while nvim-jdtls' own util.lua still uses the deprecated no-self
      -- client.request(...), so the method is either the 1st or 2nd argument.
      client.request = function(...)
        local argc = select("#", ...)
        local argv = { ... }
        local base = type(argv[1]) == "string" and 0 or 1
        local method, params, handler = argv[base + 1], argv[base + 2], argv[base + 3]

        if method == "textDocument/codeAction" and type(handler) == "function" then
          argv[base + 3] = function(err, result, ctx, config)
            return handler(err, dedup(result), ctx, config)
          end
        elseif
          method == "workspace/executeCommand"
          and type(params) == "table"
          and TEST_CMD_CACHE[params.command]
          and type(handler) == "function"
        then
          local key = params.command .. "\0" .. vim.json.encode(params.arguments or {})
          local hit = cache[key]
          local t0 = vim.uv.hrtime()
          if hit ~= nil then
            -- serve the cached result now; the real request below only
            -- refreshes the cache
            vim.schedule(function()
              handler(nil, vim.deepcopy(hit), { client_id = client.id, method = method, params = params })
            end)
            argv[base + 3] = function(err, result)
              if not err and result ~= nil then
                cache[key] = result
              end
              perflog(("hit %s (refresh %.0fms)"):format(params.command, (vim.uv.hrtime() - t0) / 1e6))
            end
          else
            argv[base + 3] = function(err, result, ctx, config)
              if not err and result ~= nil then
                if #cache_keys >= 40 then
                  cache[table.remove(cache_keys, 1)] = nil
                end
                cache[key] = result
                table.insert(cache_keys, key)
              end
              perflog(("miss %s (%.0fms)"):format(params.command, (vim.uv.hrtime() - t0) / 1e6))
              return handler(err, result, ctx, config)
            end
          end
        end
        return request(unpack(argv, 1, argc))
      end
    end
  end,
})
