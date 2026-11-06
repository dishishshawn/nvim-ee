# nvim-ee

A [LazyVim](https://www.lazyvim.org) config for embedded and electrical engineering work.

- **Claude Code beside the editor, with Cursor-style review.** Claude edits files without stopping to ask, and you review afterwards: jump through its changes, then accept or reject each one, a selection of lines, or a whole file. Its changes are kept apart from your own uncommitted work, so you only review what Claude wrote. Outside git, Claude asks before each edit and shows it as a diff in the file's own window. It runs through the official Claude Code CLI, so a Claude Pro/Max subscription covers it.
- **Live MCU registers** with [regview.nvim](https://github.com/dishishshawn/regview.nvim): registers are polled through OpenOCD while the core runs, and bitfields are decoded from the chip's SVD file. Registers that change when read (`ADC.DR`, `USART.RDR`) are only read on demand.
- **Build, flash and debug from the editor.** Builds run in the background and errors land in the quickfix list. Flashing goes through the running OpenOCD, and GDB's built-in DAP server attaches to the same OpenOCD.
- **clangd for `arm-none-eabi`.** clangd is allowed to query the cross-compiler, so newlib and CMSIS headers resolve.
- **Picks up where you left off.** Opening `nvim` in a project restores its files, splits, file tree and Claude panel, each at the width you left it.
- **Extras:** a CMake language server, plus file-type detection for ARM assembly, SVD files and OpenOCD configs.

## Install

Ubuntu/Debian, x86_64 or arm64:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/dishishshawn/nvim-ee/main/install.sh)
```

The script:

- installs the toolchain from apt (`gcc-arm-none-eabi`, `gdb-multiarch`, `openocd`, `cmake`, `ninja-build`, `ripgrep`, `fd-find`, `jq`)
- installs Neovim and the tree-sitter CLI from their GitHub releases
- backs up any existing Neovim config, clones this repo to `~/.config/nvim`, and installs the plugins
- offers to install Claude Code

<details>
<summary>Manual install</summary>

```sh
sudo apt install git curl unzip jq build-essential ripgrep fd-find python3 python3-venv \
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

| File                    | Purpose                                                                                           |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| `openocd.cfg`           | Probe and target. The template targets a Nucleo-G031K8; change the `target/` line for other chips |
| `*.svd.json`            | Register map for regview. `regview.nvim/svd/` ships a pre-built STM32G031 file                    |
| `compile_commands.json` | Lets clangd see your build flags. Makefile projects: `bear -- make`                               |
| `.clangd`               | Strips GCC-only flags that clang rejects                                                          |

## Keymaps

`<leader>` is Space.

| Keys                                       | Action                                                                 |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| **Claude**                                 |                                                                        |
| `<leader>ac`                               | Toggle Claude Code panel                                               |
| `<leader>as`                               | Send selection (visual)                                                |
| `<leader>ab`                               | Add current buffer to context                                          |
| `<leader>al`                               | List Claude's changes to review (quickfix; `]q` / `[q` to walk them)   |
| `]h` / `[h`                                | Next / previous change in the file                                     |
| `<leader>ay` / `<leader>an`                | Accept / reject the change under the cursor (visual: just those lines) |
| `<leader>aY` / `<leader>aN`                | Accept / reject every change in the file                               |
| `<leader>ai`                               | Toggle inline diff: removed lines in red, added in green               |
| `<leader>aa` / `<leader>ad`                | Accept / reject a diff Claude is waiting on (`:w` also accepts)        |
| **MCU**                                    |                                                                        |
| `<leader>mv`                               | Register panel (starts OpenOCD if needed)                              |
| `<leader>mw`                               | Watch a register (fuzzy picker)                                        |
| `<leader>mr`                               | Read on-demand registers                                               |
| `<leader>mp`                               | Pause polling                                                          |
| `<leader>mb` / `<leader>mB`                | Build / build and flash                                                |
| `<leader>mf`                               | Flash newest ELF                                                       |
| `<leader>mR`                               | Reset target                                                           |
| `<leader>mo` / `<leader>mO` / `<leader>ml` | Start / stop / log OpenOCD                                             |
| **Debug**                                  |                                                                        |
| `<leader>dc`                               | Continue, or pick "STM32: attach (OpenOCD :3333)"                      |
| `<leader>db`                               | Toggle breakpoint                                                      |
| `<leader>dO` / `<leader>di` / `<leader>do` | Step over / into / out                                                 |
| `<leader>du`                               | Debug UI                                                               |
| `<leader>dr`                               | REPL (`monitor reset halt`, `load`)                                    |
| **Files**                                  |                                                                        |
| `<leader>e`                                | File explorer                                                          |

Register panel keys: `a` add · `dd` remove · `r` read · `w` write · `<CR>` bitfields · `K` describe · `p` pause · `q` close

## Workflow

1. `<leader>mB` builds and flashes. Build errors open the quickfix list.
2. `<leader>mv` opens the register panel; press `a` and add `ADC.ISR`, `GPIOA.ODR`, …
3. `<leader>dc` attaches the debugger. The register panel keeps updating at breakpoints.
4. `<leader>ac` opens Claude: describe the change and let it work. Then `<leader>al` lists what it changed; go through it with `]q`, `<leader>ai` to see each change inline, and `<leader>ay` / `<leader>an` to keep or drop it.

### How Claude review works

Inside a git repo, a [hook](scripts/claude-review-hook.sh) stages a file just before Claude's first edit to it. The git index then holds the "before" version, so Claude's changes are exactly the file's unstaged hunks: accepting a change stages it and rejecting one restores the staged text and saves the file. Accepted work is staged and ready to commit.

- The hook stages your own uncommitted work in the files Claude edits, which merges any partial staging you had in them.
- Claude starts in accept-edits mode. Press Shift+Tab in the Claude panel to go back to approving each edit as it comes (`<leader>aa` / `<leader>ad`).
- Outside a git repo there is nothing to review against, so Claude asks before every edit instead. The edit opens as a diff in the window that already shows the file (or in a split if the file is not open), and the file comes back when you accept or reject. Reject with `<leader>ad`: `:q` closes that window.
- Edits land on disk before you review them, so a build or flash runs Claude's unreviewed code.
- Changes Claude makes through shell commands (`sed`, code generators) are not tracked.
- A rejected new file is left empty on disk; delete it yourself.

## Customizing

| What                                               | Where                                                                                                                  |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Build command                                      | `:let g:fw_build_cmd = "make -j"`. Default: `cmake --build --preset Debug`, then `cmake --build build`, then `make -j` |
| Poll rate, SVD/ELF paths, read-sensitive registers | `opts` of `regview.nvim` in `lua/plugins/firmware.lua`                                                                 |
| Toolchain outside `/usr/bin`, `/opt` or `~`        | `--query-driver` in `lua/plugins/firmware.lua`                                                                         |
| Claude panel side/width, diff style                | `lua/plugins/claude.lua` (`layout = "vertical"` gives side-by-side diffs)                                              |
| More languages                                     | `:LazyExtras`                                                                                                          |

For regview.nvim development, check it out to `~/dev/regview.nvim`; lazy.nvim loads that copy instead of the GitHub one.

## Layout

```
init.lua
lazyvim.json              enabled LazyVim extras (claudecode, dap.core, clangd, cmake)
lua/config/lazy.lua       lazy.nvim bootstrap, ~/dev override for local plugin checkouts
lua/config/options.lua    ARM asm / SVD / OpenOCD file types
lua/plugins/claude.lua    Claude Code panel, review keymaps, hook wiring
lua/plugins/firmware.lua  regview, build/flash keys, GDB DAP, clangd flags
lua/plugins/session.lua   restore the last session, panels and widths included
scripts/                  Claude review hook and its test, CI boot check
project-template/         openocd.cfg, .clangd
install.sh                Ubuntu/Debian bootstrap
```

## Credits

Built on [LazyVim](https://github.com/LazyVim/LazyVim), [claudecode.nvim](https://github.com/coder/claudecode.nvim), [nvim-dap](https://github.com/mfussenegger/nvim-dap) and [OpenOCD](https://openocd.org).

## License

Apache-2.0, following the LazyVim starter this config is based on.
