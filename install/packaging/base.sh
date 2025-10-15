# Install all base packages

echo "============================================"
echo "     Archy Linux Base Packages Installation"
echo "============================================"
echo

mapfile -t packages < <(grep -v '^#' "$ARCHY_INSTALL/archy-base.packages" | grep -v '^$')
sudo pacman -S --noconfirm --needed "${packages[@]}"
