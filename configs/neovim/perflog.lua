-- Always-on, low-overhead runtime log for diagnosing editor slowness.
-- Writes single-line, greppable records to $XDG_STATE_HOME/nvim/perf.log so a
-- freeze can be diagnosed after the fact instead of by re-instrumenting a live
-- instance. Disable with `vim.g.perflog = false` before this file is sourced.
--
-- It records exactly the failure modes that have actually bitten this setup:
--   STALL - the main loop stopped servicing events, with the interrupted Lua
--           stack. Fast-event timers still fire inside vim.wait, so for the
--           common case (a plugin blocking in vim.wait/getchar) the timer fires
--           DURING the block and the stack names the culprit. For a hard block
--           (uv.sleep, a C loop) the timer only runs afterwards, so the duration
--           is real but the stack shows just this file - absence of a culprit
--           frame is not absence of a cause.
--   SLOW  - an LSP request that took too long to answer (a slow/never-answering
--           server looks identical to an editor freeze from the user's seat).
--   MEM   - resident memory / Lua heap / buffer counts, logged on significant
--           growth. A picker that mass-adds buffers, or memory that climbs and
--           never returns, shows up here with a timestamp.
if vim.g.perflog == false then
  return
end

local M = {}

local STALL_MS = 1000 -- log a main-loop gap longer than this
local SLOW_REQUEST_MS = 1000 -- log an LSP request slower than this
local SAMPLE_MS = 30000 -- memory/buffer sampling interval
local HEARTBEAT_MS = 600000 -- log a sample at least this often
local RSS_GROWTH_MB = 250 -- log a sample when RSS grew by this much
local BUF_GROWTH = 100 -- log a sample when buffer count grew by this much
local MAX_LOG_BYTES = 4 * 1024 * 1024

local path = vim.fs.joinpath(vim.fn.stdpath("state"), "perf.log")
local fh

local function open_log()
  -- rotate rather than grow without bound; one generation is enough to cover
  -- "it hung a few minutes ago"
  local st = vim.uv.fs_stat(path)
  if st and st.size > MAX_LOG_BYTES then
    pcall(vim.uv.fs_rename, path, path .. ".old")
  end
  fh = io.open(path, "a")
  return fh
end

local function write(kind, fmt, ...)
  if not fh and not open_log() then
    return
  end
  local ok, line = pcall(string.format, fmt, ...)
  if not ok then
    return
  end
  fh:write(("%s %-5s %s\n"):format(os.date("%Y-%m-%dT%H:%M:%S"), kind, line))
  fh:flush()
end
M.write = write

-- Session header: the same config behaves differently per project, so record
-- which one this is.
write("START", "nvim %s pid=%d cwd=%s", tostring(vim.version()), vim.uv.os_getpid(), vim.uv.cwd() or "?")

--- STALL detection -----------------------------------------------------------
-- A uv timer is a fast event, so it keeps firing while the main loop is blocked
-- in vim.wait/getchar; the gap between fires measures starvation, and
-- debug.traceback from inside the callback captures whatever Lua is stuck.
do
  local timer = assert(vim.uv.new_timer())
  local last = vim.uv.hrtime()
  timer:start(250, 250, function()
    local now = vim.uv.hrtime()
    local gap = (now - last) / 1e6
    last = now
    if gap > STALL_MS then
      local ok, tb = pcall(debug.traceback, "", 2)
      local stack = (ok and tb or ""):gsub("%s+", " "):sub(1, 600)
      write("STALL", "%.0fms blocked | %s", gap, stack)
    end
  end)
end

--- LSP request latency ------------------------------------------------------
-- LspRequest is the documented hook (:h LspRequest) - no wrapping of internals.
do
  local pending = {}
  local stats = {}
  M.stats = stats

  vim.api.nvim_create_autocmd("LspRequest", {
    group = vim.api.nvim_create_augroup("perflog_lsp", { clear = true }),
    callback = function(ev)
      local d = ev.data
      if not d or not d.request then
        return
      end
      local key = d.client_id .. ":" .. d.request_id
      if d.request.type == "pending" then
        pending[key] = { t = vim.uv.hrtime(), method = d.request.method }
      else
        local p = pending[key]
        pending[key] = nil
        if not p then
          return
        end
        local ms = (vim.uv.hrtime() - p.t) / 1e6
        local s = stats[p.method]
        if not s then
          s = { n = 0, total = 0, max = 0, cancelled = 0 }
          stats[p.method] = s
        end
        s.n = s.n + 1
        s.total = s.total + ms
        if ms > s.max then
          s.max = ms
        end
        if d.request.type == "cancel" then
          s.cancelled = s.cancelled + 1
        end
        if ms > SLOW_REQUEST_MS then
          local client = vim.lsp.get_client_by_id(d.client_id)
          write("SLOW", "%s %.0fms client=%s type=%s buf=%s", p.method, ms,
            client and client.name or d.client_id, d.request.type,
            vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf or 0), ":t"))
        end
      end
    end,
  })
end

--- Memory / buffer growth ---------------------------------------------------
do
  local timer = assert(vim.uv.new_timer())
  local last_rss, last_bufs, last_report = 0, 0, 0

  local function sample()
    local rss = vim.uv.resident_set_memory() / 1048576
    local bufs = vim.api.nvim_list_bufs()
    local loaded = 0
    for _, b in ipairs(bufs) do
      if vim.api.nvim_buf_is_loaded(b) then
        loaded = loaded + 1
      end
    end
    local now = vim.uv.now()
    local grew = (rss - last_rss) >= RSS_GROWTH_MB or (#bufs - last_bufs) >= BUF_GROWTH
    if grew or (now - last_report) > HEARTBEAT_MS then
      local names = {}
      for _, c in ipairs(vim.lsp.get_clients()) do
        names[#names + 1] = c.name
      end
      write("MEM", "rss=%.0fMB (%+.0f) lua=%.0fMB bufs=%d/%d (%+d) lsp=%s", rss, rss - last_rss,
        collectgarbage("count") / 1024, loaded, #bufs, #bufs - last_bufs,
        #names > 0 and table.concat(names, ",") or "-")
      last_rss, last_bufs, last_report = rss, #bufs, now
    end
  end

  timer:start(SAMPLE_MS, SAMPLE_MS, function()
    -- buffer/LSP APIs are not allowed on the fast path
    vim.schedule(function()
      pcall(sample)
    end)
  end)
end

--- :PerfLog ----------------------------------------------------------------
vim.api.nvim_create_user_command("PerfLog", function(cmd)
  if cmd.args == "stats" then
    local rows = {}
    for method, s in pairs(M.stats) do
      rows[#rows + 1] = { method = method, n = s.n, mean = s.total / s.n, max = s.max, cancelled = s.cancelled }
    end
    table.sort(rows, function(a, b) return a.max > b.max end)
    local out = { ("%-46s %6s %9s %9s %6s"):format("method", "n", "mean", "max", "cancl") }
    for _, r in ipairs(rows) do
      out[#out + 1] = ("%-46s %6d %7.0fms %7.0fms %6d"):format(r.method, r.n, r.mean, r.max, r.cancelled)
    end
    out[#out + 1] = ("rss=%.0fMB lua=%.0fMB"):format(
      vim.uv.resident_set_memory() / 1048576, collectgarbage("count") / 1024)
    vim.notify(table.concat(out, "\n"))
  else
    vim.cmd.tabedit(path)
  end
end, {
  nargs = "?",
  complete = function() return { "stats" } end,
  desc = "Open the runtime perf log (:PerfLog stats for in-session LSP latency)",
})

return M
