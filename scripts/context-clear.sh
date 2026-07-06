#!/usr/bin/env bash
# context-clear.sh — Reset agent memory to clean state
# Backs up current memory, resets to template (preserving user preferences)
# Equivalent to /clear
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Constants ───────────────────────────────────────────────────────────────
BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_FILE="${BRAIN_DIR}/knowledge/memory.md"
ARCHIVE_DIR="${BRAIN_DIR}/knowledge/archive"

# ── Helpers ─────────────────────────────────────────────────────────────────
info()  { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
err()   { echo -e "${RED}✗${RESET} $*" >&2; }
die()   { err "$@"; exit 1; }

# ── Main ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}context-clear${RESET} — Reset agent memory to clean state

${BOLD}USAGE${RESET}
  context-clear.sh [--force]

${BOLD}OPTIONS${RESET}
  --force    Skip confirmation prompt
  --help     Show this help

${BOLD}BEHAVIOR${RESET}
  1. Backs up current memory.md to knowledge/archive/memory_TIMESTAMP.md
  2. Extracts User Preferences section from current memory
  3. Resets memory.md with clean template + preserved preferences
  4. Prints confirmation

${BOLD}NOTE${RESET}
  Session log, open tasks, and current focus are cleared.
  User preferences are preserved across resets.
EOF
}

extract_preferences() {
    local file="$1"
    if [ ! -f "${file}" ]; then
        echo "- (no preferences found — populate manually)"
        return
    fi

    # Extract everything between "## User Preferences" and the next "##"
    awk '/^## User Preferences/{found=1; next} /^## /{if(found) exit} found{print}' "${file}"
}

main() {
    local force=false
    case "${1:-}" in
        --help|-h) show_help; exit 0 ;;
        --force) force=true ;;
    esac

    if [ ! -f "${MEMORY_FILE}" ]; then
        die "Memory file not found: ${MEMORY_FILE}"
    fi

    # Confirm unless --force
    if [ "${force}" != true ]; then
        warn "This will clear the agent memory (session log, tasks, focus)."
        echo -e "  User preferences will be preserved."
        echo -e "  Current memory will be backed up to knowledge/archive/."
        echo ""
        echo -n "  Continue? [y/N] "
        read -r confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
            info "Aborted"
            exit 0
        fi
    fi

    # Create archive directory
    mkdir -p "${ARCHIVE_DIR}"

    # Backup current memory
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="${ARCHIVE_DIR}/memory_${timestamp}.md"
    cp "${MEMORY_FILE}" "${backup_file}"
    ok "Backed up memory to: ${backup_file}"

    # Extract user preferences
    local preferences
    preferences=$(extract_preferences "${MEMORY_FILE}")

    # Write clean template
    cat > "${MEMORY_FILE}" <<TEMPLATE
# Agent Memory

## Current Focus
(No active focus — set one to guide agent behavior)

## User Preferences
${preferences}

## Recent Decisions
(Cleared on ${timestamp} — see archive for history)

## Open Tasks
- [ ] Review archived memory for any incomplete work

## Session Log
| Date | Agent | Summary |
|------|-------|---------|
| $(date '+%Y-%m-%d') | system | Memory cleared (archive: memory_${timestamp}.md) |
TEMPLATE

    ok "Memory reset to clean template"
    info "Preferences preserved ($(echo "${preferences}" | wc -l) lines)"
    info "Archive: ${DIM}${backup_file}${RESET}"
}

main "$@"
