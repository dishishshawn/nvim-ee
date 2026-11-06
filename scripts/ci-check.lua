-- Boots the config and checks that the firmware pieces are wired up.
-- Run after `nvim --headless "+Lazy! sync" +qa`:
--   nvim --headless -c "luafile scripts/ci-check.lua"
local fails = 0
local function check(cond, what)
  print((cond and "PASS " or "FAIL ") .. what)
  if not cond then
    fails = fails + 1
  end
end

pcall(function()
  require("persistence").stop() -- leave no session behind for the temp project
end)

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp .. "/build/Debug", "p")
vim.fn.writefile({ "int main(void) { return 0; }" }, tmp .. "/main.c")
vim.fn.writefile({ "x" }, tmp .. "/build/Debug/demo.elf")
vim.fn.writefile({ "source [find target/stm32g0x.cfg]" }, tmp .. "/openocd.cfg")
vim.cmd("cd " .. tmp)
vim.cmd("edit main.c")
vim.wait(1000)

check(vim.bo.filetype == "c", "C buffer opens")
vim.cmd("edit openocd.cfg")
check(vim.bo.filetype == "tcl", "openocd.cfg detected as tcl")
vim.cmd("edit main.c")

local ok_rv = pcall(vim.cmd, "Lazy load regview.nvim")
check(ok_rv and vim.fn.exists(":RegView") == 2 and vim.fn.exists(":OcdFlash") == 2, "regview commands registered")
local rv = require("regview")
check(rv.find_elf(tmp) == tmp .. "/build/Debug/demo.elf", "regview finds build/Debug ELF")

pcall(vim.cmd, "Lazy load nvim-dap")
local dap = require("dap")
check(dap.adapters.arm_gdb and dap.adapters.arm_gdb.command == "gdb-multiarch", "gdb-multiarch DAP adapter")
local first = (dap.configurations.c or {})[1]
check(first and first.type == "arm_gdb" and first.target == "localhost:3333", "OpenOCD attach is the first C config")

local servers = LazyVim.opts("nvim-lspconfig").servers or {}
local cmd = table.concat((servers.clangd or {}).cmd or {}, " ")
check(cmd:find("--query-driver=", 1, true) ~= nil, "clangd has --query-driver")

local cc = LazyVim.opts("claudecode.nvim")
check(cc.diff_opts and cc.diff_opts.layout == "unified", "Claude edits shown inline (unified diff)")
check((cc.terminal_cmd or ""):find("claude-review-hook.sh", 1, true), "Claude launched with the review hook")

-- uses claudecode.nvim internals, so this is the check that catches a plugin update breaking it
pcall(vim.cmd, "Lazy load claudecode.nvim")
local diff, win, path = require("claudecode.diff"), vim.api.nvim_get_current_win(), vim.api.nvim_buf_get_name(0)
local nwins, res = #vim.api.nvim_tabpage_list_wins(0), nil
diff._setup_blocking_diff({
  old_file_path = path,
  new_file_path = path,
  new_file_contents = "int main(void) { return 1; }\n",
  tab_name = "ci",
}, function(r)
  res = r
end)
local in_place = #vim.api.nvim_tabpage_list_wins(0) == nwins
check(
  in_place and vim.b[vim.api.nvim_win_get_buf(win)].claudecode_inline_diff,
  "Claude diff opens in the file's window"
)
vim.cmd("ClaudeCodeDiffAccept")
diff._cleanup_diff_state("ci", "closed")
local back = vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == path
check(res and res.content[1].text == "FILE_SAVED" and back, "file is back in its window after accepting")

local ok_rv_group, view_cmds = pcall(vim.api.nvim_get_autocmds, { group = "restore_view" })
check(ok_rv_group and #view_cmds >= 3, "session restore autocmds set up")

local has_key = {}
for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
  has_key[m.lhs] = true
end
for _, k in ipairs({ " ac", " aa", " ad", " ay", " an", " al", " mv", " mB", " dc" }) do
  check(has_key[k], "keymap <leader>" .. k:sub(2))
end

local msgs = vim.api.nvim_exec2("messages", { output = true }).output
local lua_err = msgs:find("stack traceback") or msgs:find("E5108") or msgs:find("Error detected while processing")
check(not lua_err, "no Lua errors at startup")
if lua_err then
  print(msgs)
end

print(fails == 0 and "ALL PASS" or ("FAILURES: " .. fails))
vim.cmd(fails == 0 and "qa!" or "cq!")
