-- Reopen each project the way you left it. `nvim` with no file arguments loads the directory's last
-- session (files, splits, cursor, folds), reopens the file tree and the Claude panel, and gives every
-- window its old width. persistence.nvim (LazyVim) saves the session on exit; <leader>qd skips that.

-- Each non-floating window of the tab, left to right, with what it shows.
local function windows()
  local list = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      local buf, term = vim.api.nvim_win_get_buf(w), package.loaded["claudecode.terminal"]
      local kind = vim.bo[buf].filetype == "neo-tree" and "tree"
        or term and buf == term.get_active_terminal_bufnr() and "claude"
        or "file"
      list[#list + 1] = { win = w, kind = kind }
    end
  end
  return list
end

return {
  "folke/persistence.nvim",
  init = function()
    local group = vim.api.nvim_create_augroup("restore_view", { clear = true })
    vim.api.nvim_create_autocmd("StdinReadPre", {
      group = group,
      callback = function()
        vim.g.started_with_stdin = true
      end,
    })
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      nested = true, -- so the restored buffers get their filetype, LSP and so on
      callback = function()
        -- no UI: a headless run (scripts/ci-check.lua) must not pick up your session
        if vim.fn.argc(-1) == 0 and not vim.g.started_with_stdin and #vim.api.nvim_list_uis() > 0 then
          require("persistence").load()
        end
      end,
    })

    -- The session file leaves out the tree and the Claude panel, and sizes the rest without them, so
    -- the layout goes in a global, which the session does save ("tree=30 file=80 claude=70").
    -- ExitPre, not PersistenceSavePre: the Claude terminal closes itself on ExitPre, before the save.
    vim.api.nvim_create_autocmd("ExitPre", {
      group = group,
      callback = function()
        local parts = {}
        for _, w in ipairs(windows()) do
          parts[#parts + 1] = w.kind .. "=" .. vim.api.nvim_win_get_width(w.win)
        end
        vim.g.ViewLayout = table.concat(parts, " ")
      end,
    })
    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "PersistenceLoadPost",
      callback = function()
        local saved, file_win = vim.g.ViewLayout or "", vim.api.nvim_get_current_win()
        if saved:find("tree=") then
          vim.cmd("Neotree show")
        end
        if saved:find("claude=") then
          require("claudecode.terminal").ensure_visible() -- a new Claude; /resume in it brings back the old chat
        end
        local want = vim.split(saved, " ", { trimempty = true })
        local wins = windows()
        for _ = 1, 2 do -- twice, as winrestcmd() does: one resize can shift a window set before it
          for i, w in ipairs(wins) do
            -- by position while the windows line up; else (a quickfix list is not restored) panels only
            local width = #wins == #want and (want[i] or ""):match("^" .. w.kind .. "=(%d+)")
              or w.kind ~= "file" and saved:match(w.kind .. "=(%d+)")
            if width then
              vim.api.nvim_win_set_width(w.win, tonumber(width))
            end
          end
        end
        vim.api.nvim_set_current_win(file_win)
      end,
    })
  end,
}
