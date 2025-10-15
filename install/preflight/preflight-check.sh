#!/usr/bin/env bash
# =======================================================
#  Arch System Integrity Preflight Checker
#  Ensures proper environment before continuing execution
# =======================================================

echo
cecho $BLUE "============================================="
cecho $BLUE " Preflight Checks"
cecho $BLUE "============================================="
echo

set -euo pipefail

echo "🚀 Running environment preflight checks..."
sleep 0.5

# ---------- Helper for logging ----------
log() { cecho $GREEN -e "🔹 $*"; }
error() { cecho $RED -e "❌ $*"; }

# ---------- 1. Check Arch-based Distro ----------
if ! grep -qEi "arch" /etc/os-release; then
  error " This script is only for Arch Linux or Arch-based distros."
  error "💡 Detected OS: $(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '\"')"
  exit 1
else
  log "Arch Linux detected ✅"
fi

# ---------- 2. Check for GRUB bootloader ----------
if [[ -d /boot/grub || -d /boot/efi/EFI/grub || -f /boot/grub/grub.cfg ]]; then
  log "GRUB bootloader detected ✅"
else
  error " GRUB bootloader not found."
  error "⚠️ This script configures GRUB parameters (AppArmor, LSM, etc.)"
  error "💡 Please ensure GRUB is installed and configured before continuing."
  exit 1
fi

# ---------- 3. Check for Btrfs filesystem ----------
if ! findmnt -n -o FSTYPE / | grep -q "btrfs"; then
  error " Root filesystem is not Btrfs."
  error "💡 Snapper requires a Btrfs subvolume layout (/, @home, etc.)"
  error "Aborting for your data’s safety."
  exit 1
else
  log "Btrfs filesystem detected ✅"
fi

# ---------- 4. Check for Snapper installation ----------
if ! command -v snapper &>/dev/null; then
  error " Snapper not installed."
  echo "💡 Run: sudo pacman -S --noconfirm snapper"
  echo "Then configure with: sudo snapper -c root create-config /"
  exit 1
else
  log "Snapper detected ✅"
fi

# ---------- 5. Verify Snapper configuration ----------
if ! sudo snapper list-configs | grep -q "root"; then
  error " Snapper root configuration not found."
  echo "💡 Run: sudo snapper -c root create-config /"
  exit 1
else
  log "Snapper root config found ✅"
fi

cecho $BLUE "---------------------------------------------"
cecho $BLUE "All preflight checks ✅ passed successfully!"
cecho $BLUE "Ready to proceed with main Arch setup."
cecho $BLUE "---------------------------------------------"
sleep 1
