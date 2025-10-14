#!/usr/bin/env bash
# dns-undo.sh – undo dns-setup-dot.sh (dnsmasq + stubby + custom resolv.conf)
set -euo pipefail

echo "==> Stopping and disabling stubby and dnsmasq..."
sudo systemctl disable --now stubby || true
sudo systemctl disable --now dnsmasq || true

echo "==> Removing config files..."
sudo rm -f /etc/dnsmasq.conf
sudo rm -rf /etc/dnsmasq.d
sudo rm -f /etc/stubby/stubby.yml

echo "==> Restoring /etc/resolv.conf..."
if compgen -G "/etc/resolv.conf.bak.*" > /dev/null; then
  latest_backup=$(ls -t /etc/resolv.conf.bak.* | head -n 1)
  echo "Restoring from backup: $latest_backup"
  sudo cp -a "$latest_backup" /etc/resolv.conf
else
  echo "No backup found. Using a basic fallback resolv.conf..."
  cat <<'EOF' | sudo tee /etc/resolv.conf >/dev/null
nameserver 1.1.1.1
nameserver 9.9.9.9
options edns0
EOF
fi
sudo chmod 644 /etc/resolv.conf

echo "==> Re-enabling systemd-resolved if present..."
if systemctl list-unit-files | grep -q '^systemd-resolved\.service'; then
  sudo systemctl unmask systemd-resolved.service || true
  sudo systemctl enable --now systemd-resolved.service || true
fi

echo "==> Cleaning up NetworkManager DNS override..."
if [[ -f /etc/NetworkManager/conf.d/dns.conf ]]; then
  sudo rm -f /etc/NetworkManager/conf.d/dns.conf
  sudo systemctl reload NetworkManager || true
fi

echo "==> Optionally uninstalling packages..."
read -rp "Remove dnsmasq and stubby packages? [y/N]: " remove_pkgs
if [[ "${remove_pkgs,,}" == "y" ]]; then
  sudo pacman -Rns --noconfirm dnsmasq stubby
fi

echo "✅ DNS setup reverted. System DNS
