if [[ -n ${ARCHY_ONLINE_INSTALL:-} ]]; then
  # Install build tools
  sudo pacman -S --needed --noconfirm base-devel

  # Configure pacman
  sudo cat ~/.local/share/archy/default/pacman/pacman.conf | sudo tee -a /etc/pacman.conf
  sudo cat ~/.local/share/archy/default/pacman/mirrorlist | sudo tee -a /etc/pacman.d/mirrorlist

  # Refresh all repos
  sudo pacman -Syu --noconfirm
fi
