#!/bin/bash
# =====================================================
# Arch Linux – Telegram Security & Performance Monitor
# Interactive setup (normal user, sudo for packages/services)
# =====================================================
set -euo pipefail

# --- Basic Colors ---
#BLUE="\e[34m"; GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; RESET="\e[0m"
#cecho() { echo -e "${1}${2}${RESET}"; }

cecho "$BLUE" "========================================================"
cecho "$BLUE" " Performance & Security Monitoring via Telegram"
cecho "$BLUE" "========================================================"
echo

CONFIG_DIR="$HOME/.config/arch-telegram-monitor"
mkdir -p "$CONFIG_DIR"

# --- Optional: Status Mode ---
if [[ "${1:-}" == "--status" ]]; then
  cecho "$BLUE" "Arch Telegram Monitor Status on $(hostname)"
  echo
  echo "Telegram credentials: $( [[ -f $CONFIG_DIR/env ]] && echo OK || echo MISSING )"
  echo
  echo "Active user timers:"
  systemctl --user list-timers --no-pager --no-legend | awk '{print " • "$1}'
  echo
  exit 0
fi

# -----------------------------------------
# 0. User inputs
# -----------------------------------------
echo "-------------------------------------------------"
echo " [Optional] Create a Telegram bot using @BotFather"
echo "-------------------------------------------------"
read -rp "Telegram Bot API token (leave empty to skip Telegram): " BOT_TOKEN
read -rp "Telegram Chat ID (leave empty to skip Telegram): " CHAT_ID

if [[ -n "${BOT_TOKEN:-}" && -n "${CHAT_ID:-}" ]]; then
    echo "Saving Telegram credentials to $CONFIG_DIR/env"
    cat > "$CONFIG_DIR/env" <<EOF
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOF
fi

# -----------------------------------------
# Telegram helper
# -----------------------------------------
HELPER="$CONFIG_DIR/telegram-send"
cat > "$HELPER" <<'EOF'
#!/bin/bash
set -euo pipefail
CONFIG="$HOME/.config/arch-telegram-monitor/env"
[[ -f "$CONFIG" ]] && source "$CONFIG" || exit 0
[[ -z "${BOT_TOKEN:-}" || -z "${CHAT_ID:-}" ]] && exit 0
MSG="$*"
curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
     -d chat_id="$CHAT_ID" -d parse_mode=markdown -d text="$MSG" >/dev/null
EOF
chmod +x "$HELPER"

# Make globally accessible
cecho "$BLUE" "Linking telegram-send to /usr/local/bin"
sudo ln -sf "$HELPER" /usr/local/bin/telegram-send
sudo chmod +x /usr/local/bin/telegram-send
cecho "$GREEN" "telegram-send is now available globally."

send_telegram() { "$HELPER" "$*"; }

# -----------------------------------------
# 1. Interactive module selection
# -----------------------------------------
read -rp "Enable arch-audit CVE alerts? (y/n) [y]: " ENABLE_AUDIT
ENABLE_AUDIT=${ENABLE_AUDIT:-y}

read -rp "Enable Netdata Telegram alerts? (y/n) [y]: " ENABLE_NETDATA
ENABLE_NETDATA=${ENABLE_NETDATA:-y}

read -rp "Enable daily health digest? (y/n) [y]: " ENABLE_HEALTH
ENABLE_HEALTH=${ENABLE_HEALTH:-y}

read -rp "Enable Pacman post-transaction hook? (y/n) [y]: " ENABLE_PACMAN
ENABLE_PACMAN=${ENABLE_PACMAN:-y}

read -rp "Install Fail2Ban? (y/n): " INSTALL_FAIL2BAN
read -rp "Install ClamAV daily scan? (y/n): " INSTALL_CLAMAV
read -rp "Install AIDE integrity check (AUR)? (y/n): " INSTALL_AIDE
read -rp "Install Lynis + Logwatch weekly report? (y/n): " INSTALL_LYNIS

# -----------------------------------------
# 2. Install required packages
# -----------------------------------------
PKGS=(arch-audit netdata jq)
[[ "$INSTALL_FAIL2BAN" == "y" ]] && PKGS+=(fail2ban inetutils)
[[ "$INSTALL_CLAMAV" == "y" ]] && PKGS+=(clamav)
[[ "$INSTALL_LYNIS" == "y" ]] && PKGS+=(lynis logwatch)

echo "Installing packages..."
sudo pacman -S --needed --noconfirm "${PKGS[@]}"

# AIDE via AUR
if [[ "$INSTALL_AIDE" == "y" ]]; then
    if command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm aide
    elif command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm aide
    else
        cecho "$RED" "No AUR helper found (yay/paru). Skipping AIDE."
    fi
fi

# -----------------------------------------
# 3. User systemd directory
# -----------------------------------------
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"
loginctl enable-linger "$USER" || true

# -----------------------------------------
# 4. arch-audit
# -----------------------------------------
if [[ "$ENABLE_AUDIT" == "y" ]]; then
    echo "Setting up arch-audit Telegram alerts..."
    cat > "$SYSTEMD_USER_DIR/arch-audit-telegram.service" <<EOF
[Unit]
Description=Push pending CVE list to Telegram

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/local/bin/telegram-send "🛡️ *${HOSTNAME}* CVE pending: \$(arch-audit -q | wc -l)"'
EOF

    cat > "$SYSTEMD_USER_DIR/arch-audit-telegram.timer" <<EOF
[Unit]
Description=Daily CVE check via arch-audit

[Timer]
OnCalendar=*-*-* 08:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now arch-audit-telegram.timer
fi

# -----------------------------------------
# 5. Netdata
# -----------------------------------------
if [[ "$ENABLE_NETDATA" == "y" ]]; then
    NETDATA_CONF="/etc/netdata/health_alarm_notify.conf"
    sudo mkdir -p /etc/netdata

    if [[ ! -f "$NETDATA_CONF" ]]; then
        sudo cp /usr/lib/netdata/conf.d/health_alarm_notify.conf "$NETDATA_CONF"
    fi

    if ! grep -q "SEND_TELEGRAM" "$NETDATA_CONF" 2>/dev/null; then
        sudo tee -a "$NETDATA_CONF" >/dev/null <<EOF
# --- injected by arch-telegram-monitor ---
SEND_TELEGRAM="YES"
TELEGRAM_BOT_TOKEN="${BOT_TOKEN:-}"
DEFAULT_RECIPIENT_TELEGRAM="${CHAT_ID:-}"
EOF
    fi

    sudo systemctl enable --now netdata
    sudo systemctl restart netdata
fi

# -----------------------------------------
# 6. Daily health digest
# -----------------------------------------
if [[ "$ENABLE_HEALTH" == "y" ]]; then
    cat > "$SYSTEMD_USER_DIR/daily-health-telegram.service" <<EOF
[Unit]
Description=Daily health digest to Telegram

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/local/bin/telegram-send "📊 *${HOSTNAME}* daily health — \$(date -Iminutes)"'
EOF

    cat > "$SYSTEMD_USER_DIR/daily-health-telegram.timer" <<EOF
[Unit]
Description=Run daily-health-telegram.service daily

[Timer]
OnCalendar=*-*-* 07:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now daily-health-telegram.timer
fi

# -----------------------------------------
# 7. Pacman post-transaction hook
# -----------------------------------------
if [[ "$ENABLE_PACMAN" == "y" ]]; then
    sudo mkdir -p /etc/pacman.d/hooks
    sudo tee /etc/pacman.d/hooks/99-upgrade-report.hook >/dev/null <<EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = *
[Action]
Description = Notify Telegram after upgrade
When = PostTransaction
Exec = /bin/bash -c '/usr/local/bin/telegram-send "✅ Pacman upgraded \$(pacman -Qqu | wc -l) packages on *${HOSTNAME}*"'
EOF
fi

# -----------------------------------------
# 8. Fail2Ban
# -----------------------------------------
if [[ "$INSTALL_FAIL2BAN" == "y" ]]; then
    sudo tee /etc/fail2ban/action.d/telegram.conf > /dev/null <<EOF
[Definition]
actionban = curl -sS -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage -d chat_id=${CHAT_ID} -d text="🚫 Fail2Ban: <ip> banned on <name>"
actionunban = curl -sS -X POST https://api.telegram.org/bot${BOT_TOKEN}/sendMessage -d chat_id=${CHAT_ID} -d text="✅ Fail2Ban: <ip> unbanned"
EOF

    sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5
backend  = systemd
action   = telegram[name=%(__name__)s]

[sshd]
enabled  = true
maxretry = 3
EOF
    sudo systemctl enable --now fail2ban
    send_telegram "🛡️ Fail2Ban active (Telegram alerts)"
fi

# -----------------------------------------
# 9. ClamAV daily scan
# -----------------------------------------
if [[ "$INSTALL_CLAMAV" == "y" ]]; then
    sudo freshclam
    cat > "$SYSTEMD_USER_DIR/daily-clamscan.service" <<EOF
[Unit]
Description=ClamAV daily scan

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/clamscan -r / --exclude-dir=/proc --exclude-dir=/sys --exclude-dir=/dev --exclude-dir=/run | /usr/local/bin/telegram-send "ClamAV scan result"'
EOF

    cat > "$SYSTEMD_USER_DIR/daily-clamscan.timer" <<EOF
[Unit]
Description=Run daily ClamAV scan

[Timer]
OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now daily-clamscan.timer
fi

# -----------------------------------------
# 10. AIDE integrity check
# -----------------------------------------
if [[ "$INSTALL_AIDE" == "y" ]]; then
    sudo aide --init || true
    sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db || true

    cat > "$SYSTEMD_USER_DIR/daily-aide-telegram.service" <<EOF
[Unit]
Description=AIDE daily integrity check

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/aide --check | /usr/local/bin/telegram-send "🛡️ *${HOSTNAME}* AIDE integrity check result"'
EOF

    cat > "$SYSTEMD_USER_DIR/daily-aide-telegram.timer" <<EOF
[Unit]
Description=Run daily AIDE check

[Timer]
OnCalendar=*-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now daily-aide-telegram.timer
fi

# -----------------------------------------
# 11. Lynis + Logwatch
# -----------------------------------------
if [[ "$INSTALL_LYNIS" == "y" ]]; then
    cat > "$SYSTEMD_USER_DIR/weekly-lynis-telegram.service" <<EOF
[Unit]
Description=Lynis & Logwatch weekly security report

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/lynis audit system --quiet --no-colors | /usr/local/bin/telegram-send "🛡️ *${HOSTNAME}* Lynis weekly report"; /usr/sbin/logwatch --output stdout --range today | /usr/local/bin/telegram-send "📄 *${HOSTNAME}* Logwatch daily report"'
EOF

    cat > "$SYSTEMD_USER_DIR/weekly-lynis-telegram.timer" <<EOF
[Unit]
Description=Run weekly Lynis & Logwatch report

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now weekly-lynis-telegram.timer
fi

# -----------------------------------------
# 12. Finalization
# -----------------------------------------
send_telegram "🎉 Arch Telegram Monitor setup complete on $(hostname)"

cecho "$GREEN" "========================================================"
cecho "$GREEN" "✅ Setup complete. Review $CONFIG_DIR for configurations."
cecho "$YELLOW" "Use: systemctl --user list-timers   → Verify active jobs"
cecho "$YELLOW" "Check: sudo systemctl status fail2ban netdata"
cecho "$GREEN" "========================================================"
