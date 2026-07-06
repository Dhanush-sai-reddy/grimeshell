#!/usr/bin/env bash
# agent-sandbox.sh — Lightweight agent sandboxing via git worktrees
# Usage: agent-sandbox.sh <command> [args]
# Commands: create, validate, merge, destroy, list
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
SANDBOX_DIR="${BRAIN_DIR}/.sandboxes"
GITIGNORE="${BRAIN_DIR}/.gitignore"

# ── Helpers ─────────────────────────────────────────────────────────────────
info()  { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
err()   { echo -e "${RED}✗${RESET} $*" >&2; }
die()   { err "$@"; exit 1; }

ensure_git_repo() {
    git -C "${BRAIN_DIR}" rev-parse --is-inside-work-tree &>/dev/null \
        || die "Not a git repository: ${BRAIN_DIR}"
}

ensure_sandbox_dir() {
    if [ ! -d "${SANDBOX_DIR}" ]; then
        mkdir -p "${SANDBOX_DIR}"
        info "Created sandbox directory: ${SANDBOX_DIR}"
    fi
    # Ensure .sandboxes/ is in .gitignore
    if [ -f "${GITIGNORE}" ]; then
        if ! grep -qxF '.sandboxes/' "${GITIGNORE}" 2>/dev/null; then
            echo '.sandboxes/' >> "${GITIGNORE}"
            info "Added .sandboxes/ to .gitignore"
        fi
    else
        echo '.sandboxes/' > "${GITIGNORE}"
        info "Created .gitignore with .sandboxes/"
    fi
}

validate_name() {
    local name="$1"
    if [[ -z "${name}" ]]; then
        die "Sandbox name is required"
    fi
    if [[ ! "${name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        die "Invalid sandbox name '${name}' — use only alphanumeric, dash, underscore"
    fi
}

# ── Commands ────────────────────────────────────────────────────────────────

cmd_create() {
    local name="${1:-}"
    validate_name "${name}"
    ensure_git_repo
    ensure_sandbox_dir

    local worktree_path="${SANDBOX_DIR}/${name}"
    local branch_name="sandbox/${name}"

    if [ -d "${worktree_path}" ]; then
        die "Sandbox '${name}' already exists at ${worktree_path}"
    fi

    # Check if branch already exists
    if git -C "${BRAIN_DIR}" show-ref --verify --quiet "refs/heads/${branch_name}" 2>/dev/null; then
        warn "Branch '${branch_name}' already exists, reusing it"
        git -C "${BRAIN_DIR}" worktree add "${worktree_path}" "${branch_name}"
    else
        git -C "${BRAIN_DIR}" worktree add "${worktree_path}" -b "${branch_name}"
    fi

    ok "Created sandbox ${BOLD}${name}${RESET}"
    echo -e "  ${DIM}Worktree: ${worktree_path}${RESET}"
    echo -e "  ${DIM}Branch:   ${branch_name}${RESET}"
    echo ""
    echo -e "  ${CYAN}cd ${worktree_path}${RESET} to start working"
}

cmd_validate() {
    local name="${1:-}"
    validate_name "${name}"

    local worktree_path="${SANDBOX_DIR}/${name}"
    if [ ! -d "${worktree_path}" ]; then
        die "Sandbox '${name}' does not exist"
    fi

    local exit_code=0
    echo -e "${BOLD}Validating sandbox: ${name}${RESET}"
    echo ""

    # Run smell check if available
    local smell_script="${BRAIN_DIR}/scripts/smell.sh"
    if [ -x "${smell_script}" ]; then
        info "Running smell check..."
        if "${smell_script}" "${worktree_path}"; then
            ok "Smell check passed"
        else
            warn "Smell check found issues (exit: $?)"
            exit_code=1
        fi
    else
        warn "smell.sh not found or not executable — skipping"
    fi

    # Check for uncommitted changes
    echo ""
    info "Checking git status..."
    local status
    status=$(git -C "${worktree_path}" status --porcelain 2>/dev/null)
    if [ -n "${status}" ]; then
        warn "Uncommitted changes in sandbox:"
        echo "${status}" | sed 's/^/  /'
        exit_code=1
    else
        ok "Working tree is clean"
    fi

    # Check diff against parent branch
    echo ""
    info "Changes from base branch:"
    local diff_stat
    diff_stat=$(git -C "${worktree_path}" diff --stat HEAD~1 2>/dev/null || echo "(no parent commit)")
    if [ -n "${diff_stat}" ]; then
        echo "${diff_stat}" | sed 's/^/  /'
    else
        echo "  (no changes)"
    fi

    echo ""
    if [ "${exit_code}" -eq 0 ]; then
        ok "${BOLD}Validation passed${RESET} — safe to merge"
    else
        warn "${BOLD}Validation found issues${RESET} — review before merging"
    fi
    return "${exit_code}"
}

cmd_merge() {
    local name="${1:-}"
    validate_name "${name}"
    ensure_git_repo

    local worktree_path="${SANDBOX_DIR}/${name}"
    local branch_name="sandbox/${name}"

    if [ ! -d "${worktree_path}" ]; then
        die "Sandbox '${name}' does not exist"
    fi

    # Check for uncommitted changes
    local status
    status=$(git -C "${worktree_path}" status --porcelain 2>/dev/null)
    if [ -n "${status}" ]; then
        die "Sandbox '${name}' has uncommitted changes — commit or stash first"
    fi

    # Determine the main branch
    local main_branch
    main_branch=$(git -C "${BRAIN_DIR}" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
    if [ -z "${main_branch}" ]; then
        # Fallback: try common names
        for candidate in main master; do
            if git -C "${BRAIN_DIR}" show-ref --verify --quiet "refs/heads/${candidate}" 2>/dev/null; then
                main_branch="${candidate}"
                break
            fi
        done
    fi
    if [ -z "${main_branch}" ]; then
        die "Cannot determine main branch — ensure 'main' or 'master' exists"
    fi

    info "Merging sandbox/${name} into ${main_branch}..."

    # Switch to main branch in the main worktree
    git -C "${BRAIN_DIR}" checkout "${main_branch}"
    git -C "${BRAIN_DIR}" merge "${branch_name}" --no-ff -m "merge: sandbox/${name} into ${main_branch}"

    ok "Merged ${BOLD}${branch_name}${RESET} into ${BOLD}${main_branch}${RESET}"

    # Cleanup
    info "Cleaning up worktree and branch..."
    git -C "${BRAIN_DIR}" worktree remove "${worktree_path}" --force
    git -C "${BRAIN_DIR}" branch -d "${branch_name}" 2>/dev/null || true

    ok "Sandbox '${name}' merged and cleaned up"
}

cmd_destroy() {
    local name="${1:-}"
    validate_name "${name}"
    ensure_git_repo

    local worktree_path="${SANDBOX_DIR}/${name}"
    local branch_name="sandbox/${name}"

    if [ ! -d "${worktree_path}" ]; then
        # Maybe worktree is gone but branch remains
        if git -C "${BRAIN_DIR}" show-ref --verify --quiet "refs/heads/${branch_name}" 2>/dev/null; then
            warn "Worktree missing but branch exists — cleaning up branch"
            git -C "${BRAIN_DIR}" branch -D "${branch_name}"
            ok "Deleted branch ${branch_name}"
            return 0
        fi
        die "Sandbox '${name}' does not exist"
    fi

    # Confirm destruction
    warn "This will ${BOLD}permanently delete${RESET} sandbox '${name}' and branch '${branch_name}'"
    echo -n "  Continue? [y/N] "
    read -r confirm
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        info "Aborted"
        return 0
    fi

    git -C "${BRAIN_DIR}" worktree remove "${worktree_path}" --force 2>/dev/null || {
        warn "Worktree remove failed — force deleting directory"
        rm -rf "${worktree_path}"
        git -C "${BRAIN_DIR}" worktree prune
    }

    git -C "${BRAIN_DIR}" branch -D "${branch_name}" 2>/dev/null || warn "Branch ${branch_name} not found"

    ok "Destroyed sandbox '${name}'"
}

cmd_list() {
    ensure_git_repo

    echo -e "${BOLD}Active Sandboxes${RESET}"
    echo ""

    if [ ! -d "${SANDBOX_DIR}" ]; then
        echo -e "  ${DIM}(none)${RESET}"
        return 0
    fi

    local count=0
    while IFS= read -r worktree_line; do
        # git worktree list output: /path/to/worktree  <hash> [branch]
        local wt_path wt_branch
        wt_path=$(echo "${worktree_line}" | awk '{print $1}')
        wt_branch=$(echo "${worktree_line}" | grep -oP '\[.*?\]' | tr -d '[]')

        # Only show sandboxes (not the main worktree)
        if [[ "${wt_path}" == *"/.sandboxes/"* ]]; then
            local name
            name=$(basename "${wt_path}")
            local status_count
            status_count=$(git -C "${wt_path}" status --porcelain 2>/dev/null | wc -l)

            echo -e "  ${CYAN}${name}${RESET}"
            echo -e "    ${DIM}Branch: ${wt_branch}${RESET}"
            echo -e "    ${DIM}Path:   ${wt_path}${RESET}"
            if [ "${status_count}" -gt 0 ]; then
                echo -e "    ${YELLOW}${status_count} uncommitted change(s)${RESET}"
            else
                echo -e "    ${GREEN}clean${RESET}"
            fi
            echo ""
            count=$((count + 1))
        fi
    done < <(git -C "${BRAIN_DIR}" worktree list 2>/dev/null)

    if [ "${count}" -eq 0 ]; then
        echo -e "  ${DIM}(no active sandboxes)${RESET}"
    else
        echo -e "${DIM}Total: ${count} sandbox(es)${RESET}"
    fi
}

# ── Help ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}agent-sandbox${RESET} — Lightweight agent sandboxing via git worktrees

${BOLD}USAGE${RESET}
  agent-sandbox.sh <command> [name]

${BOLD}COMMANDS${RESET}
  create   <name>   Create a new sandbox worktree + branch
  validate <name>   Run checks on a sandbox before merging
  merge    <name>   Merge sandbox into main branch and clean up
  destroy  <name>   Delete sandbox worktree and branch
  list              Show all active sandboxes

${BOLD}EXAMPLES${RESET}
  agent-sandbox.sh create fix-login
  agent-sandbox.sh validate fix-login
  agent-sandbox.sh merge fix-login
  agent-sandbox.sh destroy fix-login
  agent-sandbox.sh list

${BOLD}NOTES${RESET}
  Sandboxes are created under .sandboxes/ (gitignored).
  Each sandbox gets a branch named sandbox/<name>.
EOF
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    local command="${1:-help}"
    shift || true

    case "${command}" in
        create)   cmd_create "$@" ;;
        validate) cmd_validate "$@" ;;
        merge)    cmd_merge "$@" ;;
        destroy)  cmd_destroy "$@" ;;
        list)     cmd_list ;;
        help|--help|-h) show_help ;;
        *)
            err "Unknown command: ${command}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
