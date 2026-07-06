#!/usr/bin/env bash
# agent-launch.sh — Universal AI agent launcher
# Launches agents in dedicated tmux sessions with brain context loaded
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Constants ───────────────────────────────────────────────────────────────
BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_FILE="${BRAIN_DIR}/knowledge/memory.md"
AGENT_BASHRC="${BRAIN_DIR}/.agent_bashrc"
DRY_RUN=false

# ── Helpers ─────────────────────────────────────────────────────────────────
info()  { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
err()   { echo -e "${RED}✗${RESET} $*" >&2; }
die()   { err "$@"; exit 1; }

check_tmux() {
    if ! command -v tmux &>/dev/null; then
        die "tmux is not installed. Install with: paru -S tmux"
    fi
}

show_context_reminder() {
    echo ""
    echo -e "${BOLD}${CYAN}── Agent Context ─────────────────────────────────${RESET}"
    if [ -f "${MEMORY_FILE}" ]; then
        # Show current focus + last 5 non-empty content lines
        echo -e "${DIM}"
        grep -A1 "## Current Focus" "${MEMORY_FILE}" 2>/dev/null | tail -1 || true
        echo ""
        echo "Recent memory:"
        tail -10 "${MEMORY_FILE}" | grep -v '^$' | tail -5
        echo -e "${RESET}"
    else
        echo -e "  ${DIM}(no memory file found)${RESET}"
    fi
    echo -e "${BOLD}${CYAN}──────────────────────────────────────────────────${RESET}"
    echo ""
}

session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

source_agent_env() {
    if [ -f "${AGENT_BASHRC}" ]; then
        info "Loading agent environment from .agent_bashrc"
    fi
}

launch_session() {
    local session_name="$1"
    local agent_name="$2"
    local launch_cmd="${3:-}"

    check_tmux

    # Check if session already exists
    if session_exists "${session_name}"; then
        ok "Session '${session_name}' already exists — attaching"
        if [ "${DRY_RUN}" = true ]; then
            info "[DRY RUN] Would attach to tmux session: ${session_name}"
            return 0
        fi
        exec tmux attach-session -t "${session_name}"
    fi

    show_context_reminder

    if [ "${DRY_RUN}" = true ]; then
        info "[DRY RUN] Would create tmux session: ${session_name}"
        info "[DRY RUN] Agent: ${agent_name}"
        info "[DRY RUN] Working directory: ${BRAIN_DIR}"
        [ -n "${launch_cmd}" ] && info "[DRY RUN] Launch command: ${launch_cmd}"
        return 0
    fi

    info "Creating tmux session: ${BOLD}${session_name}${RESET}"

    # Build the init commands
    local init_cmds=""
    init_cmds+="export AGENT_NAME='${agent_name}'; "
    init_cmds+="export BRAIN_DIR='${BRAIN_DIR}'; "
    init_cmds+="export AGENT_SESSION='${session_name}'; "

    # Source agent bashrc if it exists
    if [ -f "${AGENT_BASHRC}" ]; then
        init_cmds+="source '${AGENT_BASHRC}'; "
    fi

    init_cmds+="echo ''; "
    init_cmds+="echo -e '${GREEN}✓ Agent session ready: ${BOLD}${agent_name}${RESET}'; "
    init_cmds+="echo -e '${DIM}  Brain: ${BRAIN_DIR}${RESET}'; "
    init_cmds+="echo -e '${DIM}  Session: ${session_name}${RESET}'; "
    init_cmds+="echo ''; "

    if [ -n "${launch_cmd}" ]; then
        init_cmds+="${launch_cmd}"
    fi

    # Create the tmux session
    tmux new-session -d -s "${session_name}" -c "${BRAIN_DIR}"
    tmux send-keys -t "${session_name}" "${init_cmds}" Enter

    ok "Session '${session_name}' created"

    # Attach to the session
    exec tmux attach-session -t "${session_name}"
}

run_post_session_hook() {
    local hook="${BRAIN_DIR}/hooks/post-session.sh"
    if [ -x "${hook}" ]; then
        info "Running post-session hook..."
        "${hook}" || warn "Post-session hook returned non-zero"
    fi
}

# ── Agent Launchers ─────────────────────────────────────────────────────────

launch_gemini() {
    launch_session "agent-gemini" "gemini" ""
}

launch_opencode() {
    if ! command -v opencode &>/dev/null; then
        die "opencode is not installed. Install from: https://github.com/opencode-ai/opencode"
    fi
    launch_session "agent-opencode" "opencode" "opencode"
}

launch_claude() {
    if ! command -v claude &>/dev/null; then
        die "claude CLI is not installed. Install from: https://docs.anthropic.com/en/docs/claude-cli"
    fi
    launch_session "agent-claude" "claude" "claude"
}

launch_custom() {
    local cmd="${1:-}"
    if [ -z "${cmd}" ]; then
        die "Custom command is required: agent-launch.sh custom <command>"
    fi
    local session_name
    # Sanitize command name for session name
    session_name="agent-$(echo "${cmd}" | tr ' /' '-' | cut -c1-20)"
    launch_session "${session_name}" "custom" "${cmd}"
}

# ── Help ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}agent-launch${RESET} — Universal AI agent launcher

${BOLD}USAGE${RESET}
  agent-launch.sh [--dry-run] <agent-type> [args]

${BOLD}AGENT TYPES${RESET}
  gemini           Launch Gemini (Antigravity) agent session
  opencode         Launch opencode CLI agent session
  claude           Launch Claude CLI agent session
  custom <cmd>     Launch any command as an agent session

${BOLD}OPTIONS${RESET}
  --dry-run        Show what would happen without creating sessions

${BOLD}EXAMPLES${RESET}
  agent-launch.sh gemini
  agent-launch.sh opencode
  agent-launch.sh claude
  agent-launch.sh custom "python3 my_agent.py"
  agent-launch.sh --dry-run gemini

${BOLD}BEHAVIOR${RESET}
  • Creates a tmux session named 'agent-<type>'
  • Sets AGENT_NAME, BRAIN_DIR, AGENT_SESSION env vars
  • Sources .agent_bashrc if present
  • Shows last 5 lines of knowledge/memory.md as context
  • If session already exists, attaches to it
  • Runs hooks/post-session.sh on session end (if executable)
EOF
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    # Parse flags
    while [[ "${1:-}" == --* ]]; do
        case "$1" in
            --dry-run) DRY_RUN=true; shift ;;
            --help|-h) show_help; exit 0 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    local agent_type="${1:-help}"
    shift || true

    case "${agent_type}" in
        gemini)   launch_gemini ;;
        opencode) launch_opencode ;;
        claude)   launch_claude ;;
        custom)   launch_custom "$@" ;;
        help|--help|-h) show_help ;;
        *)
            err "Unknown agent type: ${agent_type}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
