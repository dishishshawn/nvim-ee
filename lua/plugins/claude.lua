-- Claude Code in a right-hand panel, with its edits shown inline in the file
-- (red = removed, green = added), Cursor / VS Code style.
-- Keymaps come from the LazyVim "ai.claudecode" extra:
--   <leader>ac toggle panel      <leader>as send selection   <leader>ab add buffer
--   <leader>aa accept edit (:w)  <leader>ad reject edit (:q)
return {
  {
    "coder/claudecode.nvim",
    opts = {
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
  },
}
