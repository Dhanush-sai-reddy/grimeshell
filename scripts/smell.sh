#!/usr/bin/env bash
# smell.sh — Standalone code smell checker
# Checks shell, JS/TS, Python files for common issues
# Exit: 0=clean, 1=warnings, 2=critical
set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── State ───────────────────────────────────────────────────────────────────
WARNINGS=0
CRITICALS=0
FILES_CHECKED=0
TARGET=""

# ── Helpers ─────────────────────────────────────────────────────────────────
info()     { echo -e "${BLUE}ℹ${RESET} $*"; }
ok()       { echo -e "${GREEN}✓${RESET} $*"; }
warning()  { echo -e "${YELLOW}⚠ WARN${RESET}  $*"; WARNINGS=$((WARNINGS + 1)); }
critical() { echo -e "${RED}✗ CRIT${RESET}  $*"; CRITICALS=$((CRITICALS + 1)); }
section()  { echo -e "\n${BOLD}${CYAN}── $* ──${RESET}"; }

# ── Universal Checks ───────────────────────────────────────────────────────

check_line_count() {
    local file="$1"
    local lines
    lines=$(wc -l < "${file}")
    if [ "${lines}" -gt 500 ]; then
        critical "${file}: ${lines} lines (>500) — consider splitting"
    elif [ "${lines}" -gt 300 ]; then
        warning "${file}: ${lines} lines (>300) — getting long"
    fi
}

check_todos() {
    local file="$1"
    local count
    count=$(grep -ciE '(TODO|FIXME|HACK|XXX|TEMP)' "${file}" 2>/dev/null || echo 0)
    if [ "${count}" -gt 5 ]; then
        warning "${file}: ${count} TODO/FIXME markers — clean up debt"
    elif [ "${count}" -gt 0 ]; then
        info "${file}: ${count} TODO/FIXME marker(s)"
    fi
}

check_hardcoded_strings() {
    local file="$1"
    # Check for potential hardcoded secrets
    local secret_patterns='(api[_-]?key|api[_-]?secret|password|passwd|token|secret[_-]?key)\s*[:=]\s*["\x27][^\s"'\'']{8,}'
    local hits
    hits=$(grep -ciE "${secret_patterns}" "${file}" 2>/dev/null || echo 0)
    if [ "${hits}" -gt 0 ]; then
        critical "${file}: ${hits} potential hardcoded secret(s) found"
    fi

    # Check for hardcoded IPs (not localhost)
    local ip_hits
    ip_hits=$(grep -cE '\b(?!127\.0\.0\.1|0\.0\.0\.0|localhost)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b' "${file}" 2>/dev/null || echo 0)
    if [ "${ip_hits}" -gt 0 ]; then
        warning "${file}: ${ip_hits} hardcoded IP address(es)"
    fi
}

check_function_length() {
    local file="$1"
    local ext="${file##*.}"

    # Simplified function length check via counting lines between function markers
    case "${ext}" in
        sh|bash)
            # Count functions longer than 50 lines
            awk '/^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)/ || /^function\s+[a-zA-Z_]/ {name=$0; start=NR}
                 /^}$/ && start {len=NR-start; if(len>50) printf "  ⚠ Function at line %d: %d lines\n", start, len; start=0}' \
                 "${file}" 2>/dev/null | while IFS= read -r line; do
                warning "${file}: long function — ${line}"
            done
            ;;
        js|ts|jsx|tsx)
            # Basic: count lines between function/const declarations
            local long_funcs
            long_funcs=$(awk '/^(export\s+)?(async\s+)?function\s+/ || /^(export\s+)?(const|let|var)\s+\w+\s*=\s*(async\s+)?\(/ {start=NR; name=$0}
                 /^}[;,]?$/ && start {len=NR-start; if(len>50) printf "line %d (%d lines)\n", start, len; start=0}' \
                 "${file}" 2>/dev/null | head -5)
            if [ -n "${long_funcs}" ]; then
                while IFS= read -r line; do
                    warning "${file}: long function at ${line}"
                done <<< "${long_funcs}"
            fi
            ;;
        py)
            local long_funcs
            long_funcs=$(awk '/^(    )?def\s+/ {if(start) {len=NR-start; if(len>50) printf "line %d (%d lines)\n", start, len}; start=NR; name=$0}
                 END {if(start) {len=NR-start; if(len>50) printf "line %d (%d lines)\n", start, len}}' \
                 "${file}" 2>/dev/null | head -5)
            if [ -n "${long_funcs}" ]; then
                while IFS= read -r line; do
                    warning "${file}: long function at ${line}"
                done <<< "${long_funcs}"
            fi
            ;;
    esac
}

# ── Language-Specific Checks ───────────────────────────────────────────────

check_shell() {
    local file="$1"
    section "Shell: $(basename "${file}")"
    FILES_CHECKED=$((FILES_CHECKED + 1))

    # Use shellcheck if available
    if command -v shellcheck &>/dev/null; then
        local sc_output
        sc_output=$(shellcheck -f gcc "${file}" 2>&1 || true)
        if [ -n "${sc_output}" ]; then
            local sc_errors sc_warnings
            sc_errors=$(echo "${sc_output}" | grep -c ":.*error:" 2>/dev/null || echo 0)
            sc_warnings=$(echo "${sc_output}" | grep -c ":.*warning:" 2>/dev/null || echo 0)
            if [ "${sc_errors}" -gt 0 ]; then
                critical "${file}: shellcheck found ${sc_errors} error(s)"
                echo "${sc_output}" | grep "error:" | head -5 | sed 's/^/    /'
            fi
            if [ "${sc_warnings}" -gt 0 ]; then
                warning "${file}: shellcheck found ${sc_warnings} warning(s)"
            fi
        else
            ok "shellcheck: clean"
        fi
    else
        info "shellcheck not installed — skipping (install with: paru -S shellcheck)"
    fi

    # Basic pattern checks
    if grep -qE '^\s*eval\s' "${file}" 2>/dev/null; then
        warning "${file}: uses eval — potential security risk"
    fi
    if grep -qE 'rm\s+-rf\s+(/|\$|"\$)' "${file}" 2>/dev/null; then
        critical "${file}: dangerous rm -rf pattern detected"
    fi

    check_line_count "${file}"
    check_todos "${file}"
    check_hardcoded_strings "${file}"
    check_function_length "${file}"
}

check_javascript() {
    local file="$1"
    section "JS/TS: $(basename "${file}")"
    FILES_CHECKED=$((FILES_CHECKED + 1))

    # Use eslint if available
    if command -v eslint &>/dev/null; then
        local eslint_output
        eslint_output=$(eslint --no-eslintrc --format compact "${file}" 2>&1 || true)
        if echo "${eslint_output}" | grep -q "Error -"; then
            local err_count
            err_count=$(echo "${eslint_output}" | grep -c "Error -" 2>/dev/null || echo 0)
            critical "${file}: eslint found ${err_count} error(s)"
        fi
    else
        # Basic pattern checks when no eslint
        if grep -qE 'console\.(log|debug|info)\(' "${file}" 2>/dev/null; then
            local console_count
            console_count=$(grep -cE 'console\.(log|debug|info)\(' "${file}" 2>/dev/null || echo 0)
            warning "${file}: ${console_count} console.log/debug/info call(s) — remove for production"
        fi
        if grep -qE '\bvar\s' "${file}" 2>/dev/null; then
            warning "${file}: uses 'var' — prefer 'const' or 'let'"
        fi
        if grep -qE '==\s|!=\s' "${file}" 2>/dev/null; then
            if ! grep -qE '===|!==' "${file}" 2>/dev/null; then
                warning "${file}: uses loose equality (== / !=) — prefer === / !=="
            fi
        fi
    fi

    check_line_count "${file}"
    check_todos "${file}"
    check_hardcoded_strings "${file}"
    check_function_length "${file}"
}

check_python() {
    local file="$1"
    section "Python: $(basename "${file}")"
    FILES_CHECKED=$((FILES_CHECKED + 1))

    # Use ruff or flake8 if available
    if command -v ruff &>/dev/null; then
        local ruff_output
        ruff_output=$(ruff check "${file}" 2>&1 || true)
        if [ -n "${ruff_output}" ] && ! echo "${ruff_output}" | grep -q "^$"; then
            local issue_count
            issue_count=$(echo "${ruff_output}" | grep -cE "^${file}:" 2>/dev/null || echo 0)
            if [ "${issue_count}" -gt 0 ]; then
                warning "${file}: ruff found ${issue_count} issue(s)"
                echo "${ruff_output}" | head -5 | sed 's/^/    /'
            fi
        else
            ok "ruff: clean"
        fi
    elif command -v flake8 &>/dev/null; then
        local flake_output
        flake_output=$(flake8 "${file}" 2>&1 || true)
        if [ -n "${flake_output}" ]; then
            local issue_count
            issue_count=$(echo "${flake_output}" | wc -l)
            warning "${file}: flake8 found ${issue_count} issue(s)"
        fi
    else
        # Basic checks
        if grep -qE '^\s*import\s+\*' "${file}" 2>/dev/null; then
            warning "${file}: wildcard import (import *) — be explicit"
        fi
        if grep -qE '\bprint\(' "${file}" 2>/dev/null; then
            local print_count
            print_count=$(grep -cE '\bprint\(' "${file}" 2>/dev/null || echo 0)
            if [ "${print_count}" -gt 5 ]; then
                warning "${file}: ${print_count} print() calls — consider using logging module"
            fi
        fi
        if grep -qE 'except\s*:' "${file}" 2>/dev/null; then
            warning "${file}: bare except clause — catch specific exceptions"
        fi
    fi

    check_line_count "${file}"
    check_todos "${file}"
    check_hardcoded_strings "${file}"
    check_function_length "${file}"
}

check_json() {
    local file="$1"
    section "JSON: $(basename "${file}")"
    FILES_CHECKED=$((FILES_CHECKED + 1))

    if command -v python3 &>/dev/null; then
        if ! python3 -m json.tool "${file}" >/dev/null 2>&1; then
            critical "${file}: invalid JSON"
        else
            ok "valid JSON"
        fi
    elif command -v jq &>/dev/null; then
        if ! jq . "${file}" >/dev/null 2>&1; then
            critical "${file}: invalid JSON"
        else
            ok "valid JSON"
        fi
    else
        info "No JSON validator available (install jq or python3)"
    fi
}

# ── File Router ─────────────────────────────────────────────────────────────

check_file() {
    local file="$1"
    local ext="${file##*.}"
    local basename
    basename=$(basename "${file}")

    # Skip binary files and common non-code files
    case "${basename}" in
        *.min.js|*.min.css|*.map|*.lock|*.png|*.jpg|*.gif|*.ico|*.woff*|*.ttf|*.eot)
            return 0 ;;
    esac

    case "${ext}" in
        sh|bash)         check_shell "${file}" ;;
        js|jsx|mjs)      check_javascript "${file}" ;;
        ts|tsx)          check_javascript "${file}" ;;
        py)              check_python "${file}" ;;
        json)            check_json "${file}" ;;
        *)
            # Universal checks for other text files
            if file "${file}" 2>/dev/null | grep -q "text"; then
                check_line_count "${file}"
                check_todos "${file}"
                check_hardcoded_strings "${file}"
                FILES_CHECKED=$((FILES_CHECKED + 1))
            fi
            ;;
    esac
}

# ── Directory Scanner ───────────────────────────────────────────────────────

scan_directory() {
    local dir="$1"
    info "Scanning directory: ${dir}"

    # Find relevant files, skip common ignore patterns
    while IFS= read -r -d '' file; do
        check_file "${file}"
    done < <(find "${dir}" -type f \
        \( -name "*.sh" -o -name "*.bash" -o -name "*.js" -o -name "*.jsx" \
           -o -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.json" \
           -o -name "*.mjs" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/.sandboxes/*" \
        -not -path "*/dist/*" \
        -not -path "*/build/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/vendor/*" \
        -not -name "*.min.*" \
        -not -name "package-lock.json" \
        -not -name "yarn.lock" \
        -print0 2>/dev/null)
}

# ── Report ──────────────────────────────────────────────────────────────────

print_report() {
    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD} Smell Check Report${RESET}"
    echo -e "${BOLD}═══════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "  Files checked:  ${BOLD}${FILES_CHECKED}${RESET}"
    echo -e "  Warnings:       ${YELLOW}${WARNINGS}${RESET}"
    echo -e "  Criticals:      ${RED}${CRITICALS}${RESET}"
    echo ""

    if [ "${CRITICALS}" -gt 0 ]; then
        echo -e "  ${RED}${BOLD}✗ CRITICAL issues found — must fix before proceeding${RESET}"
        return 2
    elif [ "${WARNINGS}" -gt 0 ]; then
        echo -e "  ${YELLOW}${BOLD}⚠ Warnings found — review recommended${RESET}"
        return 1
    else
        echo -e "  ${GREEN}${BOLD}✓ Clean — no issues detected${RESET}"
        return 0
    fi
}

# ── Help ────────────────────────────────────────────────────────────────────
show_help() {
    cat <<EOF
${BOLD}smell.sh${RESET} — Code smell checker

${BOLD}USAGE${RESET}
  smell.sh [file|directory]

${BOLD}ARGUMENTS${RESET}
  file         Check a single file
  directory    Recursively check all supported files (default: .)

${BOLD}CHECKS${RESET}
  Shell:     shellcheck (if installed), eval usage, dangerous rm
  JS/TS:     eslint (if installed), console.log, var usage, loose equality
  Python:    ruff/flake8 (if installed), wildcard imports, bare except
  All:       line count, function length, TODO count, hardcoded secrets

${BOLD}EXIT CODES${RESET}
  0    Clean — no issues
  1    Warnings found
  2    Critical issues found

${BOLD}EXAMPLES${RESET}
  smell.sh                    # Check current directory
  smell.sh scripts/           # Check scripts directory
  smell.sh my-script.sh       # Check single file
EOF
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    case "${1:-}" in
        --help|-h|help) show_help; exit 0 ;;
    esac

    TARGET="${1:-.}"

    echo -e "${BOLD}${MAGENTA}🔍 Code Smell Checker${RESET}"
    echo ""

    if [ -f "${TARGET}" ]; then
        check_file "${TARGET}"
    elif [ -d "${TARGET}" ]; then
        scan_directory "${TARGET}"
    else
        die "Target not found: ${TARGET}"
    fi

    print_report
}

main "$@"
