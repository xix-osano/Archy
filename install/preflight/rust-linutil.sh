#!/usr/bin/env bash

echo
cecho $BLUE "============================================"
cecho $BLUE "     Archy Linux Rust & Linuti Tool Setup"
cecho $BLUE "============================================"
echo

set -euo pipefail

log() { echo -e "\e[34m==> $*\e[0m"; }
ok()  { echo -e "\e[32m✔ $*\e[0m"; }

log "Installing rustup (Rust toolchain)..."
if ! command -v rustup >/dev/null; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
else
  log "Rustup already installed. Updating..."
  rustup update
fi

log "Ensuring yay is available..."
if ! command -v yay >/dev/null; then
  tmp=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
  (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmp"
else
  log "yay already installed."
fi

log "Installing linutil from AUR..."
yay -S --needed --noconfirm linutil

ok "Setup complete!"
echo "🦀 Rust version: $(rustc --version)"
echo "⚙️  Linutil version: $(linutil --version 2>/dev/null || echo 'installed')"
echo
echo "Tip: run 'linutil' to start the toolbox."
