#!/usr/bin/env bash
# ===================================================
#  Git Credential Setup Script
#  Author: Enosh
# ===================================================

set -euo pipefail

cecho $BLUE "==============================================="
cecho $BLUE "        Git Credential Setup Utility"
cecho $BLUE "==============================================="

# --- Step 0: Inputs -----------------------------------------------------------
read -rp "Git username: " GIT_NAME
read -rp "Git email: " GIT_EMAIL

# Optional credential cache duration (default: 15 minutes)
read -rp "Cache credentials for how many minutes? [default 15]: " CACHE_MIN
CACHE_MIN=${CACHE_MIN:-15}

# --- Step 1: Configure global git identity ------------------------------------
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

cecho $GREEN "✅ Git identity configured: $GIT_NAME <$GIT_EMAIL>"

# --- Step 2: Enable credential caching ----------------------------------------
# git config --global credential.helper "cache --timeout=$((CACHE_MIN * 60))"
# echo "🔐 Credentials will be cached for $CACHE_MIN minutes."

# --- Step 3: Setup default branch name ----------------------------------------
git config --global init.defaultBranch main
cecho $GREEN "🌿 Default branch set to 'main'."

# --- Step 4: Optional SSH configuration ---------------------------------------
# read -rp "Do you want to set up SSH keys for GitHub/GitLab? (y/n): " SSH_SETUP
# if [[ "$SSH_SETUP" =~ ^[Yy]$ ]]; then
#   SSH_DIR="$HOME/.ssh"
#   mkdir -p "$SSH_DIR"
#   chmod 700 "$SSH_DIR"

#   if [[ ! -f "$SSH_DIR/id_ed25519" ]]; then
#     echo "🔑 Generating SSH key..."
#     ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_DIR/id_ed25519" -N ""
#   else
#     echo "ℹ️ SSH key already exists at $SSH_DIR/id_ed25519"
#   fi

#   eval "$(ssh-agent -s)"
#   ssh-add "$SSH_DIR/id_ed25519"

#   echo "📋 Public key:"
#   echo "-----------------------------------------------"
#   cat "$SSH_DIR/id_ed25519.pub"
#   echo "-----------------------------------------------"
#   echo "Copy this key to your GitHub/GitLab SSH settings:"
#   echo "  🔗 GitHub: https://github.com/settings/keys"
#   echo "  🔗 GitLab: https://gitlab.com/-/profile/keys"
# fi

# --- Step 5: Display summary --------------------------------------------------
echo
cecho $GREEN "==============================================="
cecho $GREEN "  Git configuration complete 🎉"
cecho $GREEN "==============================================="
git config --global --list
