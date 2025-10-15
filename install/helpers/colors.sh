# -----------------------------------------
# Color codes
# -----------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# -----------------------------------------
# Colored echo function
# -----------------------------------------
cecho() {
    local color="$1"; shift
    echo -e "${color}$*${RESET}"
}

# Usage:
# cecho $GREEN "✅ Packages installed successfully"
# cecho $YELLOW "⚠️ Warning: something may be off"
# cecho $RED "❌ Failed!"
