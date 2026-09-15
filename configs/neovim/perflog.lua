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

-- Every nvim instance appends to the same perf.log, so without a pid a record
-- cannot be attributed to a process - a mistake already made once when reading
-- this log. Stamp all of them, not just START.
local pid = vim.uv.os_getpid()
local written = 0

local function write(kind, fmt, ...)
  if not fh and not open_log() then
    return
  end
  local ok, line = pcall(string.format, fmt, ...)
  if not ok then
    return
  end
  fh:write(("%s [%d] %-5s %s\n"):format(os.date("%Y-%m-%dT%H:%M:%S"), pid, kind, line))
  fh:flush()
  -- open_log() only checks the size at startup, so a long-lived session used to
  -- grow the log without bound; re-check occasionally.
  written = written + 1
  if written % 256 == 0 then
    local st = vim.uv.fs_stat(path)
    if st and st.size > MAX_LOG_BYTES then
      fh:close()
      fh = nil
      pcall(vim.uv.fs_rename, path, path .. ".old")
    end
  end
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
    -- DAP's console='integratedTerminal' (nvim-jdtls dap.lua:646) pipes the
    -- debuggee's raw stdout/stderr straight into a :terminal-backed buffer via
    -- nvim-dap's terminals.acquire (session.lua) - a path the wire= (LSP JSON-RPC)
    -- and TESTS (DAP junit output-event) probes below never see, since it isn't
    -- LSP traffic at all. A runaway/looping test spewing to stdout would balloon
    -- memory here invisibly to both. Measured to test that hypothesis.
    local term_bytes, term_bufs = 0, 0
    for _, b in ipairs(bufs) do
      if vim.api.nvim_buf_is_loaded(b) then
        loaded = loaded + 1
        if vim.bo[b].buftype == "terminal" then
          term_bufs = term_bufs + 1
          term_bytes = term_bytes + vim.api.nvim_buf_get_offset(b, vim.api.nvim_buf_line_count(b))
        end
      end
    end
    local now = vim.uv.now()
    local grew = (rss - last_rss) >= RSS_GROWTH_MB or (#bufs - last_bufs) >= BUF_GROWTH
    if grew or (now - last_report) > HEARTBEAT_MS then
      local names = {}
      for _, c in ipairs(vim.lsp.get_clients()) do
        names[#names + 1] = c.name
      end
      local b = M.stall_buckets or { 0, 0, 0 }
      local freezes = ""
      if b[1] + b[2] + b[3] > 0 then
        freezes = (" freezes=%d/%d/%d(.25-.5s/.5-1s/>1s)"):format(b[1], b[2], b[3])
        b[1], b[2], b[3] = 0, 0, 0
      end
      local term = term_bufs > 0 and (" term=%dbuf/%.0fMB"):format(term_bufs, term_bytes / 1048576) or ""
      write("MEM", "rss=%.0fMB (%+.0f) lua=%.0fMB bufs=%d/%d (%+d) lsp=%s%s%s", rss, rss - last_rss,
        collectgarbage("count") / 1024, loaded, #bufs, #bufs - last_bufs,
        #names > 0 and table.concat(names, ",") or "-", freezes, term)
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

--- QUEUE - scheduled-queue starvation --------------------------------------
-- The two records above cannot see the failure mode that actually eats the RAM.
-- vim/lsp/rpc.lua reads the server pipe in a libuv callback, vim.json.decode's
-- every frame there (fast context), and only then hands the DECODED table to
-- vim.schedule (rpc.lua:584 for notifications, :324 for responses). Nothing in
-- neovim throttles that read: there is no read_stop outside EOF. So whenever
-- libuv keeps getting polled while loop->events is NOT drained, decoded payloads
-- pile up ALIVE in the schedule queue and the Lua heap tracks the wire at ~2.86x.
--
-- Two sufficient conditions, both reproduced on 0.12.4 against a chatty server:
--   * any ordinary blocking builtin - vim.fn.system/systemlist, :sort, :s//ge,
--     a search loop, vim.wait(..., fast_only=true). 6s of vim.fn.system decoded
--     799MB into 2285MB of live heap with ZERO handlers run.
--     (A genuine hard block - uv.sleep - accumulates nothing: nvim stops reading
--     and the kernel socket buffer backpressures the server. So STALL and this
--     are near-disjoint, which is why STALL never fires on a spike.)
--   * no block at all - merely arrival rate > drain rate. An idle healthy loop
--     with a fast producer reached lua=6119MB in 15s.
--
-- STALL cannot catch either: max fast-timer gap in every accumulating run was
-- 258-422ms, under STALL_MS. MEM cannot either: it is itself a vim.schedule
-- callback (see above), so it runs at its own FIFO position mid-drain and its
-- lua= is a lower bound - a run whose MEM read 1328MB truly peaked at 3158MB.
--
-- This probe measures the schedule ROUND TRIP, samples the peak from fast
-- context, and names the payload that filled the queue. Set
-- vim.g.perflog_queue = false to skip it (it wraps vim.json.decode, which every
-- plugin uses; the timer half alone is harmless, the wrapper is the risky half).
if vim.g.perflog_queue ~= false and not vim.g.perflog_queue_loaded then
  vim.g.perflog_queue_loaded = true
  local QUEUE_MS = 1000

  -- Per-method wire bytes, counted in the read callback. rpc.lua:374 is
  -- `pcall(vim.json.decode, body)`, resolved through vim.json at call time, so
  -- this is the only hook that sees a message before it is queued. Counting is
  -- gated on an outstanding round trip so the steady state costs one nil test.
-- x86_64 /proc field offsets, verified 2026-08-25: splitting /proc/self/stat
-- after the "(comm)" field makes token i equal stat field i+2, so minflt=8,
-- majflt=10, utime=12, stime=13. CLK_TCK is 100 on every Linux/x86_64 build.
local CLK_TCK = 100

-- An earlier version of this probe reported the syscall from /proc/self/syscall.
-- That field is worthless and every "in=read" in the log before 2026-08-25 is an
-- artefact: a task reading its OWN syscall file is by definition inside read(2),
-- so it can only ever report read. Nothing can name the main thread's syscall
-- from inside the main thread; /proc/<pid>/syscall for another process needs
-- ptrace permission, which Yama denies for a non-ancestor. What CAN be measured
-- from in-process, and answers the same question better, is whether the stall
-- burned CPU or waited:
--   cpu%  ~100 - nvim is computing (a Lua/C hot loop: a quadratic concat, a
--                giant gsub, a GC walk over a multi-GB heap)
--   cpu%  ~0   - nvim is not running at all: blocked on I/O, or descheduled
--   sysmem%    - fraction of the window the WHOLE machine was stalled on memory
--                (/proc/pressure/memory "full"). High here with cpu% low means
--                the freeze is the box thrashing, not anything nvim did.
local function proc_self_stat()
  local f = io.open("/proc/self/stat")
  if not f then
    return
  end
  local s = f:read("*l")
  f:close()
  local rest = s and s:match("%)%s+(.*)")
  if not rest then
    return
  end
  local t, i = {}, 0
  for w in rest:gmatch("%S+") do
    i = i + 1
    t[i] = w
  end
  return tonumber(t[10]) or 0, ((tonumber(t[12]) or 0) + (tonumber(t[13]) or 0)) / CLK_TCK
end

-- cumulative microseconds during which EVERY task was stalled on memory
local function psi_full_us()
  local f = io.open("/proc/pressure/memory")
  if not f then
    return
  end
  local v
  for line in f:lines() do
    v = line:match("^full.*total=(%d+)") or v
  end
  f:close()
  return tonumber(v) or 0
end

-- Attribution. Everything above says a stall HAPPENED and whether it burned
-- CPU; nothing says WHAT ran. debug.traceback from the uv timer cannot answer
-- it - the timer callback is entered from C, so the traceback shows only this
-- file. LuaJIT's own sampling profiler can: jit.profile samples the real VM
-- stack on its own interval, independent of who called whom.
--   vmstate N/I = running Lua (compiled / interpreted) -> a plugin is the cost
--   vmstate G   = garbage collector -> the heap is the cost, not any one call
--   vmstate C   = inside a C function -> nvim core or a C library
--   vmstate J   = the JIT compiler itself
--
-- It runs CONTINUOUSLY into a ring buffer rather than being armed on demand.
-- Arming does not work: a burst that allocates GBs inside one uninterrupted
-- Lua call finishes before any timer can fire to start the profiler, so the
-- record comes back empty for exactly the event worth catching (measured).
-- A ring lets each consumer aggregate the window it cares about after the fact.
-- Set vim.g.perflog_profile = false to skip it.
local PROF_INTERVAL = "i20" -- 50 samples/sec
local PROF_RING = 4096 -- ~80s of history
local PROF_DEPTH = 8

local prof = { n = 0, t = {}, s = {}, v = {} }
local ok_prof, jitprof = pcall(require, "jit.profile")
if ok_prof and vim.g.perflog_profile ~= false then
  local now = vim.uv.hrtime
  ok_prof = pcall(jitprof.start, "l" .. PROF_INTERVAL, function(th, samples, vmstate)
    local ok, s = pcall(jitprof.dumpstack, th, "pl;", PROF_DEPTH)
    local i = prof.n % PROF_RING + 1
    prof.n = prof.n + 1
    prof.t[i], prof.s[i], prof.v[i] = now(), ok and s or "?", vmstate
  end)
else
  ok_prof = false
end

-- aggregate every sample newer than `since` (hrtime) into a one-line summary
local function prof_since(since)
  if not ok_prof then
    return nil
  end
  local stacks, states, total = {}, {}, 0
  local lo = prof.n > PROF_RING and prof.n - PROF_RING or 0
  for k = lo, prof.n - 1 do
    local i = k % PROF_RING + 1
    if prof.t[i] and prof.t[i] >= since then
      total = total + 1
      local s = prof.s[i]
      stacks[s] = (stacks[s] or 0) + 1
      local v = prof.v[i]
      states[v] = (states[v] or 0) + 1
    end
  end
  if total == 0 then
    return nil
  end
  local rows = {}
  for k, v in pairs(stacks) do
    rows[#rows + 1] = { k, v }
  end
  table.sort(rows, function(a, b)
    return a[2] > b[2]
  end)
  local st = {}
  for k, v in pairs(states) do
    st[#st + 1] = ("%s=%d%%"):format(k, v / total * 100)
  end
  table.sort(st)
  local out = { ("n=%d vm[%s]"):format(total, table.concat(st, " ")) }
  for i = 1, math.min(#rows, 3) do
    out[#out + 1] = ("%d%% %s"):format(rows[i][2] / total * 100, (rows[i][1]:gsub("%s+", "")))
  end
  return table.concat(out, " | ")
end

local wire, worst, stack, queued_at, peak_lua, peak_rss = {}, nil, nil, nil, 0, 0
local stall_buckets = { 0, 0, 0 }
M.stall_buckets = stall_buckets
local base_maj, base_cpu, base_psi = 0, 0, 0
local orig_decode = vim.json.decode
vim.json.decode = function(s, ...)
  local v = orig_decode(s, ...)
  if queued_at and type(v) == "table" and type(s) == "string" then
    local k = v.method or (v.id and "response" or "?")
    local e = wire[k]
    if e then
      e[1], e[2] = e[1] + 1, e[2] + #s
    else
      wire[k] = { 1, #s }
    end
    -- one giant payload and a flood of small ones look identical in the
    -- totals; the largest single frame tells them apart
    if not worst or #s > worst[2] then
      worst = { k, #s }
    end
  end
  return v
end

-- SPIKE - the allocation burst, caught while it is happening.
-- QUEUE only fires when a schedule round trip is late, and MEM samples every
-- 30s from inside vim.schedule, so a burst that allocates GBs in ~1s and then
-- settles is invisible to both except as an after-the-fact number. This watches
-- the Lua heap on every 250ms fast tick and, the moment it jumps, arms the
-- profiler - so the record names the code that is allocating rather than the
-- code that happened to be running when the dust settled.
-- Arm the profiler on the RAMP (a modest jump), report only if the burst turns
-- out to be big. Arming at the reporting threshold is too late: a 400MB burst
-- inside one 250ms tick starts and finishes before the profiler sees a sample.
local PROF_ARM_MB = 100 -- one-tick growth that starts profiling
local SPIKE_MB = 250 -- total growth worth writing a record for
local SPIKE_SETTLED_MB = 50 -- growth below this ends the burst
local SPIKE_MIN_TICKS = 2 -- always sample at least this long once armed
local last_lua, spiking, spike_from, spike_peak, spike_ticks = 0, false, 0, 0, 0
local spike_since = 0

local function spike_watch()
  local lua = collectgarbage("count") / 1024
  local grew = lua - last_lua
  last_lua = lua
  if not spiking then
    if grew > PROF_ARM_MB then
      spiking, spike_from, spike_peak, spike_ticks = true, lua - grew, lua, 0
      -- the burst is already in the ring; look back over the tick it landed in
      spike_since = vim.uv.hrtime() - 400 * 1e6
    end
    return
  end
  spike_ticks = spike_ticks + 1
  if lua > spike_peak then
    spike_peak = lua
  end
  -- end the burst once it stops growing, or after 30s as a backstop
  if (grew < SPIKE_SETTLED_MB and spike_ticks >= SPIKE_MIN_TICKS) or spike_ticks > 120 then
    spiking = false
    local profile = prof_since(spike_since)
    if spike_peak - spike_from >= SPIKE_MB then
      write("SPIKE", "lua %.0f->%.0fMB (+%.0f) in %.1fs | rss=%.0fMB | %s",
        spike_from, spike_peak, spike_peak - spike_from, spike_ticks * 0.25,
        vim.uv.resident_set_memory() / 1048576, profile or "(no profile)")
    end
  end
end

local timer = assert(vim.uv.new_timer())
timer:start(250, 250, function()
  pcall(spike_watch)
  if queued_at then
    -- still starved: sample the true peak, and grab the interrupted stack once
    local l = collectgarbage("count") / 1024
    if l > peak_lua then
      peak_lua = l
    end
    local r = vim.uv.resident_set_memory() / 1048576
    if r > peak_rss then
      peak_rss = r
    end
    if not stack and (vim.uv.hrtime() - queued_at) / 1e6 > QUEUE_MS then
      local ok, tb = pcall(debug.traceback, "", 2)
      stack = (ok and tb or ""):gsub("%s+", " "):sub(1, 400)
    end
    return
  end
  queued_at = vim.uv.hrtime()
  peak_lua, peak_rss = collectgarbage("count") / 1024, vim.uv.resident_set_memory() / 1048576
  base_maj, base_cpu = proc_self_stat()
  base_psi = psi_full_us()
  local t0 = queued_at
  vim.schedule(function()
    local ms = (vim.uv.hrtime() - t0) / 1e6
    queued_at = nil
    local profile = prof_since(t0)
    -- A 185ms freeze on every focus change is invisible at QUEUE_MS=1000 but is
    -- exactly what "sluggish" feels like. Bucket the short ones and let MEM
    -- report the rate instead of writing a record per event.
    if ms >= 250 then
      local b = ms < 500 and 1 or (ms < 1000 and 2 or 3)
      stall_buckets[b] = stall_buckets[b] + 1
    end
    if ms > QUEUE_MS then
      local maj, cpu = proc_self_stat()
      local psi = psi_full_us()
      local top, total = {}, 0
      for k, e in pairs(wire) do
        top[#top + 1] = { k, e[1], e[2] }
        total = total + e[2]
      end
      table.sort(top, function(a, b)
        return a[3] > b[3]
      end)
      local parts = {}
      for i = 1, math.min(#top, 4) do
        parts[i] = ("%s n=%d %.0fMB"):format(top[i][1], top[i][2], top[i][3] / 1048576)
      end
      -- biggest is in KB on purpose: one 900MB response and a flood of 7KB
      -- ones produce the same wire total, and MB rounds the flood case to 0
      write("QUEUE", "%.0fms starved | cpu=%.0f%% sysmem=%.0f%% majflt=%d | wire=%.0fMB [%s] | biggest=%s %.0fKB | peak lua=%.0fMB rss=%.0fMB | %s",
        ms, ((cpu or 0) - (base_cpu or 0)) * 1000 / ms * 100,
        ((psi or 0) - (base_psi or 0)) / 1000 / ms * 100,
        (maj or 0) - (base_maj or 0),
        total / 1048576, table.concat(parts, ", "),
        worst and worst[1] or "-", (worst and worst[2] or 0) / 1024,
        peak_lua, peak_rss, profile or stack or "(no lua frame)")
    end
    wire, worst, stack = {}, nil, nil
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
