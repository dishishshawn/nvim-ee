# nvim-ee

A [LazyVim](https://www.lazyvim.org) config for embedded and electrical engineering work.

- **Claude Code beside the editor.** Its edits appear inline in the file, red for removed lines and green for added. `:w` accepts an edit and `:q` rejects it. It runs through the official Claude Code CLI, so a Claude Pro/Max subscription covers it.
- **Live MCU registers** with [regview.nvim](https://github.com/dishishshawn/regview.nvim): registers are polled through OpenOCD while the core runs, and bitfields are decoded from the chip's SVD file. Registers that change when read (`ADC.DR`, `USART.RDR`) are only read on demand.
- **Build, flash and debug from the editor.** Builds run in the background and errors land in the quickfix list. Flashing goes through the running OpenOCD, and GDB's built-in DAP server attaches to the same OpenOCD.
- **clangd for `arm-none-eabi`.** clangd is allowed to query the cross-compiler, so newlib and CMSIS headers resolve.
- **Extras:** a CMake language server, plus file-type detection for ARM assembly, SVD files and OpenOCD configs.

## Install

Ubuntu/Debian, x86_64 or arm64:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/dishishshawn/nvim-ee/main/install.sh)
```

The script:
- installs the toolchain from apt (`gcc-arm-none-eabi`, `gdb-multiarch`, `openocd`, `cmake`, `ninja-build`, `ripgrep`, `fd-find`)
- installs Neovim and the tree-sitter CLI from their GitHub releases
- backs up any existing Neovim config, clones this repo to `~/.config/nvim`, and installs the plugins
- offers to install Claude Code

<details>
<summary>Manual install</summary>

```sh
sudo apt install git curl unzip build-essential ripgrep fd-find python3 python3-venv \
  gcc-arm-none-eabi gdb-multiarch openocd cmake ninja-build
# Neovim >= 0.11.2 and tree-sitter CLI >= 0.26.1 (Ubuntu's apt versions are older)
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz && sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
curl -L https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-x64.gz \
  | gunzip > ~/.local/bin/tree-sitter && chmod +x ~/.local/bin/tree-sitter

mv ~/.config/nvim ~/.config/nvim.bak
git clone https://github.com/dishishshawn/nvim-ee ~/.config/nvim
nvim

curl -fsSL https://claude.ai/install.sh | bash   # Claude Code, then `claude` → /login
```
</details>

Use a [Nerd Font](https://www.nerdfonts.com) in your terminal.

## Project setup

From your firmware repo's root:

```sh
cp ~/.config/nvim/project-template/{openocd.cfg,.clangd} .
python3 ~/.local/share/nvim/lazy/regview.nvim/scripts/svd2json.py STM32G031.svd -o stm32g031.svd.json
ln -sf build/Debug/compile_commands.json .    # CubeMX CMake preset; plain CMake: build/compile_commands.json
```

| File | Purpose |
|---|---|
| `openocd.cfg` | Probe and target. The template targets a Nucleo-G031K8; change the `target/` line for other chips |
| `*.svd.json` | Register map for regview. `regview.nvim/svd/` ships a pre-built STM32G031 file |
| `compile_commands.json` | Lets clangd see your build flags. Makefile projects: `bear -- make` |
| `.clangd` | Strips GCC-only flags that clang rejects |

## Keymaps

`<leader>` is Space.

| Keys | Action |
|---|---|
| **Claude** | |
| `<leader>ac` | Toggle Claude Code panel |
| `<leader>as` | Send selection (visual) |
| `<leader>ab` | Add current buffer to context |
| `<leader>aa` / `:w` | Accept the edit shown inline |
| `<leader>ad` / `:q` | Reject it |
| **MCU** | |
| `<leader>mv` | Register panel (starts OpenOCD if needed) |
| `<leader>mw` | Watch a register (fuzzy picker) |
| `<leader>mr` | Read on-demand registers |
| `<leader>mp` | Pause polling |
| `<leader>mb` / `<leader>mB` | Build / build and flash |
| `<leader>mf` | Flash newest ELF |
| `<leader>mR` | Reset target |
| `<leader>mo` / `<leader>mO` / `<leader>ml` | Start / stop / log OpenOCD |
| **Debug** | |
| `<leader>dc` | Continue, or pick "STM32: attach (OpenOCD :3333)" |
| `<leader>db` | Toggle breakpoint |
| `<leader>dO` / `<leader>di` / `<leader>do` | Step over / into / out |
| `<leader>du` | Debug UI |
| `<leader>dr` | REPL (`monitor reset halt`, `load`) |
| **Files** | |
| `<leader>e` | File explorer |

Register panel keys: `a` add · `dd` remove · `r` read · `w` write · `<CR>` bitfields · `K` describe · `p` pause · `q` close

## Workflow

1. `<leader>mB` builds and flashes. Build errors open the quickfix list.
2. `<leader>mv` opens the register panel; press `a` and add `ADC.ISR`, `GPIOA.ODR`, …
3. `<leader>dc` attaches the debugger. The register panel keeps updating at breakpoints.
4. `<leader>ac` opens Claude: describe the change, review the inline diff, and `:w` to keep it.

## Customizing

| What | Where |
|---|---|
| Build command | `:let g:fw_build_cmd = "make -j"`. Default: `cmake --build --preset Debug`, then `cmake --build build`, then `make -j` |
| Poll rate, SVD/ELF paths, read-sensitive registers | `opts` of `regview.nvim` in `lua/plugins/firmware.lua` |
| Toolchain outside `/usr/bin`, `/opt` or `~` | `--query-driver` in `lua/plugins/firmware.lua` |
| Claude panel side/width, diff style | `lua/plugins/claude.lua` (`layout = "vertical"` gives side-by-side diffs) |
| More languages | `:LazyExtras` |

For regview.nvim development, check it out to `~/dev/regview.nvim`; lazy.nvim loads that copy instead of the GitHub one.

## Layout

```
init.lua
lazyvim.json              enabled LazyVim extras (claudecode, dap.core, clangd, cmake)
lua/config/lazy.lua       lazy.nvim bootstrap, ~/dev override for local plugin checkouts
lua/config/options.lua    ARM asm / SVD / OpenOCD file types
lua/plugins/claude.lua    Claude Code panel + inline diff
lua/plugins/firmware.lua  regview, build/flash keys, GDB DAP, clangd flags
project-template/         openocd.cfg, .clangd
install.sh                Ubuntu/Debian bootstrap
```

## Credits

Built on [LazyVim](https://github.com/LazyVim/LazyVim), [claudecode.nvim](https://github.com/coder/claudecode.nvim), [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [OpenOCD](https://openocd.org).

## License

Apache-2.0, following the LazyVim starter this config is based on.
