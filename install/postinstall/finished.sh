#!/bin/bash
# ----------------------------------------------------------
# Copy background images + display post-reboot instructions
# ----------------------------------------------------------

# Ensure target directory exists
sudo mkdir -p ~/Pictures/Backgrounds

# Copy backgrounds safely
if [[ -d ~/.local/share/archy/themes/Backgrounds ]]; then
  sudo cp -r ~/.local/share/archy/themes/Backgrounds/* ~/Pictures/Backgrounds/
  echo "[INFO] ✅ Background images copied to ~/Pictures/Backgrounds"
else
  echo "[WARN] ⚠️  Source directory not found: ~/.local/share/archy/themes/Backgrounds"
fi

# ------------------------------------------------------
#   Disable networkmanager-wait-online for faster boots
# -------------------------------------------------------

sudo systemctl disable NetworkManager-wait-online.service

# Post-reboot tasks
cat <<'EOF'

===========================================================
👉  After reboot, run the following commands:

  sudo systemctl start powertop.service     # Power optimization
  sudo pacman -Rns sddm                     # Remove SDDM if unused
  sudo aa-status                            # Check Apparmor status
  linutil                                   # To start the linutil toolbox
  nvim                                      # To load lazyvim configs
===========================================================

EOF
