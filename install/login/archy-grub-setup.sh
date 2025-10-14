#!/bin/bash
set -e

# Detect EFI or BIOS
if [[ -d /sys/firmware/efi ]]; then
  EFI=true
  BOOTMODE="UEFI"
else
  EFI=false
  BOOTMODE="BIOS"
fi

echo -e "\e[34m==> Setting up GRUB Bootloader for $BOOTMODE...\e[0m"

# --- mkinitcpio Hooks ---
sudo tee /etc/mkinitcpio.conf.d/archy_hooks.conf >/dev/null <<EOF
HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap consolefont block encrypt filesystems fsck btrfs)
EOF
sudo mkinitcpio -P

# --- Install GRUB ---
if $EFI; then
  sudo pacman -S --noconfirm --needed grub efibootmgr os-prober
  sudo grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="Archy" --recheck
else
  sudo pacman -S --noconfirm --needed grub os-prober
  sudo grub-install --target=i386-pc /dev/$(lsblk -no pkname $(findmnt -n -o SOURCE /))
fi

# --- Install grub-btrfs for snapshot integration ---
sudo pacman -S --noconfirm --needed grub-btrfs snapper inotify-tools

sudo systemctl enable --now grub-btrfsd.service

# --- Configure Snapper ---
for cfg in root home; do
  if ! sudo snapper list-configs | grep -q "$cfg"; then
    if [[ "$cfg" == "root" ]]; then
      sudo snapper -c root create-config /
    else
      sudo snapper -c home create-config /home
    fi
  fi
done

# --- Tweak snapper default configs ---
for cfg in /etc/snapper/configs/root /etc/snapper/configs/home; do
  [[ -f "$cfg" ]] || continue
  sudo sed -i 's/^TIMELINE_CREATE="yes"/TIMELINE_CREATE="no"/' "$cfg"
  sudo sed -i 's/^NUMBER_LIMIT="50"/NUMBER_LIMIT="5"/' "$cfg"
  sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT="10"/NUMBER_LIMIT_IMPORTANT="5"/' "$cfg"
done


# Backup GRUB config before modifying
if [[ -f /etc/default/grub ]]; then
  backup_timestamp=$(date +"%Y%m%d%H%M%S")
  sudo cp /etc/default/grub "/etc/default/grub.bak.${backup_timestamp}"
  echo "Backed up /etc/default/grub to grub.bak.${backup_timestamp}"
else
  echo "No existing /etc/default/grub found; skipping backup."
fi

# --- Theme / Styling ---
sudo cp -r ~/.local/share/archy/install/Vixy /boot/grub/themes/Vixy
# --- Ensure grub-theme setting exists (update or append) ---
if grep -q '^GRUB_THEME=' /etc/default/grub; then
  sudo sed -i 's/^GRUB_THEME=.*/GRUB_THEME="/boot/grub/themes/Vixy/theme.txt"/' /etc/default/grub
else
  echo 'GRUB_THEME="/boot/grub/themes/Vixy/theme.txt"' | sudo tee -a /etc/default/grub >/dev/null
fi

# --- Ensure grub-btrfs setting exists (update or append) ---
if grep -q '^GRUB_BTRFS_SHOW_SNAPSHOTS_SUBMENU=' /etc/default/grub; then
  sudo sed -i 's/^GRUB_BTRFS_SHOW_SNAPSHOTS_SUBMENU=.*/GRUB_BTRFS_SHOW_SNAPSHOTS_SUBMENU=y/' /etc/default/grub
else
  echo 'GRUB_BTRFS_SHOW_SNAPSHOTS_SUBMENU=y' | sudo tee -a /etc/default/grub >/dev/null
fi

# --- Generate Config ---
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\e[32m==> GRUB setup complete!\e[0m"
echo "  - Snapper snapshots will appear in the GRUB menu under 'Arch Linux Snapshots'"
echo "Generated GRUB config at /boot/grub/grub.cfg"
echo "  - Use 'sudo grub-mkconfig -o /boot/grub/grub.cfg' after creating snapshots to refresh entries"
