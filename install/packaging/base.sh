# Install all base packages
mapfile -t packages < <(grep -v '^#' "$ARCHY_INSTALL/archy-base.packages" | grep -v '^$')
sudo pacman -S --noconfirm --needed "${packages[@]}"
