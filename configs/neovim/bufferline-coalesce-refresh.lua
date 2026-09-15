-- bufferline.nvim's diagnostics.get() (diagnostics.lua) calls vim.diagnostic.get()
-- with no bufnr filter - a full scan of every diagnostic in the workspace, not
-- just the buffers shown in the tabline. Against a large multi-module jdtls
-- project that publishes diagnostics for every source file (not just open
-- buffers), that scan runs over ~400k diagnostic entries across ~1250 buffers
-- (confirmed live via `nvim --server --remote-expr` on 2026-09-01, dwmp project).
--
-- bufferline.ui.M.refresh() just does `vim.schedule(redrawtabline)`, and nothing
-- coalesces repeated calls - every jdtls $/progress / workDoneProgress
-- notification (jdtls sends dozens per burst while indexing/running tests)
-- re-triggers it. perf.log's QUEUE probe caught 18-55s CPU-pinned stalls with
-- 16-34% of samples in this exact chain (bufferline/buffers.lua -> ui.lua:130),
-- correlating with progress-notification bursts ($/progress n=45 in one 22s
-- window) - the editor "getting slower" over a long jdtls session.
--
-- Root cause is the O(all-workspace-diagnostics) scan on every refresh; the
-- surgical fix (without patching vendored plugin internals, which lazy.nvim
-- overwrites on update) is the same one already applied to document_highlight
-- in lsp-coalesce-highlight.lua: coalesce bursts into one redraw instead of one
-- per trigger.
if vim.g.bufferline_coalesce_refresh == false then
  return
end

local COALESCE_MS = 150

-- bufferline.nvim lazy-loads on BufAdd/TabEnter, so `require("bufferline.ui")`
-- at plugin/ startup time would run before lazy.nvim has added it to the
-- runtimepath. Patch it once lazy.nvim actually loads the plugin instead.
local function patch()
  local ok, ui = pcall(require, "bufferline.ui")
  if not ok then
    return
  end
  local timer
  ui.refresh = function()
    if not timer then
      timer = assert(vim.uv.new_timer())
    end
    timer:stop()
    timer:start(COALESCE_MS, 0, function()
      vim.schedule(function()
        pcall(vim.cmd.redrawtabline)
      end)
    end)
  end
end

if package.loaded["bufferline.ui"] then
  patch()
else
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyLoad",
    callback = function(ev)
      if ev.data == "bufferline.nvim" then
        patch()
      end
    end,
  })
end
