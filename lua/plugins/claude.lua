-- Claude Code in a right-hand panel. Claude edits files straight away (accept-edits mode) and you
-- review afterwards, Cursor style: a hook stages each file before Claude's first edit to it, so
-- Claude's changes are exactly the file's unstaged git hunks (scripts/claude-review-hook.sh).
--   ]h / [h next/prev change    <leader>ay / <leader>an accept / reject change (or visual lines)
--   <leader>al list all changes  <leader>aY / <leader>aN accept / reject whole file
--   <leader>ai inline red/green  Shift+Tab in Claude: back to approving each edit in a diff
-- Outside git, Claude asks before each edit instead, showing it as a diff (in the file's own
-- window when it is open): <leader>aa or :w accepts, <leader>ad rejects.
-- Panel keymaps come from the LazyVim "ai.claudecode" extra:
--   <leader>ac toggle panel      <leader>as send selection   <leader>ab add buffer
local hook = '"' .. vim.fn.stdpath("config") .. '/scripts/claude-review-hook.sh"'
local on_edit = { { matcher = "Edit|Write|MultiEdit", hooks = { { type = "command", command = hook } } } }
local settings = vim.json.encode({
  hooks = {
    UserPromptSubmit = { { hooks = { { type = "command", command = hook } } } },
    PreToolUse = on_edit,
    PostToolUse = on_edit,
  },
})

-- Rejecting writes the file at once, so Claude and the build see the same text as the buffer.
local function reject(range)
  require("gitsigns").reset_hunk(
    range,
    nil,
    vim.schedule_wrap(function()
      vim.cmd("silent update")
    end)
  )
end

-- Every unstaged hunk into the quickfix list, new files included (Gitsigns setqflist skips those).
local function list_changes()
  local top = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
  local items, file = {}, nil
  for _, l in
    ipairs(vim.fn.systemlist({ "git", "diff", "-U0", "--no-color", "--no-ext-diff", "--dst-prefix=" .. top .. "/" }))
  do
    file = l:match("^%+%+%+ (.+)") or file
    local lnum = l:match("^@@ %-[%d,]+ %+(%d+)")
    if lnum then
      items[#items + 1] = { filename = file, lnum = math.max(tonumber(lnum), 1) }
    elseif items[#items] and not items[#items].text and l:match("^[+-]") then
      items[#items].text = l -- the hunk's first changed line
    end
  end
  vim.fn.setqflist({}, " ", { title = "Changes to review", items = items })
  if #items > 0 then
    vim.cmd("copen")
  else
    vim.notify("Nothing to review")
  end
end

-- When the file Claude wants to edit is already open, show the proposed edit in that window instead
-- of a split beside it, and put the file back there once you accept or reject.
-- shortcut: wraps claudecode.nvim internals (diff_inline setup/cleanup); recheck after plugin updates.
local function diff_in_place()
  local diff, inline = require("claudecode.diff"), require("claudecode.diff_inline")
  local setup, cleanup = inline.setup_inline_diff, inline.cleanup_inline_diff
  local borrowed = {} -- diff name -> the file window it took over: { win, buf, view }

  inline.setup_inline_diff = function(params, ...)
    setup(params, ...)
    local d = diff._get_active_diffs()[params.tab_name]
    if not (d and d.new_window and vim.api.nvim_win_is_valid(d.new_window)) then
      return
    end
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(d.new_window))) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_get_name(buf) == params.old_file_path then
        borrowed[params.tab_name] = { win = win, buf = buf, view = vim.api.nvim_win_call(win, vim.fn.winsaveview) }
        local cursor = vim.api.nvim_win_get_cursor(d.new_window) -- on the first change
        vim.api.nvim_win_set_buf(win, d.new_buffer)
        vim.api.nvim_win_set_cursor(win, cursor)
        vim.api.nvim_win_close(d.new_window, true)
        diff._restore_window_sizes(d.window_sizes) -- undo the split's resizing, Claude panel included
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end

  inline.cleanup_inline_diff = function(tab_name, d)
    local b = borrowed[tab_name]
    borrowed[tab_name] = nil
    -- only if the window still shows the diff (you may have closed it or switched away)
    if b and vim.api.nvim_win_is_valid(b.win) and vim.api.nvim_win_get_buf(b.win) == d.new_buffer then
      vim.bo[d.new_buffer].bufhidden = "hide" -- else hiding it wipes it now; cleanup deletes it next
      vim.api.nvim_win_set_buf(b.win, b.buf)
      vim.api.nvim_win_call(b.win, function()
        vim.fn.winrestview(b.view)
      end)
      vim.cmd.checktime(b.buf) -- pick up the edit if Claude has written it already
    end
    return cleanup(tab_name, d)
  end
end

return {
  {
    "coder/claudecode.nvim",
    config = function(_, opts)
      require("claudecode").setup(opts)
      diff_in_place()
    end,
    opts = {
      terminal_cmd = "claude --permission-mode acceptEdits --settings " .. vim.fn.shellescape(settings),
      terminal = {
        split_side = "right",
        split_width_percentage = 0.35,
      },
      diff_opts = {
        layout = "unified",
        open_in_new_tab = false,
        keep_terminal_focus = false, -- jump into the diff so you can review it
      },
    },
    keys = {
      { "<leader>ay", ":Gitsigns stage_hunk<cr>", mode = { "n", "x" }, desc = "Accept change" },
      { "<leader>an", reject, desc = "Reject change" },
      {
        "<leader>an",
        function()
          reject({ vim.fn.line("."), vim.fn.line("v") })
        end,
        mode = "x",
        desc = "Reject lines",
      },
      { "<leader>aY", "<cmd>Gitsigns stage_buffer<cr>", desc = "Accept file" },
      { "<leader>aN", "<cmd>Gitsigns reset_buffer<cr><cmd>silent update<cr>", desc = "Reject file" },
      { "<leader>al", list_changes, desc = "List changes to review" },
      {
        "<leader>ai",
        function()
          local gs = require("gitsigns")
          local on = gs.toggle_linehl()
          gs.toggle_word_diff(on)
          gs.toggle_deleted(on) -- removed lines inline, in red
        end,
        desc = "Toggle inline diff",
      },
    },
  },
}
