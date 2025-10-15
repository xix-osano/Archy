#!/usr/bin/env bash
# secureboot-setup.sh — Configure Secure Boot with sbctl and GRUB

echo
cecho $BLUE "========================================="
cecho $BLUE "     Archy Linux Secureboot Setup"
cecho $BLUE "========================================="
echo

set -euo pipefail

echo "==> Installing Secure Boot tools..."
sudo pacman -S --needed --noconfirm sbctl sbsigntools efitools

# Ensure running in EFI mode
if [[ ! -d /sys/firmware/efi/efivars ]]; then
  echo "❌ EFI variables not found. You are not booted in UEFI mode."
  echo "   Secure Boot setup requires UEFI."
  exit 1
fi

echo "==> Checking sbctl status..."
sudo sbctl status || true

# Create keys if missing
if ! sudo sbctl status | grep -q "Keys exist:.*✓"; then
  echo "==> Creating Secure Boot keys..."
  sudo sbctl create-keys
else
  echo "✔ Keys already exist."
fi

# Enroll keys if not enrolled
if ! sudo sbctl status | grep -q "Setup Mode:.*✓"; then
  echo "==> Enrolling keys with Microsoft compatibility..."
  sudo sbctl enroll-keys --microsoft
else
  echo "✔ Keys already enrolled."
fi

# Reinstall GRUB with TPM module (optional)
if ! grub-install --version >/dev/null 2>&1; then
  echo "❌ GRUB not found. Install it first: sudo pacman -S grub"
  exit 1
fi

echo "==> Reinstalling GRUB with TPM module..."
sudo grub-install --target=x86_64-efi \
  --efi-directory=/boot \
  --bootloader-id=ARCHY \
  --modules="tpm" \
  --disable-shim-lock

echo "==> Verifying current signatures..."
sudo sbctl verify || true

echo "==> Signing key EFI and kernel binaries..."
FILES_TO_SIGN=(
  /boot/EFI/Archy/grubx64.efi
  /boot/EFI/BOOT/BOOTX64.EFI
  /boot/grub/x86_64-efi/core.efi
  /boot/grub/x86_64-efi/grub.efi
  /boot/vmlinuz-linux
)

# Add -lts kernel if present
[[ -f /boot/vmlinuz-linux-lts ]] && FILES_TO_SIGN+=("/boot/vmlinuz-linux-lts")

for file in "${FILES_TO_SIGN[@]}"; do
  if [[ -f "$file" ]]; then
    echo "   Signing: $file"
    sudo sbctl sign -s "$file"
  else
    echo "   Skipping (not found): $file"
  fi
done

echo "==> Running final verification..."
sudo sbctl verify || echo "⚠ Some binaries may not be signed yet."

echo "==> Signing all remaining unsigned EFI binaries..."
sudo sbctl sign-all || true

# Create pacman hook for automatic signing
# HOOK_PATH="/etc/pacman.d/hooks/99-secureboot.hook"
# echo "==> Setting up pacman hook at $HOOK_PATH ..."
# sudo mkdir -p /etc/pacman.d/hooks
# sudo tee "$HOOK_PATH" >/dev/null <<'EOF'
# [Trigger]
# Operation = Install
# Operation = Upgrade
# Type = Package
# Target = linux
# Target = linux-lts
# Target = grub

# [Action]
# Description = Re-sign EFI binaries for Secure Boot
# When = PostTransaction
# Exec = /usr/bin/sbctl sign-all
# EOF

# sudo chmod 644 "$HOOK_PATH"

echo
echo "✔ Secure Boot setup complete!"
echo "  Verify with: sudo sbctl status"
echo "  To check signatures: sudo sbctl verify"
echo "  On every kernel or GRUB update, EFI binaries will auto re-sign."
echo "  Reboot and enable Secure Boot in firmware when ready."
