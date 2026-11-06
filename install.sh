#!/usr/bin/env bash
# nvim-ee bootstrap for Ubuntu / Debian (x86_64 or arm64).
#   bash <(curl -fsSL https://raw.githubusercontent.com/dishishshawn/nvim-ee/main/install.sh)
#
# Installs the embedded toolchain from apt, Neovim and the tree-sitter CLI from
# their GitHub releases, backs up any existing Neovim config, clones this repo
# to ~/.config/nvim, and installs plugins. Re-running is safe.
set -euo pipefail

REPO="${NVIM_EE_REPO:-https://github.com/dishishshawn/nvim-ee.git}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
BIN="$HOME/.local/bin"
NVIM_MIN="0.11.2"
TS_MIN="0.26.1"

step() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
# version_ge A B  -> true if A >= B
version_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

case "$(uname -m)" in
  x86_64 | amd64) NVIM_ARCH="x86_64"; TS_ARCH="x64" ;;
  aarch64 | arm64) NVIM_ARCH="arm64"; TS_ARCH="arm64" ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

step "apt packages"
sudo apt-get update
sudo apt-get install -y \
  git curl unzip jq build-essential ripgrep fd-find python3 python3-venv \
  gcc-arm-none-eabi gdb-multiarch openocd cmake ninja-build

step "Neovim >= $NVIM_MIN"
current=""
if have nvim; then
  current="$(nvim --version | head -n1 | sed -E 's/^NVIM v([0-9.]+).*/\1/')"
fi
if [ -n "$current" ] && version_ge "$current" "$NVIM_MIN"; then
  echo "found Neovim $current"
else
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/nvim.tar.gz" \
    "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz"
  sudo tar -C /opt -xzf "$tmp/nvim.tar.gz"
  sudo ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim
  rm -r "$tmp"
  echo "installed $(nvim --version | head -n1)"
fi

step "tree-sitter CLI >= $TS_MIN"
mkdir -p "$BIN"
ts_current=""
if have tree-sitter; then
  ts_current="$(tree-sitter --version | awk '{print $2}')"
fi
if [ -n "$ts_current" ] && version_ge "$ts_current" "$TS_MIN"; then
  echo "found tree-sitter $ts_current"
else
  curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-${TS_ARCH}.gz" \
    | gunzip >"$BIN/tree-sitter"
  chmod +x "$BIN/tree-sitter"
  echo "installed $("$BIN/tree-sitter" --version)"
fi
case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "note: add $BIN to your PATH (open a new login shell, or add it in ~/.profile)" ;;
esac

step "config -> $CONFIG"
if [ -d "$CONFIG/.git" ] && git -C "$CONFIG" remote get-url origin 2>/dev/null | grep -q "nvim-ee"; then
  git -C "$CONFIG" pull --ff-only
else
  stamp="$(date +%Y%m%d-%H%M%S)"
  for d in "$CONFIG" "$HOME/.local/share/nvim" "$HOME/.local/state/nvim" "$HOME/.cache/nvim"; do
    if [ -e "$d" ]; then
      mv "$d" "$d.bak-$stamp"
      echo "backed up $d -> $d.bak-$stamp"
    fi
  done
  git clone "$REPO" "$CONFIG"
fi

step "Claude Code CLI"
if have claude || [ -x "$BIN/claude" ]; then
  echo "found claude"
else
  read -r -p "Install Claude Code CLI (native installer)? [y/N] " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    curl -fsSL https://claude.ai/install.sh | bash
    echo "run 'claude' once and /login before using <space>ac"
  fi
fi

step "plugins (this takes a minute)"
nvim --headless "+Lazy! sync" +qa

cat <<'EOF'

Done. Next:
  1. Unplug and replug your ST-LINK (OpenOCD's udev rules grant access).
  2. In a firmware project:
       cp ~/.config/nvim/project-template/{openocd.cfg,.clangd} .
       python3 ~/.local/share/nvim/lazy/regview.nvim/scripts/svd2json.py <Chip>.svd -o <chip>.svd.json
       ln -sf build/Debug/compile_commands.json .
  3. nvim, then <space>mv for registers, <space>ac for Claude.
EOF
