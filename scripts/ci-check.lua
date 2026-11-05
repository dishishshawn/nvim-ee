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

local has_key = {}
for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
  has_key[m.lhs] = true
end
for _, k in ipairs({ " ac", " aa", " ad", " mv", " mB", " dc" }) do
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
