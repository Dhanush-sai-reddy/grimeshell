#!/usr/bin/env bash
# post-session.sh — Post-session hook called when an agent session ends
# Appends session summary to memory.md, validates knowledge, commits changes
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
MEMORY_FILE="${BRAIN_DIR}/knowledge/memory.md"
SYNC_SCRIPT="${BRAIN_DIR}/scripts/knowledge-sync.sh"

# ── Helpers ─────────────────────────────────────────────────────────────────
info() { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()   { echo -e "${GREEN}✓${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }

# ── Main ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}post-session${RESET} — Post-session cleanup hook

${BOLD}USAGE${RESET}
  post-session.sh [agent-name] [summary]

${BOLD}ARGUMENTS${RESET}
  agent-name    Name of the agent (default: \$AGENT_NAME or "unknown")
  summary       One-line session summary (default: "Session ended")

${BOLD}BEHAVIOR${RESET}
  1. Appends session entry to knowledge/memory.md
  2. Runs knowledge-sync.sh --check to validate knowledge graph
  3. Git add + commit knowledge/ changes

${BOLD}EXAMPLES${RESET}
  post-session.sh gemini "Fixed login bug and updated tests"
  post-session.sh claude "Refactored API routes"
  post-session.sh  # Uses defaults
EOF
}

main() {
    case "${1:-}" in
        --help|-h) show_help; exit 0 ;;
    esac

    local agent_name="${1:-${AGENT_NAME:-unknown}}"
    local summary="${2:-Session ended}"
    local date_str
    date_str=$(date '+%Y-%m-%d')
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${BOLD}📋 Post-Session Hook${RESET}"
    echo -e "${DIM}Agent: ${agent_name} | Time: ${timestamp}${RESET}"
    echo ""

    # 1. Append session entry to memory.md
    if [ -f "${MEMORY_FILE}" ]; then
        # Append to the session log table
        echo "| ${date_str} | ${agent_name} | ${summary} |" >> "${MEMORY_FILE}"
        ok "Session logged to memory.md"
    else
        warn "Memory file not found: ${MEMORY_FILE}"
    fi

    # 2. Run knowledge sync check
    if [ -x "${SYNC_SCRIPT}" ]; then
        info "Running knowledge validation..."
        "${SYNC_SCRIPT}" --check 2>/dev/null || warn "Knowledge sync reported issues"
    else
        info "knowledge-sync.sh not found — skipping validation"
    fi

    # 3. Git commit knowledge changes
    if git -C "${BRAIN_DIR}" rev-parse --is-inside-work-tree &>/dev/null; then
        local changes
        changes=$(git -C "${BRAIN_DIR}" diff --name-only -- knowledge/ 2>/dev/null || true)

        if [ -n "${changes}" ]; then
            git -C "${BRAIN_DIR}" add knowledge/
            git -C "${BRAIN_DIR}" commit -m "session: ${agent_name} — ${summary}" \
                -m "Auto-committed by post-session hook at ${timestamp}" \
                --no-verify 2>/dev/null && \
                ok "Knowledge changes committed" || \
                info "Nothing new to commit"
        else
            info "No knowledge changes to commit"
        fi
    else
        warn "Not a git repository — skipping commit"
    fi

    echo ""
    ok "${BOLD}Post-session cleanup complete${RESET}"
}

main "$@"
