#!/bin/bash

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
git clone "https://github.com/xix-osano/Archy.git" ~/.local/share/archy

echo -e "\nInstallation starting..."
source ~/.local/share/archy/all.sh
