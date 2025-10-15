#!/usr/bin/env bash

echo "============================================"
echo "     Archy Linux Global Executables Setup"
echo "============================================"
echo

set -e

ARCHY_DIR="/home/enosh/.local/share/archy/bin"

echo "[INFO] Setting up Archy utilities..."

# Ensure directory exists
if [ ! -d "$ARCHY_DIR" ]; then
    echo "[ERROR] $ARCHY_DIR does not exist. Please clone Archy first."
    exit 1
fi

# Make scripts executable
echo "[INFO] Making Archy scripts executable..."
chmod +x "$ARCHY_DIR"/*

# Link scripts into /usr/local/bin
echo "[INFO] Linking scripts to /usr/local/bin..."
for script in "$ARCHY_DIR"/*; do
    name=$(basename "$script")
    if [ ! -f "/usr/local/bin/$name" ]; then
        sudo ln -s "$script" "/usr/local/bin/$name"
        echo "[OK] Linked $name → /usr/local/bin/$name"
    else
        echo "[SKIP] /usr/local/bin/$name already exists."
    fi
done

echo "[SUCCESS] Archy utilities are now globally available."

