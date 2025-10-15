#!/bin/bash
# Make Vimix theme survive encrypted /usr

set -euo pipefail

THEME_NAME="Vimix"
THEME_SRC="/usr/share/grub/themes/${THEME_NAME}"
THEME_DST="/boot/grub/themes/${THEME_NAME}"
GRUB_DEFAULT="/etc/default/grub"
HOOK_DIR="/etc/pacman.d/hooks"
HOOK_FILE="${HOOK_DIR}/grub-theme-vimix.hook"

# colours
GRN='\e[1;32m'; YLW='\e[1;33m'; RED='\e[1;31m'; RST='\e[0m'

msg() { printf "${GRN}[+]${RST} %s\n" "$*"; }
warn() { printf "${YLW}[!]${RST} %s\n" "$*"; }
die() { printf "${RED}[✗]${RST} %s\n" "$*" >&2; exit 1; }

# need root
[[ $EUID -eq 0 ]] || die "Run this script with sudo."

# 1. install theme if missing -------------------------------------------------
if [[ ! -d $THEME_SRC ]]; then
    msg "Theme not found – installing grub-theme-vimix"
    if command -v yay &>/dev/null; then
        yay -S --noconfirm grub-theme-vimix
    elif command -v paru &>/dev/null; then
        paru -S --noconfirm grub-theme-vimix
    else
        die "No AUR helper (yay/paru) found. Install grub-theme-vimix manually."
    fi
fi

# 2. copy theme into /boot ----------------------------------------------------
mkdir -p "$(dirname "$THEME_DST")"
cp -r "$THEME_SRC" "$THEME_DST"
msg "Theme copied → ${THEME_DST}"

# 3. patch /etc/default/grub --------------------------------------------------
if grep -q "^GRUB_THEME=" "$GRUB_DEFAULT"; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${THEME_DST}/theme.txt\"|" "$GRUB_DEFAULT"
else
    echo "GRUB_THEME=\"${THEME_DST}/theme.txt\"" >> "$GRUB_DEFAULT"
fi
msg "GRUB_THEME updated in ${GRUB_DEFAULT}"

# 4. ensure GRUB_GFXMODE is set (optional but nice) ---------------------------
if ! grep -q "^GRUB_GFXMODE=" "$GRUB_DEFAULT"; then
    echo 'GRUB_GFXMODE=1920x1080,auto' >> "$GRUB_DEFAULT"
    msg "Added GRUB_GFXMODE=1920x1080,auto"
fi

# 5. regenerate grub.cfg ------------------------------------------------------
if [[ -d /boot/grub ]]; then
    grub-mkconfig -o /boot/grub/grub.cfg
    msg "grub.cfg regenerated"
else
    warn "/boot/grub not found – skipped grub-mkconfig"
fi

# 6. pacman hook for automatic future copies ----------------------------------
mkdir -p "$HOOK_DIR"
cat > "$HOOK_FILE" <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = grub-theme-vimix

[Action]
Description = Copy Vimix theme to /boot/grub/themes
When = PostTransaction
Exec = /usr/bin/cp -r /usr/share/grub/themes/Vimix /boot/grub/themes/
EOF
msg "Pacman hook installed → ${HOOK_FILE}"

msg "Done. Reboot to see the new theme."