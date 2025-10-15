#!/bin/bash
# =========================================
#  Arch Linux Defensive Security Setup
#  Author: Enosh (System defense)
# =========================================

echo
cecho $BLUE "========================================="
cecho $BLUE "     Archy Linux Defensive Setup Tool"
cecho $BLUE "========================================="
echo

set -euo pipefail
LOGFILE="$HOME/security-setup.log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "Logging to $LOGFILE"

# -----------------------------------------
# 0. Module selection
# -----------------------------------------
cecho $YELLOW "Select modules to install (y/n):"

read -rp "Install UFW firewall? (y/n): " INSTALL_UFW
read -rp "Harden SSH? (y/n): " INSTALL_SSH
read -rp "Install AppArmor? (y/n): " INSTALL_APPARMOR
read -rp "Install optional extras (wireshark)? (y/n): " INSTALL_EXTRAS

# -----------------------------------------
# 1. Firewall (UFW)
# -----------------------------------------
if [[ "$INSTALL_UFW" == "y" ]]; then
    echo "=== Installing and enabling UFW ==="
    sudo pacman -S --noconfirm ufw
    sudo systemctl enable --now ufw

    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw --force enable
    sudo ufw status verbose
    echo "UFW enabled. Firewall active and configured."
fi

# -----------------------------------------
# 2. SSH hardening
# -----------------------------------------
if [[ "$INSTALL_SSH" == "y" && -f /etc/ssh/sshd_config ]]; then
    echo "=== Hardening SSH ==="
    sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sudo systemctl restart sshd
    echo "SSH hardened: root login and password auth disabled."
fi

# -----------------------------------------
# 3. AppArmor
# -----------------------------------------
if [[ "$INSTALL_APPARMOR" == "y" ]]; then
    echo "=== Installing AppArmor ==="
    sudo pacman -S --needed --noconfirm apparmor audit
    sudo systemctl enable --now apparmor.service

    if [[ -f /etc/default/grub ]]; then
        current=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT" /etc/default/grub | cut -d'"' -f2)
        new="$current"
        [[ ! "$current" =~ lsm= ]] && new="$new lsm=landlock,lockdown,yama,apparmor,bpf"
        [[ ! "$current" =~ apparmor=1 ]] && new="$new apparmor=1"
        [[ ! "$current" =~ security=apparmor ]] && new="$new security=apparmor"
        new=$(echo "$new" | xargs)
        sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new\"|" /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo "GRUB updated – reboot required for AppArmor"
    else
        echo "⚠ No GRUB detected – add kernel parameters manually for AppArmor."
    fi
fi

# -----------------------------------------
# 4. NetworkManager
# -----------------------------------------
echo "=== Switching to NetworkManager ==="
sudo pacman -S --needed --noconfirm networkmanager
sudo systemctl enable --now NetworkManager
sudo systemctl disable --now systemd-networkd.service 2>/dev/null || true
sudo systemctl mask systemd-networkd.service 2>/dev/null || true

# -----------------------------------------
# 5. Optional extras
# -----------------------------------------
if [[ "$INSTALL_EXTRAS" == "y" ]]; then
    sudo pacman -S --noconfirm wireshark-cli
    sudo gpasswd -a "$USER" wireshark 2>/dev/null || true
fi

# -----------------------------------------
# Completion
# -----------------------------------------
cecho $GREEN "✅ Arch Defensive Setup. reboot recommended"
cecho $GREEN "========================================="
cecho $GREEN " SECURITY SETUP COMPLETE "
cecho $GREEN "========================================="
cecho $GREEN "Reboot to activate AppArmor (if kernel parameters were added)."
