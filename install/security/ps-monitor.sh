#!/bin/bash
# =====================================================
# Arch Linux – Telegram Security & Performance Monitor
# Interactive setup (normal user, sudo for packages/services)
# =====================================================
set -euo pipefail

echo
cecho $BLUE "========================================================"
cecho $BLUE " Performance & Security Monitoring via Telegram"
cecho $BLUE "========================================================"
echo

CONFIG_DIR="$HOME/.config/arch-telegram-monitor"
mkdir -p "$CONFIG_DIR"

# -----------------------------------------
# 0. User inputs
# -----------------------------------------

echo "-------------------------------------------------"
echo " [Optional]Create telegram bot using @BotFather"
echo "--------------------------------------------------"
read -rp "Telegram Bot API token (leave empty to skip Telegram): " BOT_TOKEN
read -rp "Telegram Chat ID (leave empty to skip Telegram): " CHAT_ID

if [[ -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
    # Save env vars in user config
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
source "$HOME/.config/arch-telegram-monitor/env"
[[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]] && exit 1
curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
     -d chat_id="$CHAT_ID" -d parse_mode=markdown -d text="$*" >/dev/null
EOF

# -----------------------------------------
# Make telegram-send globally accessible
# -----------------------------------------
sudo ln -sf "$HELPER" /usr/local/bin/telegram-send
sudo chmod +x /usr/local/bin/telegram-send
echo "Now telegram-send is globally accessible. To use, run:"
echo " telegram-send <"Your message"> "

send_telegram() { "$HELPER" "$*"; }
send_telegram_file() {
    local file="$1" caption="$2"
    [[ ! -f "$file" ]] && return
    curl -sS -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
        -F chat_id="$CHAT_ID" \
        -F document=@"$file" \
        -F caption="$caption" >/dev/null
}

send_telegram "✅ Arch Telegram Monitor v3 started on $(hostname -f)"

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
read -rp "Install AIDE integrity check? (y/n): " INSTALL_AIDE
read -rp "Install Lynis + Logwatch weekly report? (y/n): " INSTALL_LYNIS

# -----------------------------------------
# 2. Install required packages
# -----------------------------------------
PKGS="arch-audit netdata jq"
[[ "$INSTALL_FAIL2BAN" == "y" ]] && PKGS+=" fail2ban inetutils"
[[ "$INSTALL_CLAMAV" == "y" ]] && PKGS+=" clamav"
[[ "$INSTALL_LYNIS" == "y" ]] && PKGS+=" lynis logwatch"

echo "Installing packages..."
sudo pacman -S --needed --noconfirm $PKGS

# -----------------------------------------
# 3. User systemd directory
# -----------------------------------------
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER_DIR"

# -----------------------------------------
# 4. arch-audit
# -----------------------------------------
if [[ "$ENABLE_AUDIT" == "y" ]]; then
    echo "Setting up arch-audit Telegram alerts..."
    systemctl --user enable --now arch-audit.timer 2>/dev/null || true
    cat > "$SYSTEMD_USER_DIR/arch-audit-telegram.service" <<EOF
[Unit]
Description=Push pending CVE list to Telegram
After=arch-audit.service

[Service]
Type=oneshot
ExecStart=$HELPER "🛡️ *$(hostname)* CVE pending: $(arch-audit -q | wc -l)"
EOF
fi

# -----------------------------------------
# 5. Netdata
# -----------------------------------------
if [[ "$ENABLE_NETDATA" == "y" ]]; then
    NETDATA_CONF="/etc/netdata/health_alarm_notify.conf"

    # Ensure /etc/netdata exists
    sudo mkdir -p /etc/netdata

    # Copy default if missing
    if [[ ! -f "$NETDATA_CONF" ]]; then
        sudo cp /usr/lib/netdata/conf.d/health_alarm_notify.conf "$NETDATA_CONF"
    fi

    # Backup original
    sudo cp -a "$NETDATA_CONF"{,.bak}

    sudo bash -c "cat >> $NETDATA_CONF" <<EOF

# --- injected by arch-telegram-monitor v3 ---
SEND_TELEGRAM="YES"
TELEGRAM_BOT_TOKEN="$BOT_TOKEN"
DEFAULT_RECIPIENT_TELEGRAM="$CHAT_ID"
EOF
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
ExecStart=/usr/local/bin/telegram-send "📊 *$(hostname)* daily health"
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
    mkdir -p "$HOME/.config/pacman/hooks"
    cat > "$HOME/.config/pacman/hooks/99-upgrade-report.hook" <<EOF
[Trigger]
Operation = Upgrade
Type = Package
Target = *
[Action]
Description = Notify Telegram after upgrade
When = PostTransaction
Exec = $HELPER "✅ Pacman upgraded \$(pacman -Qqu | wc -l) packages on *\$(hostname)*"
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
ExecStart=/usr/bin/clamscan -r / --exclude-dir=/proc --exclude-dir=/sys --exclude-dir=/dev --exclude-dir=/run | /usr/local/bin/telegram-send "ClamAV scan result"
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
# 10. AIDE - File Integrity & Intrusion Detection
# -----------------------------------------
if [[ "$INSTALL_AIDE" == "y" ]]; then
    yay -S --noconfirm aide
    cat > "$SYSTEMD_USER_DIR/daily-aide-telegram.service" <<EOF
[Unit]
Description=AIDE daily integrity check

[Service]
Type=oneshot
ExecStart=/usr/bin/aide --check | /usr/local/bin/telegram-send "🛡️ *$(hostname)* AIDE integrity check result"
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
# 11. Lynis + Logwatch weekly report
# -----------------------------------------
if [[ "$INSTALL_LYNIS" == "y" ]]; then
    cat > "$SYSTEMD_USER_DIR/weekly-lynis-telegram.service" <<EOF
[Unit]
Description=Lynis & Logwatch weekly security report

[Service]
Type=oneshot
ExecStart=/bin/bash -c '/usr/bin/lynis audit system --quiet --no-colors | /usr/local/bin/telegram-send "🛡️ *$(hostname)* Lynis weekly report"; /usr/sbin/logwatch --output stdout --range today | /usr/local/bin/telegram-send "📄 *$(hostname)* Logwatch daily report"'
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

echo "========================================================"
echo "✅ Setup complete. Review $CONFIG_DIR for configurations."
echo "Note: All timers are user-level. Ensure 'systemctl --user' is enabled."
echo "========================================================"
