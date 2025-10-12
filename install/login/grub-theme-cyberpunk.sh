#!/bin/bash
# grub-theme-cyberpunk.sh  –  make Cyberpunk theme survive encrypted /usr
# usage:  sudo ./cyberpunk-grub-auto.sh  [aur|git]   (default: aur)

set -euo pipefail

THEME_CHOICE=${1:-aur}          # aur  ||  git
THEME_NAME="Cyberpunk"
THEME_DIR="/boot/grub/themes/${THEME_NAME}"
GRUB_DEFAULT="/etc/default/grub"
HOOK_DIR="/etc/pacman.d/hooks"
HOOK_FILE="${HOOK_DIR}/cyberpunk-grub-theme.hook"

GRN='\e[1;32m'; YLW='\e[1;33m'; RED='\e[1;31m'; RST='\e[0m'
msg()  { printf "${GRN}[+]${RST} %s\n" "$*"; }
warn() { printf "${YLW}[!]${RST} %s\n" "$*"; }
die()  { printf "${RED}[✗]${RST} %s\n" "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run with sudo."

# 1. obtain theme -------------------------------------------------------------
case "$THEME_CHOICE" in
    aur)
        if ! pacman -Q cyberpunk-grub-theme-git &>/dev/null; then
            msg "Installing cyberpunk-grub-theme-git from AUR"
            yay -S --noconfirm cyberpunk-grub-theme-git ||
            paru -S --noconfirm cyberpunk-grub-theme-git ||
            die "AUR helper not found. Install the package manually."
        fi
        SRC="/usr/share/grub/themes/Cyberpunk"
        ;;
    git|zip)
        TMP=$(mktemp -d)
        msg "Cloning CyberGRUB-2077"
        git clone https://github.com/NayamAmarshe/CyberGRUB-2077.git "$TMP" ||
        die "Clone failed"
        SRC="$TMP/CyberGRUB-2077/Cyberpunk"
        ;;
    *) die "Usage: $0  [aur|git]" ;;
esac

[[ -d $SRC ]] || die "Theme source not found: $SRC"

# 2. copy theme into /boot ----------------------------------------------------
mkdir -p "$(dirname "$THEME_DIR")"
cp -r "$SRC" "$THEME_DIR"
msg "Theme copied → ${THEME_DIR}"

# 3. patch /etc/default/grub --------------------------------------------------
if grep -q "^GRUB_THEME=" "$GRUB_DEFAULT"; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"${THEME_DIR}/theme.txt\"|" "$GRUB_DEFAULT"
else
    echo "GRUB_THEME=\"${THEME_DIR}/theme.txt\"" >> "$GRUB_DEFAULT"
fi
msg "GRUB_THEME updated"

# 4. gfxmode fallback
grep -q "^GRUB_GFXMODE=" "$GRUB_DEFAULT" || {
    echo 'GRUB_GFXMODE=1920x1080,auto' >> "$GRUB_DEFAULT"
    msg "Added GRUB_GFXMODE"
}

# 5. regenerate cfg -----------------------------------------------------------
grub-mkconfig -o /boot/grub/grub.cfg
msg "grub.cfg regenerated"

# 6. pacman hook (only for AUR path) ------------------------------------------
if [[ $THEME_CHOICE == "aur" ]]; then
    mkdir -p "$HOOK_DIR"
    cat > "$HOOK_FILE" <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = cyberpunk-grub-theme-git

[Action]
Description = Copy Cyberpunk theme to /boot/grub/themes
When = PostTransaction
Exec = /usr/bin/cp -r /usr/share/grub/themes/Cyberpunk /boot/grub/themes/
EOF
    msg "Pacman hook installed → ${HOOK_FILE}"
fi

msg "Done. Reboot to enjoy the neon boot screen."