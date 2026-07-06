#!/usr/bin/env bash
# pre-commit.sh — Git pre-commit hook
# Runs smell checks, secret detection, and JSON validation on staged files
# Install: ln -sf ../../hooks/pre-commit.sh .git/hooks/pre-commit
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Constants ───────────────────────────────────────────────────────────────
BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# If running as a git hook, BRAIN_DIR may be .git/hooks/../../ = repo root
if [ -d "${BRAIN_DIR}/.git" ]; then
    : # already at repo root
elif [ -d "${BRAIN_DIR}/../../.git" ]; then
    BRAIN_DIR="$(cd "${BRAIN_DIR}/../.." && pwd)"
fi

SMELL_SCRIPT="${BRAIN_DIR}/scripts/smell.sh"
EXIT_CODE=0

# ── Helpers ─────────────────────────────────────────────────────────────────
info()  { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $*"; }
err()   { echo -e "${RED}✗${RESET} $*" >&2; }

# ── Secret Detection ───────────────────────────────────────────────────────

check_secrets() {
    local file="$1"

    # Patterns that likely indicate hardcoded secrets
    local patterns=(
        # API keys and tokens
        'api[_-]?key\s*[:=]\s*["\x27][A-Za-z0-9_\-]{20,}'
        'api[_-]?secret\s*[:=]\s*["\x27][A-Za-z0-9_\-]{20,}'
        'auth[_-]?token\s*[:=]\s*["\x27][A-Za-z0-9_\-]{20,}'
        'access[_-]?token\s*[:=]\s*["\x27][A-Za-z0-9_\-]{20,}'

        # AWS
        'AKIA[0-9A-Z]{16}'

        # Private keys
        '-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----'

        # Generic secrets
        'password\s*[:=]\s*["\x27][^\s"'\'']{8,}'
        'secret\s*[:=]\s*["\x27][^\s"'\'']{8,}'

        # GitHub tokens
        'gh[pousr]_[A-Za-z0-9_]{36,}'

        # Gemini/Google API
        'AIza[0-9A-Za-z_\-]{35}'
    )

    for pattern in "${patterns[@]}"; do
        if grep -qEi "${pattern}" "${file}" 2>/dev/null; then
            err "BLOCKED: Potential secret in ${file}"
            grep -nEi "${pattern}" "${file}" 2>/dev/null | head -3 | while IFS= read -r line; do
                # Mask the actual secret value
                echo "  ${line}" | sed -E 's/(["\x27])[A-Za-z0-9_\-]{8,}(["\x27])/\1***MASKED***\2/g'
            done
            return 1
        fi
    done
    return 0
}

# ── JSON Validation ────────────────────────────────────────────────────────

validate_json_file() {
    local file="$1"

    if command -v python3 &>/dev/null; then
        if ! python3 -m json.tool "${file}" >/dev/null 2>&1; then
            err "Invalid JSON: ${file}"
            python3 -m json.tool "${file}" 2>&1 | head -3 | sed 's/^/  /'
            return 1
        fi
    elif command -v jq &>/dev/null; then
        if ! jq . "${file}" >/dev/null 2>&1; then
            err "Invalid JSON: ${file}"
            return 1
        fi
    fi
    return 0
}

# ── Main ────────────────────────────────────────────────────────────────────

main() {
    echo -e "${BOLD}🔒 Pre-Commit Checks${RESET}"
    echo ""

    # Get staged files
    local staged_files
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

    if [ -z "${staged_files}" ]; then
        info "No staged files to check"
        exit 0
    fi

    local file_count
    file_count=$(echo "${staged_files}" | wc -l)
    info "Checking ${file_count} staged file(s)..."
    echo ""

    # 1. Secret detection on ALL staged files
    echo -e "${BOLD}── Secret Detection ──${RESET}"
    local secrets_found=0
    while IFS= read -r file; do
        if [ -f "${file}" ]; then
            if ! check_secrets "${file}"; then
                secrets_found=1
            fi
        fi
    done <<< "${staged_files}"

    if [ "${secrets_found}" -eq 0 ]; then
        ok "No secrets detected"
    else
        EXIT_CODE=1
    fi

    # 2. JSON validation for knowledge/graph/ files
    echo ""
    echo -e "${BOLD}── JSON Validation ──${RESET}"
    local json_issues=0
    while IFS= read -r file; do
        if [[ "${file}" == knowledge/graph/*.json ]] && [ -f "${file}" ]; then
            if validate_json_file "${file}"; then
                ok "Valid: ${file}"
            else
                json_issues=1
            fi
        fi
    done <<< "${staged_files}"

    if [ "${json_issues}" -eq 0 ]; then
        ok "All JSON files valid"
    else
        EXIT_CODE=1
    fi

    # 3. Smell check on staged code files
    echo ""
    echo -e "${BOLD}── Code Smell Check ──${RESET}"
    if [ -x "${SMELL_SCRIPT}" ]; then
        local code_files=""
        while IFS= read -r file; do
            case "${file}" in
                *.sh|*.bash|*.js|*.jsx|*.ts|*.tsx|*.py|*.mjs)
                    if [ -f "${file}" ]; then
                        code_files="${code_files} ${file}"
                    fi
                    ;;
            esac
        done <<< "${staged_files}"

        if [ -n "${code_files}" ]; then
            for file in ${code_files}; do
                "${SMELL_SCRIPT}" "${file}" 2>/dev/null || {
                    local smell_exit=$?
                    if [ "${smell_exit}" -eq 2 ]; then
                        EXIT_CODE=1  # Critical issues block commit
                    fi
                    # Warnings (exit 1) don't block
                }
            done
        else
            info "No code files to smell-check"
        fi
    else
        info "smell.sh not found — skipping code smell check"
    fi

    # Final verdict
    echo ""
    if [ "${EXIT_CODE}" -ne 0 ]; then
        err "${BOLD}Pre-commit checks FAILED — commit blocked${RESET}"
        echo -e "  ${YELLOW}Fix the issues above and try again.${RESET}"
        echo -e "  ${YELLOW}To bypass (not recommended): git commit --no-verify${RESET}"
    else
        ok "${BOLD}All pre-commit checks passed${RESET}"
    fi

    exit "${EXIT_CODE}"
}

main "$@"
