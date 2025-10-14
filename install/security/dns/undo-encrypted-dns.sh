#!/bin/bash
# undo-encrypted-dns.sh — revert everything the encrypted-dns script touched
set -euo pipefail

echo "============================================="
echo "  Reverting DNS-over-TLS (systemd-resolved)"
echo "============================================="

# 1. Stop & disable systemd-resolved
#sudo systemctl disable --now systemd-resolved 2>/dev/null || true

# 2. Remove NetworkManager delegate file
sudo rm -f /etc/NetworkManager/conf.d/10-systemd-resolved.conf

# 3. Delete resolved.conf so it returns to stock
sudo rm -f /etc/systemd/resolved.conf

# 4. Restore classic resolv.conf (NetworkManager-controlled)
sudo rm -f /etc/resolv.conf
sudo unlink /etc/resolv.conf

# 5. Tell NetworkManager to manage DNS again
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/20-dns-default.conf >/dev/null <<'EOF'
[main]
dns=default
EOF

# 6. Restart NM
sudo systemctl restart NetworkManager

# 7. Show result
echo "→ Current DNS:"
resolvectl status | grep -E 'Current DNS Server|DNS Servers' || cat /etc/resolv.conf

echo "============================================="
echo "✅ DNS back to NetworkManager defaults."
echo "============================================="