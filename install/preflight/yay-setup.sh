#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -euo pipefail

# ----------------------------------------------------------
#  yay installer – run as NORMAL user (will ask for sudo)
# ----------------------------------------------------------

PKGS=(base-devel git)

echo "==> Installing build essentials..."
sudo pacman -S --needed --noconfirm "${PKGS[@]}"

echo "==> Cloning yay stable..."
tmpdir=$(mktemp -d)
git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
cd "$tmpdir/yay-bin"

echo "==> Building yay..."
makepkg -si --noconfirm

echo "==> Cleaning up..."
cd
rm -rf "$tmpdir"

echo "==> Yay installed. Version:"
yay --version