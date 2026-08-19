-- snacks.nvim's word-highlighter (snacks.words) fires textDocument/documentHighlight
-- on every CursorMoved (200ms debounced), and vim.lsp.buf.document_highlight()
-- never cancels a still-pending request before sending the next one. Against a
-- server that's slow to answer (e.g. jdtls stuck behind a reconcile), that lets
-- outstanding highlight requests pile up uncancelled.
--
-- Observed via perflog.lua on the dwmp project 2026-08-19: several concurrent
-- documentHighlight responses landing in the same second while jdtls was
-- clogged, correlating with nvim's own Lua heap transiently ballooning to
-- several GB (perf.log MEM lua=~8GB, back to double-digit MB once the pile
-- cleared) and the whole editor stalling under the resulting swap pressure.
-- Capping it at one in-flight highlight request per buffer - cancel the
-- previous one before sending the next - removes the pile-up regardless of
-- how slow or busy the server gets.
if vim.g.lsp_coalesce_highlight == false then
  return
end

local pending_cancel = {} --- @type table<integer, function>

vim.lsp.buf.document_highlight = function()
  local buf = vim.api.nvim_get_current_buf()

  local cancel = pending_cancel[buf]
  pending_cancel[buf] = nil
  if cancel then
    cancel()
  end

  local win = vim.api.nvim_get_current_win()
  local _, cancel_all = vim.lsp.buf_request(buf, "textDocument/documentHighlight", function(client)
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end)
  pending_cancel[buf] = cancel_all
end

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  callback = function(ev)
    pending_cancel[ev.buf] = nil
  end,
})
