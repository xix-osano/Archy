#!/bin/bash

# Ensure the script is NOT run as root
if [[ $EUID -eq 0 ]]; then
    echo -e "\e[31m[ACCESS DENIED]\e[0m This script must be run as a *regular user*, not the omnipotent root."
    echo "❌ Please rerun this script without sudo."
    exit 1
fi

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
