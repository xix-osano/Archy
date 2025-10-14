#!/bin/bash
# ------------------------------------------------------------
# Snapshot creator — safely take a Btrfs snapshot before customization
# Author: Enosh, snapshot enthusiast
# ------------------------------------------------------------

set -euo pipefail

# === CONFIGURATION ==========================================
ROOT_SUBVOL="@"
HOME_SUBVOL="@home"
SNAPSHOT_DIR="/.snapshots"
TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
SNAP_NAME="PreArchySnap-$TIMESTAMP"
LOGFILE="/var/log/pre-customization-snapshot.log"
# =============================================================

# --- Log output to both screen and file ---
exec > >(tee -a "$LOGFILE") 2>&1

echo "🚀 Taking pre-customization snapshots at $TIMESTAMP..."
echo "------------------------------------------------------------"

# --- Check if on Btrfs ---
if ! findmnt -no FSTYPE / | grep -q "btrfs"; then
  echo "❌ This script only supports Btrfs filesystems."
  exit 1
fi

# --- Ensure snapshot directories exist ---
sudo mkdir -p "$SNAPSHOT_DIR/root" "$SNAPSHOT_DIR/home"

# --- Create snapshots ---
echo "📸 Creating root snapshot..."
sudo btrfs subvolume snapshot -r /"$ROOT_SUBVOL" "$SNAPSHOT_DIR/root/$SNAP_NAME"
echo "✅ Root snapshot created at: $SNAPSHOT_DIR/root/$SNAP_NAME"

if [[ -d /home ]]; then
  echo "📸 Creating home snapshot..."
  sudo btrfs subvolume snapshot -r /"$HOME_SUBVOL" "$SNAPSHOT_DIR/home/$SNAP_NAME"
  echo "✅ Home snapshot created at: $SNAPSHOT_DIR/home/$SNAP_NAME"
fi

# --- Log summary ---
echo "------------------------------------------------------------"
echo "[$(date)] Snapshots created successfully:"
echo "  🧩 Root → $SNAPSHOT_DIR/root/$SNAP_NAME"
echo "  🏠 Home → $SNAPSHOT_DIR/home/$SNAP_NAME"
echo "✨ Logged to: $LOGFILE"
echo
echo "🩵 To rollback later, you can run:"
echo "  sudo btrfs subvolume delete /@ && sudo btrfs subvolume snapshot $SNAPSHOT_DIR/root/$SNAP_NAME /@"
echo "------------------------------------------------------------"
echo "✅ All systems go — you may now safely run your customizations."

