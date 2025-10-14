#!/bin/bash
# setup-encrypted-dns.sh — Secure DNS-over-TLS setup for Arch Linux
# Author: Enosh
set -euo pipefail

echo "============================================="
echo "      Secure DNS-over-TLS Configuration"
echo "============================================="

# 1. Enable systemd-resolved
echo "→ Enabling systemd-resolved..."
sudo systemctl enable --now systemd-resolved.service

# 2. Create symlink for resolv.conf (systemd stub)
if [[ -L /etc/resolv.conf ]]; then
  echo "→ Existing resolv.conf symlink found, refreshing..."
  sudo rm -f /etc/resolv.conf
else
  echo "→ Removing any static /etc/resolv.conf..."
  sudo rm -f /etc/resolv.conf
fi

sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
echo "✓ /etc/resolv.conf now linked to systemd-resolved stub."

# 3. Configure resolved.conf with DoT providers
echo "→ Configuring systemd-resolved for DNS-over-TLS..."
sudo tee /etc/systemd/resolved.conf >/dev/null <<'EOF'
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 8.8.8.8#dns.google
FallbackDNS=8.8.4.4#dns.google
DNSOverTLS=yes
Domains=.
EOF

# 4. Ensure NetworkManager plays nice
echo "→ Adjusting NetworkManager to use systemd-resolved..."
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/10-systemd-resolved.conf >/dev/null <<'EOF'
[main]
dns=systemd-resolved
EOF

# 5. Restart services
echo "→ Restarting NetworkManager and systemd-resolved..."
sudo systemctl restart NetworkManager
sudo systemctl restart systemd-resolved

# 6. Verification
echo "→ Checking resolver status..."
sleep 2
resolvectl status | grep -E 'Current DNS Server|DNS Servers|DNS Over TLS'

echo "============================================="
echo "✅ DNS-over-TLS setup complete."
echo "All DNS queries are now encrypted via Cloudflare + Google."
echo "To confirm, run: resolvectl query example.com"
echo "============================================="
