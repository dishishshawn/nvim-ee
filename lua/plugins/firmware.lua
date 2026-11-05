-- Firmware workflow for STM32 (or anything OpenOCD + GDB can talk to):
--   regview.nvim  live registers, flashing, OpenOCD process   (<leader>m…)
--   nvim-dap      GDB (gdb-multiarch, native DAP) attached to OpenOCD :3333
--   clangd        allowed to query arm-none-eabi-gcc for its system headers

-- Build in the background and load errors into the quickfix list.
-- Override the command per project with  :let g:fw_build_cmd = "make -j"
local function fw_build(then_flash)
  local root = vim.fs.root(0, { "openocd.cfg", "CMakePresets.json", "CMakeLists.txt", "Makefile", ".git" })
    or vim.fn.getcwd()
  local cmd = vim.g.fw_build_cmd
  if not cmd then
    if vim.uv.fs_stat(root .. "/CMakePresets.json") then
      cmd = "cmake --build --preset Debug"
    elseif vim.uv.fs_stat(root .. "/CMakeLists.txt") then
      cmd = "cmake --build build"
    else
      cmd = "make -j"
    end
  end
  vim.notify("build: " .. cmd)
  vim.system({ "sh", "-c", cmd .. " 2>&1" }, { cwd = root, text = true }, function(res)
    vim.schedule(function()
      local out = vim.split(res.stdout or "", "\n", { trimempty = true })
      vim.fn.setqflist({}, " ", { title = cmd, lines = out, efm = vim.o.errorformat })
      if res.code ~= 0 then
        vim.notify("build failed", vim.log.levels.ERROR)
        vim.cmd("copen")
      else
        vim.notify("build ok")
        if then_flash then
          require("regview").flash()
        end
      end
    end)
  end)
end

return {
  -- live register viewer + OpenOCD control
  {
    "dishishshawn/regview.nvim",
    dev = true, -- uses ~/dev/regview.nvim if present (see lua/config/lazy.lua)
    cmd = {
      "RegView",
      "RegWatch",
      "RegUnwatch",
      "RegRead",
      "RegWrite",
      "RegPause",
      "RegClear",
      "OcdStart",
      "OcdStop",
      "OcdLog",
      "OcdFlash",
      "Ocd",
    },
    keys = {
      { "<leader>m", "", desc = "+mcu" },
      { "<leader>mv", "<cmd>RegView<cr>", desc = "Register view" },
      { "<leader>mw", "<cmd>RegWatch<cr>", desc = "Watch register" },
      { "<leader>mr", "<cmd>RegRead<cr>", desc = "Read on-demand registers" },
      { "<leader>mp", "<cmd>RegPause<cr>", desc = "Pause polling" },
      {
        "<leader>mb",
        function()
          fw_build(false)
        end,
        desc = "Build",
      },
      {
        "<leader>mB",
        function()
          fw_build(true)
        end,
        desc = "Build + flash",
      },
      { "<leader>mf", "<cmd>OcdFlash<cr>", desc = "Flash ELF" },
      { "<leader>mR", "<cmd>Ocd reset run<cr>", desc = "Reset target" },
      { "<leader>mo", "<cmd>OcdStart<cr>", desc = "Start OpenOCD" },
      { "<leader>mO", "<cmd>OcdStop<cr>", desc = "Stop OpenOCD" },
      { "<leader>ml", "<cmd>OcdLog<cr>", desc = "OpenOCD log" },
    },
    opts = {
      interval = 100,
      -- svd = "~/dev/svd/stm32g031.svd.json", -- default: any *.svd.json in the project root
      -- elf = "build/Debug/myproj.elf",       -- default: newest build/**/*.elf
    },
  },

  -- GDB's built-in DAP server, attached to the OpenOCD that regview manages
  {
    "mfussenegger/nvim-dap",
    optional = true,
    opts = function()
      local dap = require("dap")
      dap.adapters.arm_gdb = {
        type = "executable",
        command = "gdb-multiarch",
        args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
      }
      local attach = {
        name = "STM32: attach (OpenOCD :3333)",
        type = "arm_gdb",
        request = "attach",
        target = "localhost:3333",
        program = function()
          local rv = require("regview")
          rv.ensure_openocd()
          return rv.find_elf()
        end,
        cwd = "${workspaceFolder}",
      }
      for _, ft in ipairs({ "c", "cpp", "asm" }) do
        dap.configurations[ft] = dap.configurations[ft] or {}
        table.insert(dap.configurations[ft], 1, attach)
      end
    end,
  },

  -- clangd: let it ask arm-none-eabi-gcc where newlib/CMSIS headers live
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.clangd = opts.servers.clangd or {}
      opts.servers.clangd.cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=never",
        "--completion-style=detailed",
        "--function-arg-placeholders",
        "--fallback-style=llvm",
        "--query-driver=/usr/bin/arm-none-eabi-*,/opt/**/arm-none-eabi-*,"
          .. vim.fn.expand("~")
          .. "/**/arm-none-eabi-*",
      }
    end,
  },
}
