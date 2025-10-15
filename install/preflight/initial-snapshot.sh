#!/bin/bash
# ------------------------------------------------------------
# Snapper-based snapshot creator — automated, safe, and traceable
# Author: Enosh
# ------------------------------------------------------------

set -euo pipefail

SNAPPER_ROOT_CONFIG="root"
SNAPPER_HOME_CONFIG="home"
LOGFILE="$HOME/pre-customization-snapshot.log"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
COMMENT="PreArchy snapshot $TIMESTAMP"

cecho $BLUE "=============================================="
cecho $BLUE "     Archy Linux Pre-customization Snapshot"
cecho $BLUE "=============================================="
echo "🚀 Taking Snapper snapshots at $TIMESTAMP..."
echo "------------------------------------------------------------"

# --- Check if snapper exists ---
if ! command -v snapper &>/dev/null; then
  echo "⚙️ Installing snapper..."
  sudo pacman -S --noconfirm snapper
fi

# --- Ensure configs exist ---
if ! sudo snapper list-configs | grep -q "$SNAPPER_ROOT_CONFIG"; then
  echo "⚙️ Creating Snapper config for root..."
  sudo snapper -c "$SNAPPER_ROOT_CONFIG" create-config /
fi

if [[ -d /home ]] && ! sudo snapper list-configs | grep -q "$SNAPPER_HOME_CONFIG"; then
  echo "⚙️ Creating Snapper config for home..."
  sudo snapper -c "$SNAPPER_HOME_CONFIG" create-config /home
fi

# --- Create snapshots ---
echo "📸 Creating root snapshot..."
sudo snapper -c "$SNAPPER_ROOT_CONFIG" create -t pre -p -d "$COMMENT"

if [[ -d /home ]]; then
  echo "📸 Creating home snapshot..."
  sudo snapper -c "$SNAPPER_HOME_CONFIG" create -t pre -p -d "$COMMENT"
fi

echo "✅ Snapshots created successfully!"
echo "🧾 Log: $LOGFILE"
echo "------------------------------------------------------------"
echo "✨ To list snapshots:"
echo "  sudo snapper -c root list"
echo "  sudo snapper -c home list"
echo
echo "🧩 To rollback if needed:"
echo "  sudo snapper -c root undochange <from-snap>..<to-snap>"
echo "  sudo snapper -c home undochange <from-snap>..<to-snap>"
echo "------------------------------------------------------------"

