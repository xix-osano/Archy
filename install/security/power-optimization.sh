#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing power management tools..."
sudo pacman -S --needed --noconfirm tlp powertop lm_sensors acpi tlp-rdw

echo "==> Enabling and starting TLP service..."
sudo systemctl enable --now tlp

echo "==> Checking ACPI and battery info..."
acpi || echo "ACPI command failed — ensure it's installed properly."
if upower -e | grep -q "BAT"; then
  upower -i "$(upower -e | grep BAT)"
else
  echo "No battery detected via upower."
fi

#Backup Tlp before editing
if [[ -f /etc/tlp.conf ]]; then
  sudo cp /etc/tlp.conf "/etc/tlp.conf.bak"
  echo "Backed up /etc/tlp.conf to /etc/tlp.conf.bak"
else
  echo "No existing /etc/tlp.conf found; skipping backup."
fi

echo "==> Configuring TLP..."
sudo bash -c 'cat > /etc/tlp.conf <<EOF
TLP_ENABLE=1

# CPU scaling
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# Energy performance hints
CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=balance_power

# AMD Ryzen boost control
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Platform profiles
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power

# Disk devices
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"

# SATA link power management
SATA_LINKPWR_ON_AC=med_power_with_dipm
SATA_LINKPWR_ON_BAT=min_power

# GPU power management (for integrated Vega GPU)
RADEON_DPM_PERF_LEVEL_ON_AC=auto
RADEON_DPM_PERF_LEVEL_ON_BAT=low

# WiFi powersave
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# PCIe power saving
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersave

# Runtime power management
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto

# USB autosuspend
USB_AUTOSUSPEND=1
EOF'

echo "==> Restarting TLP to apply settings..."
sudo systemctl restart tlp

echo "==> TLP status summary:"
tlp-stat -s
sudo tlp-stat -b

echo "==> Creating Powertop auto-tune systemd service..."
sudo bash -c 'cat > /etc/systemd/system/powertop.service <<EOF
[Unit]
Description=Powertop tunings
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/powertop --auto-tune

[Install]
WantedBy=multi-user.target
EOF'

echo "==> Enabling Powertop service..."
sudo systemctl enable powertop.service

echo "✅ Power optimization setup complete!"
echo "You can now reboot or run 'sudo systemctl start powertop.service' to apply Powertop tunings."
