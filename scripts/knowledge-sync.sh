#!/usr/bin/env bash
# knowledge-sync.sh — Knowledge graph maintenance and validation
# Validates entities/relations, finds orphans, auto-fixes, commits changes
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
GRAPH_DIR="${BRAIN_DIR}/knowledge/graph"
ENTITIES_FILE="${GRAPH_DIR}/entities.json"
RELATIONS_FILE="${GRAPH_DIR}/relations.json"
CHECK_ONLY=false
ISSUES=0

# ── Helpers ─────────────────────────────────────────────────────────────────
info()     { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()       { echo -e "${GREEN}✓${RESET} $*"; }
warn()     { echo -e "${YELLOW}⚠${RESET} $*"; ISSUES=$((ISSUES + 1)); }
err()      { echo -e "${RED}✗${RESET} $*" >&2; ISSUES=$((ISSUES + 1)); }
die()      { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }
section()  { echo -e "\n${BOLD}${CYAN}── $* ──${RESET}"; }

# Require python3 for JSON manipulation
require_python() {
    if ! command -v python3 &>/dev/null; then
        die "python3 is required for knowledge-sync. Install with: paru -S python"
    fi
}

# ── Validation ──────────────────────────────────────────────────────────────

validate_json() {
    local file="$1"
    local label="$2"

    if [ ! -f "${file}" ]; then
        err "${label}: file not found (${file})"
        return 1
    fi

    if python3 -m json.tool "${file}" >/dev/null 2>&1; then
        ok "${label}: valid JSON"
        return 0
    else
        err "${label}: INVALID JSON"
        python3 -m json.tool "${file}" 2>&1 | head -5 | sed 's/^/    /'
        return 1
    fi
}

validate_entities() {
    section "Entity Validation"

    if ! validate_json "${ENTITIES_FILE}" "entities.json"; then
        return 1
    fi

    local entity_count
    entity_count=$(python3 -c "
import json
with open('${ENTITIES_FILE}') as f:
    data = json.load(f)
entities = data.get('entities', [])
print(len(entities))

# Check for duplicate IDs
ids = [e.get('id', '') for e in entities]
dupes = [i for i in set(ids) if ids.count(i) > 1]
if dupes:
    for d in dupes:
        print(f'DUPE:{d}')

# Check for missing required fields
for e in entities:
    if not e.get('id'):
        print(f'MISSING_ID:{json.dumps(e)[:60]}')
    if not e.get('type'):
        print(f'MISSING_TYPE:{e.get(\"id\", \"unknown\")}')
    if not e.get('name'):
        print(f'MISSING_NAME:{e.get(\"id\", \"unknown\")}')
" 2>/dev/null)

    local count
    count=$(echo "${entity_count}" | head -1)
    info "Entity count: ${count}"

    # Check for issues
    echo "${entity_count}" | tail -n +2 | while IFS= read -r line; do
        case "${line}" in
            DUPE:*) warn "Duplicate entity ID: ${line#DUPE:}" ;;
            MISSING_ID:*) warn "Entity missing ID: ${line#MISSING_ID:}" ;;
            MISSING_TYPE:*) warn "Entity missing type: ${line#MISSING_TYPE:}" ;;
            MISSING_NAME:*) warn "Entity missing name: ${line#MISSING_NAME:}" ;;
        esac
    done
}

validate_relations() {
    section "Relation Validation"

    if ! validate_json "${RELATIONS_FILE}" "relations.json"; then
        return 1
    fi

    # Get all entity IDs and check relations
    local result
    result=$(python3 -c "
import json

with open('${ENTITIES_FILE}') as f:
    entities = json.load(f)
with open('${RELATIONS_FILE}') as f:
    relations = json.load(f)

entity_ids = {e['id'] for e in entities.get('entities', [])}
rels = relations.get('relations', [])
print(f'RELATION_COUNT:{len(rels)}')

orphans = []
for i, r in enumerate(rels):
    from_id = r.get('from', '')
    to_id = r.get('to', '')
    if from_id not in entity_ids:
        orphans.append(f'ORPHAN_FROM:{i}:{from_id}')
    if to_id not in entity_ids:
        orphans.append(f'ORPHAN_TO:{i}:{to_id}')
    if not r.get('type'):
        print(f'MISSING_TYPE:{i}:{from_id}->{to_id}')

for o in orphans:
    print(o)

if orphans:
    print(f'ORPHAN_COUNT:{len(orphans)}')
else:
    print('ORPHAN_COUNT:0')
" 2>/dev/null)

    # Parse results
    local rel_count orphan_count
    rel_count=$(echo "${result}" | grep "^RELATION_COUNT:" | cut -d: -f2)
    orphan_count=$(echo "${result}" | grep "^ORPHAN_COUNT:" | cut -d: -f2)

    info "Relation count: ${rel_count}"

    # Report orphans
    echo "${result}" | grep "^ORPHAN_" | grep -v "ORPHAN_COUNT" | while IFS= read -r line; do
        case "${line}" in
            ORPHAN_FROM:*) warn "Orphan relation: 'from' entity '${line##*:}' not found" ;;
            ORPHAN_TO:*)   warn "Orphan relation: 'to' entity '${line##*:}' not found" ;;
        esac
    done

    echo "${result}" | grep "^MISSING_TYPE:" | while IFS= read -r line; do
        warn "Relation missing type: ${line#MISSING_TYPE:}"
    done

    if [ "${orphan_count}" = "0" ]; then
        ok "No orphan relations"
    else
        warn "${orphan_count} orphan reference(s) found"
    fi
}

# ── Auto-Fix ────────────────────────────────────────────────────────────────

fix_orphans() {
    section "Auto-Fix: Removing Orphan Relations"

    if [ "${CHECK_ONLY}" = true ]; then
        info "Skipping auto-fix (--check mode)"
        return 0
    fi

    python3 -c "
import json
from datetime import datetime

with open('${ENTITIES_FILE}') as f:
    entities = json.load(f)
with open('${RELATIONS_FILE}') as f:
    relations = json.load(f)

entity_ids = {e['id'] for e in entities.get('entities', [])}
original_count = len(relations.get('relations', []))

# Filter out orphan relations
clean_rels = [
    r for r in relations.get('relations', [])
    if r.get('from', '') in entity_ids and r.get('to', '') in entity_ids
]

removed = original_count - len(clean_rels)

if removed > 0:
    relations['relations'] = clean_rels
    relations['updated'] = datetime.now().isoformat()
    with open('${RELATIONS_FILE}', 'w') as f:
        json.dump(relations, f, indent=2)
        f.write('\n')
    print(f'FIXED:{removed}')
else:
    print('FIXED:0')
" 2>/dev/null

    local fixed
    fixed=$(python3 -c "
import json
with open('${ENTITIES_FILE}') as f:
    entities = json.load(f)
with open('${RELATIONS_FILE}') as f:
    relations = json.load(f)
entity_ids = {e['id'] for e in entities.get('entities', [])}
orphans = [r for r in relations.get('relations', []) if r.get('from','') not in entity_ids or r.get('to','') not in entity_ids]
print(len(orphans))
" 2>/dev/null || echo "0")

    if [ "${fixed}" = "0" ]; then
        ok "No orphans to fix"
    else
        ok "Removed ${fixed} orphan relation(s)"
    fi
}

# ── Git Commit ──────────────────────────────────────────────────────────────

commit_changes() {
    section "Git Commit"

    if [ "${CHECK_ONLY}" = true ]; then
        info "Skipping git commit (--check mode)"
        return 0
    fi

    # Check if we're in a git repo
    if ! git -C "${BRAIN_DIR}" rev-parse --is-inside-work-tree &>/dev/null; then
        warn "Not a git repository — skipping commit"
        return 0
    fi

    # Check for knowledge changes
    local changes
    changes=$(git -C "${BRAIN_DIR}" diff --name-only -- knowledge/ 2>/dev/null || true)
    local staged
    staged=$(git -C "${BRAIN_DIR}" diff --cached --name-only -- knowledge/ 2>/dev/null || true)

    if [ -z "${changes}" ] && [ -z "${staged}" ]; then
        info "No knowledge changes to commit"
        return 0
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    git -C "${BRAIN_DIR}" add knowledge/
    git -C "${BRAIN_DIR}" commit -m "knowledge: sync at ${timestamp}" \
        -m "Auto-committed by knowledge-sync.sh" \
        --no-verify 2>/dev/null || {
        info "Nothing to commit (already clean)"
        return 0
    }

    ok "Committed knowledge changes"
}

# ── Report ──────────────────────────────────────────────────────────────────

print_report() {
    section "Summary"

    if [ "${ISSUES}" -eq 0 ]; then
        ok "${BOLD}Knowledge graph is healthy${RESET}"
    else
        warn "${BOLD}${ISSUES} issue(s) found${RESET}"
    fi
}

# ── Help ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}knowledge-sync${RESET} — Knowledge graph maintenance

${BOLD}USAGE${RESET}
  knowledge-sync.sh [--check]

${BOLD}OPTIONS${RESET}
  --check    Validate only, no changes or commits
  --help     Show this help

${BOLD}CHECKS${RESET}
  • Validates entities.json and relations.json (valid JSON)
  • Checks for duplicate entity IDs
  • Checks for missing required fields (id, type, name)
  • Finds orphan relations (referencing non-existent entities)
  • Reports entity count, relation count

${BOLD}AUTO-FIX (without --check)${RESET}
  • Removes relations referencing non-existent entities
  • Commits knowledge changes with timestamped message

${BOLD}EXAMPLES${RESET}
  knowledge-sync.sh            # Full sync + auto-fix + commit
  knowledge-sync.sh --check    # Validate only
EOF
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    case "${1:-}" in
        --help|-h) show_help; exit 0 ;;
        --check) CHECK_ONLY=true ;;
    esac

    require_python

    echo -e "${BOLD}${CYAN}🔄 Knowledge Graph Sync${RESET}"
    echo -e "${DIM}Brain: ${BRAIN_DIR}${RESET}"

    validate_entities
    validate_relations
    fix_orphans
    commit_changes
    print_report
}

main "$@"
