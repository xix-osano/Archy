# Only run if GRUB is present
if [ -f "/etc/default/grub" ]; then
  echo "Detected GRUB"

  # Backup GRUB config before modifying
  backup_timestamp=$(date +"%Y%m%d%H%M%S")
  sudo cp /etc/default/grub "/etc/default/grub.bak.${backup_timestamp}"

  # Check if splash or quiet are already in GRUB_CMDLINE_LINUX_DEFAULT
  if ! grep -q "splash" /etc/default/grub || ! grep -q "quiet" /etc/default/grub; then
    # Get current GRUB_CMDLINE_LINUX_DEFAULT value
    current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)

    # Add splash and quiet if missing
    new_cmdline="$current_cmdline"
    [[ ! "$current_cmdline" =~ splash ]] && new_cmdline="$new_cmdline splash"
    [[ ! "$current_cmdline" =~ quiet ]] && new_cmdline="$new_cmdline quiet"

    # Trim spaces
    new_cmdline=$(echo "$new_cmdline" | xargs)

    # Update GRUB config
    sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"|" /etc/default/grub

    echo "Updated GRUB_CMDLINE_LINUX_DEFAULT to: $new_cmdline"

    # Regenerate GRUB configuration
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  else
    echo "GRUB already configured with splash and quiet parameters"
  fi
  
else
  echo "GRUB not detected on this system."
fi
