#!/usr/bin/env bash
# -------------------------------------------------------------
# Smart DNS Configurator v2.1
# Automatically sets DNS per connection:
#   - University SSID → keep DHCP DNS
#   - All others → Cloudflare + Google (IPv4 + IPv6)
# Integrates NetworkManager + systemd-resolved cleanly.
# -------------------------------------------------------------

echo
cecho $BLUE "========================================="
cecho $BLUE "     Archy Linux Smart DNS setup"
cecho $BLUE "========================================="
echo

set -euo pipefail

# ---------- 0. Helper Functions ----------
log() { cecho $GREEN -e "[\e[1;34mINFO\e[0m] $*"; }
warn() { cecho $YELLOW -e "[\e[1;33mWARN\e[0m] $*"; }
error() { cecho $RED -e "[\e[1;31mERROR\e[0m] $*" >&2; exit 1; }

# ---------- 1.  Collect University SSID & preflight check ----------
read -rp "Enter your University SSID (exact name): " UNI_SSID
[[ -z "$UNI_SSID" ]] && error "SSID cannot be empty. Aborting."

if ! command -v nmcli &>/dev/null; then
  error "NetworkManager CLI (nmcli) not found. Install NetworkManager first."
fi

# ---------- 2.  systemd-resolved setup ----------
if ! systemctl is-active --quiet systemd-resolved; then
  log "Enabling systemd-resolved…"
  sudo systemctl enable --now systemd-resolved
else
  log "systemd-resolved already active."
fi

if [[ ! "$(readlink /etc/resolv.conf 2>/dev/null)" =~ resolve ]]; then
  log "Linking /etc/resolv.conf → systemd-resolved stub..."
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
else
  log "/etc/resolv.conf already linked to systemd-resolved."
fi

# ---------- 3.  NetworkManager Integration ----------
CONF_DIR=/etc/NetworkManager/conf.d
sudo mkdir -p "$CONF_DIR"
if ! sudo grep -q "dns=systemd-resolved" "$CONF_DIR/resolved.conf" 2>/dev/null; then
  log "Pointing NetworkManager to systemd-resolved …"
  printf "%s\n" "[main]" "dns=systemd-resolved" | sudo tee "$CONF_DIR/resolved.conf" >/dev/null
  sudo systemctl restart NetworkManager
  log "NetworkManager restarted successfully."
fi

# ---------- 4.  DNS server lists ----------
QUAD9_IPV4="9.9.9.9"
CLOUD_IPV4="1.1.1.1 1.0.0.1"
GOOGLE_IPV4="8.8.8.8"

QUAD9_IPV6="2620:fe::fe"
CLOUD_IPV6="2606:4700:4700::1111 2606:4700:4700::1001"
GOOGLE_IPV6="2001:4860:4860::8888 2001:4860:4860::8844"

COMBINED_IPV4="$QUAD9_IPV4 $CLOUD_IPV4 $GOOGLE_IPV4"
COMBINED_IPV6="$QUAD9_IPV6 $CLOUD_IPV6 $GOOGLE_IPV6"

# ---------- 5.  Per-connection DNS ----------
mapfile -t UUIDS < <(nmcli -t -f UUID,TYPE connection show | grep -E "802-11-wireless|ethernet" | cut -d: -f1)
if ((${#UUIDS[@]} == 0)); then
  warn "No saved network connections found. Connect to a network first, then rerun this script."
  exit 0
fi

for UUID in "${UUIDS[@]}"; do
  NAME=$(nmcli -g connection.id connection show uuid "$UUID")          # modern nmcli
  log "Processing: $NAME"

  if [[ "$NAME" == "$UNI_SSID" ]]; then
    log "→ Matched university SSID. Keeping DHCP DNS."
    sudo nmcli connection modify "$UUID" ipv4.ignore-auto-dns no   ipv4.dns ""
    sudo nmcli connection modify "$UUID" ipv6.ignore-auto-dns no   ipv6.dns ""
  else
    log "→ Non-university connection. Applying Quad9 + Cloudflare + Google DNS."
    sudo nmcli connection modify "$UUID" ipv4.ignore-auto-dns yes  ipv4.dns "$COMBINED_IPV4"
    sudo nmcli connection modify "$UUID" ipv6.ignore-auto-dns yes  ipv6.dns "$COMBINED_IPV6"
  fi
done

# ---------- 6. Final Summary ----------
echo
log "✅ All done. Reconnect to any network to apply new DNS."
log "🔍 Check your resolver with:  resolvectl status"
log "Quick check:"
resolvectl status | grep -E "Current DNS Server|DNS Servers" || true