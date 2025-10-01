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
source ~/.local/share/archy/install.sh
