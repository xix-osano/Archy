#!/bin/bash
# =========================================
#  Arch Linux Defensive Security Setup
#  Author: Enosh (System defense)
# =========================================

# Exit immediately on error
set -e

# -----------------------------------------
# 1. Firewall & Network Defense
# -----------------------------------------
echo "=== Installing and enabling UFW Firewall ==="
sudo pacman -S --noconfirm ufw
sudo systemctl enable --now ufw

#sudo ufw limit 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit ssh comment 'Rate limit SSH to prevent brute-force'
sudo ufw enable
echo "Firewall active and configured."

# -----------------------------------------
# 2. Apparmor
# -----------------------------------------
echo "==> Installing AppArmor and related utilities..."
sudo pacman -S --needed --noconfirm apparmor audit

echo "==> Enabling AppArmor kernel service..."
sudo systemctl enable --now apparmor.service

# Handle non-Grub bootloaders
if [[ ! -f /etc/default/grub ]]; then
  echo "⚠ No GRUB config found (systemd-boot or custom loader detected)."
  echo "   Please manually add: lsm=landlock,lockdown,yama,apparmor,bpf apparmor=1 security=apparmor"
  exit 0
fi

if ! zgrep -q "CONFIG_SECURITY_APPARMOR=y" /proc/config.gz 2>/dev/null; then
  echo "⚠ AppArmor not built into kernel. Install linux-apparmor or rebuild with AppArmor support."
  exit 1
fi

if ! grep -q "lsm=landlock,lockdown,yama,apparmor,bpf" /etc/default/grub || \
   ! grep -q "apparmor=1" /etc/default/grub || \
   ! grep -q "security=apparmor" /etc/default/grub; then
  # Get current GRUB_CMDLINE_LINUX_DEFAULT value
  current_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub | cut -d'"' -f2)

  # Append lsm and apparmor parameters if missing
  new_cmdline="$current_cmdline"
  [[ ! "$current_cmdline" =~ lsm=landlock,lockdown,yama,apparmor,bpf ]] && new_cmdline="$new_cmdline lsm=landlock,lockdown,yama,apparmor,bpf"
  [[ ! "$current_cmdline" =~ apparmor=1 ]] && new_cmdline="$new_cmdline apparmor=1"
  [[ ! "$current_cmdline" =~ security=apparmor ]] && new_cmdline="$new_cmdline security=apparmor"

  # Trim spaces
  new_cmdline=$(echo "$new_cmdline" | xargs)

  # Update GRUB config
  sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\".*\"|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"|" /etc/default/grub

  echo "Updated GRUB_CMDLINE_LINUX_DEFAULT to: $new_cmdline"

  # Regenerate GRUB configuration
  sudo grub-mkconfig -o /boot/grub/grub.cfg
else
  echo "GRUB already configured with lsm and apparmor parameters"
fi

# Confirm AppArmor is active
if [[ "$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null)" != "Y" ]]; then
  echo "Kernel command line now contains:"
  grep "GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub

  echo "✔ AppArmor parameters set. Reboot required for changes to take effect."
  echo "   Reboot. And run sudo aa-status"
  echo
fi

# -----------------------------------------
# 3. Intrusion Prevention & Audit
# -----------------------------------------
echo "=== Installing Auditd, and PSACCT ==="
sudo pacman -S --noconfirm audit acct

sudo systemctl enable --now auditd
sudo systemctl enable --now psacct

echo "Auditd, and Process Accounting enabled."

# -----------------------------------------
# 4. Rootkit & Malware Scanning
# -----------------------------------------
echo "=== Installing malware and rootkit scanners ==="
sudo pacman -S --noconfirm rkhunter chkrootkit clamav
sudo freshclam
sudo systemctl enable --now clamav-freshclam.service

echo "Scanners ready. Run 'rkhunter --check' or 'chkrootkit' periodically."

# -----------------------------------------
# 5. File Integrity & Intrusion Detection
# -----------------------------------------
echo "=== Installing and initializing AIDE ==="
sudo pacman -S --noconfirm aide
sudo aide --init
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
echo "AIDE database initialized. Use 'sudo aide --check' to verify integrity."

# -----------------------------------------
# 6. System Auditing and Recommendations
# -----------------------------------------
echo "=== Installing Lynis for security auditing ==="
sudo pacman -S --noconfirm lynis
sudo lynis audit system

echo "==> Installing and enabling NetworkManager..."
sudo pacman -S --needed --noconfirm networkmanager
sudo systemctl enable --now NetworkManager

echo "==> Checking systemd-networkd status..."
systemctl is-enabled systemd-networkd || true
systemctl is-active systemd-networkd || true

echo "==> Disabling and masking systemd-networkd..."
sudo systemctl disable --now systemd-networkd.service || true
sudo systemctl mask systemd-networkd.service || true

sudo systemctl disable --now systemd-networkd-wait-online.service || true
sudo systemctl mask systemd-networkd-wait-online.service || true

echo "==> Verifying systemd-networkd status..."
systemctl status systemd-networkd --no-pager || true

echo "✅ NetworkManager setup complete. systemd-networkd is disabled and masked."

# -----------------------------------------
# 7. Optional Network Monitoring
# -----------------------------------------
echo "=== Installing optional network defense tools (Snort, Wireshark) ==="
sudo pacman -S --noconfirm snort wireshark-cli
echo "Snort and Wireshark installed (disabled by default)."

# -----------------------------------------
# 9. System Summary
# -----------------------------------------
echo "=== SECURITY SUMMARY ==="
echo "• Firewall (ufw): enabled"
echo "• Apparmor setup"
echo "• Auditd active"
echo "• AIDE integrity check: configured"
echo "• Malware scanners: installed"
echo "• Lynis audit: completed"
echo "• Optional IDS tools: ready"

echo "System hardened. Reboot recommended."
