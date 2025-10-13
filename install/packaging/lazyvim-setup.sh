#!/bin/bash
set -e

# ---------- config ----------
NVIM_MIN="0.9.0"
LAZYVIM_REPO="https://github.com/LazyVim/starter"
# ----------------------------

command -v nvim >/dev/null || {
  echo "==> Installing neovim ..."
  sudo pacman -S --needed --noconfirm neovim
}

# version check (semver)
current=$(nvim --version | head -n1 | grep -oP '\d+\.\d+\.\d+')
if [[ "$(printf '%s\n' "$NVIM_MIN" "$current" | sort -V | head -n1)" != "$NVIM_MIN" ]]; then
  echo "ERROR: Neovim $current < required $NVIM_MIN"
  echo "       Upgrade first (yay -S neovim-nightly if needed)."
  exit 1
fi

conf_dir="$HOME/.config/nvim"
backup_dir="${conf_dir}.bak.$(date +%Y%m%d%H%M%S)"

if [[ -d "$conf_dir" ]]; then
  echo "==> Backing up existing config → $backup_dir"
  mv "$conf_dir" "$backup_dir"
fi

echo "==> Cloning LazyVim starter ..."
git clone --depth=1 "$LAZYVIM_REPO" "$conf_dir"

# remove the upstream .git so it becomes *your* dot-folder
rm -rf "$conf_dir/.git"

# --- Launch Neovim to trigger bootstrap ---
echo "==> Bootstrapping LazyVim plugins..."
nvim --headless "+Lazy! sync" +qa

# ---------- inject svim alias ----------
shells=()
[[ -f $HOME/.bashrc ]] && shells+=("$HOME/.bashrc")
[[ -f $HOME/.zshrc  ]] && shells+=("$HOME/.zshrc")
command -v fish >/dev/null && [[ -d $HOME/.config/fish ]] && shells+=("$HOME/.config/fish/config.fish")

for rc in "${shells[@]}"; do
  if [[ $rc == *"config.fish"* ]]; then        # fish syntax
    grep -qx 'alias svim "sudo -e"' "$rc" 2>/dev/null || echo 'alias svim "sudo -e"' >> "$rc"
    grep -qx 'set -x SUDO_EDITOR nvim' "$rc" 2>/dev/null || echo 'set -x SUDO_EDITOR nvim' >> "$rc"
  else                                         # bash/zsh
    grep -qx 'alias svim.*sudo -e' "$rc" 2>/dev/null || echo "alias svim='sudo -e'" >> "$rc"
    grep -qx 'export SUDO_EDITOR=nvim' "$rc" 2>/dev/null || echo 'export SUDO_EDITOR="nvim"' >> "$rc"
  fi
done
# -------------- Done -------------------------

echo
echo "✔ LazyVim installed."
echo "  Root-editing helper 'svim' alias added to your shell rc(s)."
echo "  Usage:  svim /etc/pacman.conf"
echo "Detected shell: $(basename "$SHELL")"
echo
echo "  Open nvim once to download plugins / LSP / treesitter:"
echo "     nvim"
echo "  Then read the docs inside:"
echo "     :help lazyvim-tutorials"