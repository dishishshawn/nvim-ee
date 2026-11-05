-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- Embedded file types Neovim doesn't detect on its own
vim.filetype.add({
  extension = {
    s = "asm",
    S = "asm",
    svd = "xml",
  },
  filename = {
    ["openocd.cfg"] = "tcl",
  },
  pattern = {
    [".*/openocd/.*%.cfg"] = "tcl",
  },
})
