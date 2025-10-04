#!/bin/bash

# Set install mode to online since boot.sh is used for curl installations
export ARCHY_ONLINE_INSTALL=true

ansi_art='                 ▄▄▄                                                   
   ▄███████   ▄███████   ▄███████   ▄█   █▄    ▄█   █▄ 
  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
  ███   ███  ███   ███  ███   █▀   ███   ███  ███   ███
 ▄███▄▄▄███ ▄███▄▄▄██▀  ███       ▄███▄▄▄███▄ ███▄▄▄███
 ▀███▀▀▀███ ▀███▀▀▀▀    ███      ▀▀███▀▀▀███  ▀▀▀▀▀▀███
  ███   ███ ██████████  ███   █▄   ███   ███  ▄██   ███
  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
  ███   █▀   ███   ███  ███████▀   ███   █▀    ▀█████▀ 
             ███   █▀                                  '

clear
echo -e "\n$ansi_art\n"

sudo pacman -Syu --noconfirm --needed git

echo -e "\nCloning Archy from: https://github.com/xix-osano/Archy.git"
rm -rf ~/.local/share/archy/
git clone "https://github.com/xix-osano/Archy.git" ~/.local/share/archy >/dev/null

echo -e "\nInstallation starting..."

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Archy locations
export ARCHY_PATH="$HOME/.local/share/archy"
export ARCHY_INSTALL="$ARCHY_PATH/install"
export PATH="$ARCHY_PATH/bin:$PATH"

# Install
source "$ARCHY_INSTALL/preflight/all.sh"
source "$ARCHY_INSTALL/packaging/all.sh"
source "$ARCHY_INSTALL/login/all.sh"
