# Install all base packages

echo
cecho $BLUE "============================================"
cecho $BLUE "     Archy Linux Base Packages Installation"
cecho $BLUE "============================================"
echo

mapfile -t packages < <(grep -v '^#' "$ARCHY_INSTALL/archy-base.packages" | grep -v '^$')
sudo pacman -S --noconfirm --needed "${packages[@]}"
