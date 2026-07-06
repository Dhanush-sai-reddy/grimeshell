#!/usr/bin/env bash
# smell-check.sh — Run smell.sh on git staged files only
# Wrapper used by pre-commit hook and CI
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Constants ───────────────────────────────────────────────────────────────
BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMELL_SCRIPT="${BRAIN_DIR}/scripts/smell.sh"

# ── Helpers ─────────────────────────────────────────────────────────────────
info()  { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
err()   { echo -e "\033[0;31m✗\033[0m $*" >&2; }
die()   { err "$@"; exit 1; }

# ── Help ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}smell-check${RESET} — Run smell.sh on git staged files

${BOLD}USAGE${RESET}
  smell-check.sh [--all]

${BOLD}OPTIONS${RESET}
  --all     Check all tracked files (not just staged)
  --help    Show this help

${BOLD}SUPPORTED FILE TYPES${RESET}
  .sh, .bash, .js, .jsx, .ts, .tsx, .py, .json, .mjs

${BOLD}EXIT CODES${RESET}
  0    All files clean
  1    Warnings found
  2    Critical issues found
EOF
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    local check_all=false
    case "${1:-}" in
        --help|-h) show_help; exit 0 ;;
        --all) check_all=true ;;
    esac

    if [ ! -x "${SMELL_SCRIPT}" ]; then
        die "smell.sh not found or not executable at: ${SMELL_SCRIPT}"
    fi

    echo -e "${BOLD}🔍 Smell Check — Staged Files${RESET}"
    echo ""

    # Get file list
    local files
    if [ "${check_all}" = true ]; then
        info "Checking all tracked files..."
        files=$(git -C "${BRAIN_DIR}" ls-files -- \
            '*.sh' '*.bash' '*.js' '*.jsx' '*.ts' '*.tsx' '*.py' '*.json' '*.mjs' \
            2>/dev/null || true)
    else
        info "Checking staged files..."
        files=$(git -C "${BRAIN_DIR}" diff --cached --name-only --diff-filter=ACM -- \
            '*.sh' '*.bash' '*.js' '*.jsx' '*.ts' '*.tsx' '*.py' '*.json' '*.mjs' \
            2>/dev/null || true)
    fi

    if [ -z "${files}" ]; then
        ok "No matching files to check"
        exit 0
    fi

    local file_count
    file_count=$(echo "${files}" | wc -l)
    info "Found ${file_count} file(s) to check"
    echo ""

    local worst_exit=0
    while IFS= read -r file; do
        local full_path="${BRAIN_DIR}/${file}"
        if [ -f "${full_path}" ]; then
            "${SMELL_SCRIPT}" "${full_path}" 2>/dev/null || {
                local exit_code=$?
                if [ "${exit_code}" -gt "${worst_exit}" ]; then
                    worst_exit="${exit_code}"
                fi
            }
        fi
    done <<< "${files}"

    echo ""
    case "${worst_exit}" in
        0) ok "${BOLD}All staged files are clean${RESET}" ;;
        1) warn "${BOLD}Warnings found in staged files${RESET}" ;;
        2) err "${BOLD}Critical issues in staged files${RESET}" ;;
    esac

    exit "${worst_exit}"
}

main "$@"
