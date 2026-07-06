#!/usr/bin/env bash
# context-compact.sh — Generate compact context summary for agent catch-up
# Equivalent to /compact — agents read this to quickly regain context
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Constants ───────────────────────────────────────────────────────────────
BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_FILE="${BRAIN_DIR}/knowledge/memory.md"
ENTITIES_FILE="${BRAIN_DIR}/knowledge/graph/entities.json"
RELATIONS_FILE="${BRAIN_DIR}/knowledge/graph/relations.json"
PROJECT_MAP="${BRAIN_DIR}/knowledge/project_map.md"
DECISIONS_FILE="${BRAIN_DIR}/knowledge/decisions.md"

# ── Helpers ─────────────────────────────────────────────────────────────────
info() { echo -e "${BLUE}ℹ${RESET} $*"; }

count_json_array() {
    local file="$1"
    local key="$2"
    if [ -f "${file}" ] && command -v python3 &>/dev/null; then
        python3 -c "
import json, sys
try:
    with open('${file}') as f:
        data = json.load(f)
    print(len(data.get('${key}', [])))
except:
    print(0)
" 2>/dev/null
    elif [ -f "${file}" ] && command -v jq &>/dev/null; then
        jq ".${key} | length" "${file}" 2>/dev/null || echo 0
    else
        echo "?"
    fi
}

# ── Main ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}context-compact${RESET} — Quick context summary for agent catch-up

${BOLD}USAGE${RESET}
  context-compact.sh [--append]

${BOLD}OPTIONS${RESET}
  --append    Also append compact marker to memory.md
  --help      Show this help

${BOLD}PURPOSE${RESET}
  Generates a compact summary of the brain state so agents can
  quickly catch up without reading every file. Equivalent to /compact.
EOF
}

main() {
    local do_append=false
    case "${1:-}" in
        --help|-h) show_help; exit 0 ;;
        --append) do_append=true ;;
    esac

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')

    # ── Gather stats ────────────────────────────────────────────────────
    local entity_count relation_count project_count session_count open_tasks
    entity_count=$(count_json_array "${ENTITIES_FILE}" "entities")
    relation_count=$(count_json_array "${RELATIONS_FILE}" "relations")

    if [ -f "${PROJECT_MAP}" ]; then
        project_count=$(grep -c '^### ' "${PROJECT_MAP}" 2>/dev/null || echo 0)
    else
        project_count=0
    fi

    if [ -f "${MEMORY_FILE}" ]; then
        session_count=$(grep -c '|.*|.*|' "${MEMORY_FILE}" 2>/dev/null || echo 0)
        session_count=$((session_count > 1 ? session_count - 1 : 0))  # Subtract header row
        open_tasks=$(grep -c '^\- \[ \]' "${MEMORY_FILE}" 2>/dev/null || echo 0)
    else
        session_count=0
        open_tasks=0
    fi

    local decision_count=0
    if [ -f "${DECISIONS_FILE}" ]; then
        decision_count=$(grep -c '^## ADR-' "${DECISIONS_FILE}" 2>/dev/null || echo 0)
    fi

    # ── Current focus ───────────────────────────────────────────────────
    local current_focus="(unknown)"
    if [ -f "${MEMORY_FILE}" ]; then
        current_focus=$(awk '/^## Current Focus/{getline; if(NF) print; exit}' "${MEMORY_FILE}" 2>/dev/null || echo "(unknown)")
    fi

    # ── Output compact summary ──────────────────────────────────────────
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║         SHELLLL Brain — Compact Context         ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${BOLD}Timestamp:${RESET}     ${timestamp}"
    echo -e "${BOLD}Brain:${RESET}         ${BRAIN_DIR}"
    echo ""
    echo -e "${BOLD}Current Focus:${RESET} ${current_focus}"
    echo ""
    echo -e "${BOLD}Knowledge Graph${RESET}"
    echo -e "  Entities:    ${entity_count}"
    echo -e "  Relations:   ${relation_count}"
    echo ""
    echo -e "${BOLD}Status${RESET}"
    echo -e "  Projects:    ${project_count}"
    echo -e "  Sessions:    ${session_count}"
    echo -e "  Open Tasks:  ${open_tasks}"
    echo -e "  Decisions:   ${decision_count}"
    echo ""

    # Show open tasks if any
    if [ "${open_tasks}" -gt 0 ] && [ -f "${MEMORY_FILE}" ]; then
        echo -e "${BOLD}Open Tasks${RESET}"
        grep '^\- \[ \]' "${MEMORY_FILE}" 2>/dev/null | head -10 | sed 's/^/  /'
        echo ""
    fi

    # Show recent sessions
    if [ -f "${MEMORY_FILE}" ]; then
        local recent_sessions
        recent_sessions=$(grep '^| [0-9]' "${MEMORY_FILE}" 2>/dev/null | tail -3)
        if [ -n "${recent_sessions}" ]; then
            echo -e "${BOLD}Recent Sessions${RESET}"
            echo "${recent_sessions}" | sed 's/^/  /'
            echo ""
        fi
    fi

    echo -e "${DIM}── End of compact context ──${RESET}"

    # ── Optionally append to memory ─────────────────────────────────────
    if [ "${do_append}" = true ] && [ -f "${MEMORY_FILE}" ]; then
        {
            echo ""
            echo "<!-- compact: ${timestamp} | entities:${entity_count} relations:${relation_count} projects:${project_count} tasks:${open_tasks} -->"
        } >> "${MEMORY_FILE}"
        info "Compact marker appended to memory.md"
    fi
}

main "$@"
