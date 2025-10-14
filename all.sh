#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Define Archy locations
export ARCHY_PATH="$HOME/.local/share/archy"
export ARCHY_INSTALL="$ARCHY_PATH/install"
export PATH="$ARCHY_PATH/bin:$PATH"

# Install
source "$ARCHY_INSTALL/preflight/all.sh"
source "$ARCHY_INSTALL/packaging/all.sh"
source "$ARCHY_INSTALL/login/all.sh"
source "$ARCHY_INSTALL/security/all.sh"
source "$ARCHY_INSTALL/postinstall/all.sh"