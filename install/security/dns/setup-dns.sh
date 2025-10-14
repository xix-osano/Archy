#!/bin/bash

# setup-dns.sh — configure DNS providers for NetworkManager

set -euo pipefail

if [[ -z ${1:-} ]]; then
  dns=$(gum choose --height 5 --header "Select DNS provider" Cloudflare DHCP Custom)
else
  dns=$1
fi

CONFIG_DIR="/etc/NetworkManager/conf.d"
DNS_CONF="$CONFIG_DIR/dns.conf"

sudo mkdir -p "$CONFIG_DIR"

case "$dns" in
Cloudflare)
  echo "→ Configuring Cloudflare DNS (DoT optional via stubby or local proxy)"
  sudo tee "$DNS_CONF" >/dev/null <<'EOF'
[main]
dns=default

[global-dns]
servers=1.1.1.1;1.0.0.1;9.9.9.9;149.112.112.112
domains=.
EOF

  # Disable automatic DNS from DHCP
  for file in /etc/NetworkManager/system-connections/*.nmconnection; do
    [[ -f "$file" ]] || continue
    sudo sed -i '/^ignore-auto-dns=/d' "$file"
    sudo sed -i '/^\[ipv4\]/a ignore-auto-dns=true' "$file"
    sudo sed -i '/^\[ipv6\]/a ignore-auto-dns=true' "$file"
  done
  ;;

DHCP)
  echo "→ Reverting to DHCP-provided DNS"
  sudo tee "$DNS_CONF" >/dev/null <<'EOF'
[main]
dns=default
EOF

  for file in /etc/NetworkManager/system-connections/*.nmconnection; do
    [[ -f "$file" ]] || continue
    sudo sed -i '/^ignore-auto-dns=/d' "$file"
    sudo sed -i '/^\[ipv4\]/a ignore-auto-dns=false' "$file"
    sudo sed -i '/^\[ipv6\]/a ignore-auto-dns=false' "$file"
  done
  ;;

Custom)
  read -rp "Enter your DNS servers (space-separated, e.g. '192.168.1.1 1.1.1.1'): " dns_servers
  if [[ -z "$dns_servers" ]]; then
    echo "Error: No DNS servers provided."
    exit 1
  fi

  echo "→ Applying custom DNS servers: $dns_servers"
  servers=$(echo "$dns_servers" | sed 's/ /;/g')

  sudo tee "$DNS_CONF" >/dev/null <<EOF
[main]
dns=default

[global-dns]
servers=$servers
domains=.
EOF

  for file in /etc/NetworkManager/system-connections/*.nmconnection; do
    [[ -f "$file" ]] || continue
    sudo sed -i '/^ignore-auto-dns=/d' "$file"
    sudo sed -i '/^\[ipv4\]/a ignore-auto-dns=true' "$file"
    sudo sed -i '/^\[ipv6\]/a ignore-auto-dns=true' "$file"
  done
  ;;
esac

echo "→ Restarting NetworkManager..."
sudo systemctl restart NetworkManager

echo "→ DNS configuration complete. Current resolver setup:"
resolvectl status | grep -A5 "Current DNS"
