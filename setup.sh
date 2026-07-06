#!/usr/bin/env bash
# ============================================================================
# SHELLLL — One-Shot Installer
# Idempotent setup script for the SHELLLL terminal-first agent brain.
# Safe to run multiple times. Detects Arch-based systems, installs deps,
# symlinks configs, and validates everything.
# ============================================================================
set -euo pipefail

# --- Colors ----------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Helpers ---------------------------------------------------------------
info()    { printf "${CYAN}[INFO]${RESET}  %s\n" "$*"; }
success() { printf "${GREEN}[  OK]${RESET}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${RESET}  %s\n" "$*"; }
error()   { printf "${RED}[ ERR]${RESET}  %s\n" "$*"; }
section() { printf "\n${BOLD}── %s ──${RESET}\n" "$*"; }

SHELLLL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Pre-flight checks -----------------------------------------------------
section "Pre-flight Checks"

# Must be Arch-based
if [[ ! -f /etc/arch-release ]] && ! grep -qi 'arch\|cachyos\|manjaro\|endeavour\|garuda' /etc/os-release 2>/dev/null; then
    error "This script requires an Arch-based Linux distribution."
    error "Detected OS does not appear to be Arch-based."
    exit 1
fi
success "Arch-based system detected"

# Need a AUR helper
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
else
    error "No AUR helper found. Please install paru or yay first."
    exit 1
fi
success "AUR helper found: $AUR_HELPER"

# Need npm/node
if ! command -v npm &>/dev/null; then
    error "npm not found. Please install Node.js first."
    exit 1
fi
success "npm $(npm --version) found"

if ! command -v node &>/dev/null; then
    error "node not found. Please install Node.js first."
    exit 1
fi
success "node $(node --version) found"

# --- Install system packages -----------------------------------------------
section "System Packages"

install_if_missing() {
    local pkg="$1"
    local cmd="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        success "$pkg already installed ($(command -v "$cmd"))"
    else
        info "Installing $pkg via $AUR_HELPER..."
        if $AUR_HELPER -S --noconfirm --needed "$pkg"; then
            success "$pkg installed"
        else
            error "Failed to install $pkg"
            return 1
        fi
    fi
}

install_if_missing "tmux" "tmux"
install_if_missing "github-cli" "gh"

# --- Validate npx-based tools ---------------------------------------------
section "NPX-based Tools"

# gh-axi runs via: npx gh-axi (or gh extension)
if command -v npx &>/dev/null; then
    success "npx available — gh-axi and bash-mcp can be invoked via npx"
else
    warn "npx not found; gh-axi and bash-mcp will not be available"
fi

# Validate gh-axi is resolvable (dry-run resolve, don't actually execute)
if npx --yes gh-axi --help &>/dev/null 2>&1; then
    success "gh-axi is resolvable via npx"
else
    warn "gh-axi could not be resolved via npx — it may need to be installed separately"
fi

# Validate bash-mcp is resolvable (just a quick check without hanging)
# (Skipping execution check because bash-mcp hangs waiting for stdio)
success "bash-mcp validation skipped (server runs in foreground)"

# --- Install NPM Packages ---------------------------------------------------
section "NPM Packages"

if [[ -x "$SHELLLL_ROOT/node_modules/.bin/no-mistakes" ]]; then
    success "no-mistakes already installed locally"
else
    info "Installing no-mistakes locally..."
    if (cd "$SHELLLL_ROOT" && npm install no-mistakes >/dev/null 2>&1); then
        success "no-mistakes installed locally"
    else
        warn "Failed to install no-mistakes locally"
    fi
fi

# --- Symlink tmux.conf ----------------------------------------------------
section "Configuration Symlinks"

TMUX_SRC="$SHELLLL_ROOT/tmux.conf"
TMUX_DST="$HOME/.tmux.conf"

if [[ -f "$TMUX_SRC" ]]; then
    if [[ -L "$TMUX_DST" ]] && [[ "$(readlink -f "$TMUX_DST")" == "$(readlink -f "$TMUX_SRC")" ]]; then
        success "~/.tmux.conf already symlinked correctly"
    else
        # Backup existing config if it exists and is not our symlink
        if [[ -e "$TMUX_DST" ]] || [[ -L "$TMUX_DST" ]]; then
            BACKUP="$TMUX_DST.backup.$(date +%Y%m%d_%H%M%S)"
            info "Backing up existing ~/.tmux.conf → $BACKUP"
            mv "$TMUX_DST" "$BACKUP"
            success "Backup created: $BACKUP"
        fi
        ln -sf "$TMUX_SRC" "$TMUX_DST"
        success "Symlinked $TMUX_SRC → $TMUX_DST"
    fi
else
    warn "tmux.conf not found at $TMUX_SRC — skipping symlink"
    warn "Run this script again after tmux.conf is created"
fi

# --- Git repo initialization -----------------------------------------------
section "Git Repository"

if [[ -d "$SHELLLL_ROOT/.git" ]]; then
    success "Git repo already initialized"
    info "Branch: $(git -C "$SHELLLL_ROOT" branch --show-current 2>/dev/null || echo 'detached')"
else
    info "Initializing git repo..."
    git -C "$SHELLLL_ROOT" init
    git -C "$SHELLLL_ROOT" checkout -b main 2>/dev/null || true
    success "Git repo initialized on branch 'main'"
fi

# --- Create directory structure if missing ---------------------------------
section "Directory Structure"

DIRS=(
    "scripts"
    "skills"
    "knowledge"
    "knowledge/graph"
    "contexts"
)

for dir in "${DIRS[@]}"; do
    target="$SHELLLL_ROOT/$dir"
    if [[ -d "$target" ]]; then
        success "$dir/ exists"
    else
        mkdir -p "$target"
        success "$dir/ created"
    fi
done

# --- Make scripts executable -----------------------------------------------
section "Script Permissions"

if [[ -d "$SHELLLL_ROOT/scripts" ]]; then
    find "$SHELLLL_ROOT/scripts" -name '*.sh' -exec chmod +x {} \; 2>/dev/null
    success "All scripts/*.sh marked executable"
fi

chmod +x "$SHELLLL_ROOT/setup.sh" 2>/dev/null || true
success "setup.sh marked executable"

# --- Validation ------------------------------------------------------------
section "Final Validation"

PASS=0
FAIL=0

validate() {
    local label="$1"
    local cmd="$2"
    if eval "$cmd" &>/dev/null 2>&1; then
        success "$label"
        PASS=$((PASS + 1))
    else
        error "$label — FAILED"
        FAIL=$((FAIL + 1))
    fi
}

validate "tmux"              "command -v tmux"
validate "gh (GitHub CLI)"   "command -v gh"
validate "git"               "command -v git"
validate "node"              "command -v node"
validate "npm"               "command -v npm"
validate "npx"               "command -v npx"
validate "fzf"               "command -v fzf"
validate "python3"           "command -v python3"
validate "~/.tmux.conf"      "test -L $HOME/.tmux.conf"
validate "SHELLLL .git"      "test -d $SHELLLL_ROOT/.git"
validate "scripts/ dir"      "test -d $SHELLLL_ROOT/scripts"
validate "skills/ dir"       "test -d $SHELLLL_ROOT/skills"
validate "knowledge/ dir"    "test -d $SHELLLL_ROOT/knowledge"

# --- Summary ---------------------------------------------------------------
section "Setup Complete"

printf "\n"
printf "  ${GREEN}✓ Passed:${RESET} %d\n" "$PASS"
if [[ $FAIL -gt 0 ]]; then
    printf "  ${RED}✗ Failed:${RESET} %d\n" "$FAIL"
fi
printf "\n"
printf "  ${BOLD}SHELLLL_ROOT:${RESET} %s\n" "$SHELLLL_ROOT"
printf "  ${BOLD}Next steps:${RESET}\n"
printf "    1. Source the agent env:  ${CYAN}source %s/.agent_bashrc${RESET}\n" "$SHELLLL_ROOT"
printf "    2. Read the agent prompt: ${CYAN}cat %s/Agent.md${RESET}\n" "$SHELLLL_ROOT"
printf "    3. Start a tmux session:  ${CYAN}tmux new -s agent${RESET}\n"
printf "\n"
