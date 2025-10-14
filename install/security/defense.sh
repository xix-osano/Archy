#!/bin/bash
# =========================================
#  Arch Linux Defensive Security Setup
#  Author: Enosh (System defense)
# =========================================

# Exit immediately on error
set -e
LOGFILE="$HOME/security-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "Logging to $LOGFILE"


echo "========================================="
echo "     Arch Linux Defensive Setup Tool"
echo "========================================="

# -----------------------------------------
# 0. Get user email for alerts
# -----------------------------------------
read -rp "Enter the email address for security alerts: " ALERT_EMAIL

# Basic validation
if [[ ! "$ALERT_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
  echo "Invalid email address format. Exiting..."
  exit 1
fi

echo "Using $ALERT_EMAIL for all alert notifications."
sleep 1

# -----------------------------------------
# 1. Firewall & Network Defense
# -----------------------------------------
echo "=== Installing and enabling UFW Firewall ==="
sudo pacman -S --noconfirm ufw
sudo systemctl enable --now ufw

#sudo ufw limit 22/tcp
#sudo ufw allow 80/tcp
#sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit ssh comment 'Rate limit SSH to prevent brute-force'
sudo ufw enable
echo "Firewall active and configured."

# -----------------------------------------
# 2. SSH Hardening
# -----------------------------------------
if [[ -f /etc/ssh/sshd_config ]]; then
    echo "=== Hardening SSH configuration ==="
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    echo "SSH hardened: root login and password auth disabled."
fi

# -----------------------------------------
# 3. Apparmor
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
# 4. Intrusion Prevention & Audit
# -----------------------------------------
echo "=== Installing Fail2Ban and Auditd==="
sudo pacman -S --noconfirm fail2ban audit postfix inetutils
sudo systemctl enable --now fail2ban
sudo systemctl enable --now auditd
sudo systemctl enable --now postfix

# Compute a reliable hostname in the current shell (avoid running hostname inside sudo heredoc)
HOSTNAME="$(/usr/bin/hostname 2>/dev/null || uname -n)"


# Configure Fail2Ban with user-provided email and safe hostname substitution
echo "=== Configuring Fail2Ban email notifications ==="
sudo bash -c "cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
destemail = $ALERT_EMAIL
sender = fail2ban@$HOSTNAME
mta = sendmail
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF"
sudo systemctl restart fail2ban
echo "Fail2Ban configured to alert $ALERT_EMAIL (sender: fail2ban@$HOSTNAME)."

# -----------------------------------------
# 5. Rootkit & Malware Scanning
# -----------------------------------------
echo "=== Installing malware and rootkit scanners ==="
sudo pacman -S --noconfirm rkhunter clamav
sudo freshclam
sudo systemctl enable --now clamav-freshclam.service

# Schedule daily scan and email results
sudo bash -c "cat > /usr/local/bin/daily-clamscan.sh <<EOF
#!/bin/bash
clamscan -r /home --log=/var/log/clamav/daily-scan.log
mail -s 'ClamAV Daily Scan Report - $(hostname)' '$ALERT_EMAIL' < /var/log/clamav/daily-scan.log
EOF"
sudo chmod +x /usr/local/bin/daily-clamscan.sh

sudo bash -c "cat > /etc/systemd/system/daily-clamscan.timer <<EOF
[Unit]
Description=Daily ClamAV Scan Timer

[Timer]
OnCalendar=03:00
Persistent=true

[Install]
WantedBy=timers.target
EOF"

sudo bash -c "cat > /etc/systemd/system/daily-clamscan.service <<EOF
[Unit]
Description=Run ClamAV Daily Scan

[Service]
ExecStart=/usr/local/bin/daily-clamscan.sh
EOF"

sudo systemctl enable --now daily-clamscan.timer
echo "✅ ClamAV daily scan timer active."

# -----------------------------------------
# 6. File Integrity & Intrusion Detection
# -----------------------------------------
echo "=== Installing and initializing AIDE ==="
yay -S --noconfirm aide
sudo aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

sudo bash -c "cat > /usr/local/bin/aide-check.sh <<EOF
#!/bin/bash
RESULT=\$(aide --check)
echo \"\$RESULT\" | mail -s 'AIDE Integrity Check Report - $(hostname)' '$ALERT_EMAIL'
EOF"
sudo chmod +x /usr/local/bin/aide-check.sh

sudo bash -c "cat > /etc/systemd/system/aide-check.timer <<EOF
[Unit]
Description=Daily AIDE Integrity Check Timer

[Timer]
OnCalendar=04:00
Persistent=true

[Install]
WantedBy=timers.target
EOF"

sudo bash -c "cat > /etc/systemd/system/aide-check.service <<EOF
[Unit]
Description=Run AIDE Integrity Check

[Service]
ExecStart=/usr/local/bin/aide-check.sh
EOF"

sudo systemctl enable --now aide-check.timer
echo "✅ AIDE integrity timer active."

# -----------------------------------------
# 7. System Auditing, Reporting and Recommendations
# -----------------------------------------
echo "=== Installing Lynis and Logwatch ==="
sudo pacman -S --noconfirm lynis logwatch


sudo bash -c "cat > /usr/local/bin/weekly-security-report.sh <<EOF
#!/bin/bash
lynis audit system --quiet > /var/log/lynis-weekly.log
logwatch --output mail --mailto $ALERT_EMAIL --detail high
EOF"
sudo chmod +x /usr/local/bin/weekly-security-report.sh

sudo bash -c "cat > /etc/systemd/system/weekly-security-report.timer <<EOF
[Unit]
Description=Weekly Security Audit Timer

[Timer]
OnCalendar=Sun *-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF"

sudo bash -c "cat > /etc/systemd/system/weekly-security-report.service <<EOF
[Unit]
Description=Run Weekly Security Audit

[Service]
ExecStart=/usr/local/bin/weekly-security-report.sh
EOF"

sudo systemctl enable --now weekly-security-report.timer
echo "✅ Weekly security audit timer active."

# Network Management
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
# 8. Optional Network Monitoring
# -----------------------------------------
echo "=== Installing optional network defense tools (Wireshark) ==="
sudo pacman -S --noconfirm wireshark-cli
echo "Wireshark installed (disabled by default)."

# -----------------------------------------
# 9. Test email delivery
# -----------------------------------------
echo "Testing email delivery..."
if echo "Test email from Arch Defensive Setup" | mail -s "Security setup test" "$ALERT_EMAIL"; then
    echo "✅ Test email sent successfully to $ALERT_EMAIL."
else
    echo "⚠ Failed to send test email. Check Postfix or mail configuration."
fi


# -----------------------------------------
# 10. Summary
# -----------------------------------------
echo "========================================="
echo " SECURITY SETUP COMPLETE"
echo "========================================="
echo "Alerts and reports will be sent to: $ALERT_EMAIL"
echo ""
echo "Included protections:"
echo "• Firewall (ufw): active"
echo "• SSH: hardened"
echo "• Fail2Ban: email alerts configured"
echo "• ClamAV: daily scan + email reports"
echo "• AIDE: integrity checks + email reports"
echo "• Lynis & Logwatch: weekly reports"
echo "• AppArmor: active"
echo "• Snort IDS: ready (manual setup)"
echo ""
echo "You can change your email anytime by editing:"
echo "  /etc/fail2ban/jail.local"
echo "  /etc/cron.daily/aide-check"
echo "  /etc/cron.weekly/security-report"
echo ""
echo "Reboot recommended after installation."
