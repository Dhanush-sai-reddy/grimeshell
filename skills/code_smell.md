---
name: code-smell
trigger: "before any commit, when user says /smell, or agent suspects code quality issues"
requires: [git]
---

# Code Smell Detection

## Overview

This skill evaluates code quality by scanning changed or staged files against a
structured checklist of common code smells. Inspired by Zen van Riel's clean code
philosophy: code should read like well-written prose, not a puzzle. Run this before
every commit to catch quality issues early, before they compound into technical debt.

## Prerequisites

- [ ] `git` is installed and the working directory is a git repository
- [ ] There are changed files to analyze (staged, unstaged, or in recent commits)

## Procedure

### Step 1: Identify — Gather Changed Files

Determine which files need analysis based on context:

```bash
# If about to commit (staged files):
git diff --cached --name-only --diff-filter=ACMR

# If general quality check (unstaged changes):
git diff --name-only --diff-filter=ACMR

# If reviewing last commit:
git diff --name-only HEAD~1

# If user specified files explicitly, use those instead
```

**Filter rules:**
- Skip binary files, lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`)
- Skip auto-generated files (`*.min.js`, `*.min.css`, `dist/`, `build/`, `.next/`)
- Skip config files unless they contain logic (`*.config.js` YES, `.gitignore` NO)
- Focus on source code: `.ts`, `.js`, `.py`, `.go`, `.rs`, `.sh`, `.tsx`, `.jsx`, `.vue`, `.svelte`

**If no files found:** Report "No changed files to analyze" and exit cleanly.

### Step 2: Analyze — Run the Smell Checklist

For **each file**, read the full content and evaluate against all 10 smell categories.
Use the diff context (changed lines) to focus analysis, but consider the full file for
structural smells.

#### Smell Checklist

| #  | Smell                    | Detection Method                                                                                                  | Severity |
|----|--------------------------|-------------------------------------------------------------------------------------------------------------------|----------|
| 1  | **DRY Violations**       | Look for duplicated blocks (3+ lines repeated). Check for copy-pasted logic with minor variations.                | MEDIUM   |
| 2  | **Poor Naming**          | Single-letter vars (except `i/j/k` in loops, `e` in catches). Abbreviations (`usr`, `btn`, `mgr`). Misleading names (boolean not prefixed with `is/has/should`). | LOW      |
| 3  | **Long Functions**       | Count lines per function/method. Flag if > 30 lines (excluding comments and blank lines). Suggest extraction.     | MEDIUM   |
| 4  | **Deep Nesting**         | Count indentation depth. Flag if > 3 levels of nesting (if/for/while/try). Suggest early returns or extraction.   | MEDIUM   |
| 5  | **Magic Numbers/Strings**| Hardcoded values that aren't self-documenting. Exempt: 0, 1, -1, "", true, false, common HTTP status codes.       | LOW      |
| 6  | **Missing Error Handling**| Uncaught promises, empty catch blocks, functions that can throw without try/catch, missing null checks on externals. | HIGH   |
| 7  | **Dead Code**            | Unused imports, unreachable code after return/throw, commented-out code blocks (> 3 lines), unused variables.     | LOW      |
| 8  | **God Objects**          | Classes/modules with > 10 public methods, files > 300 lines, objects holding unrelated responsibilities.          | HIGH     |
| 9  | **Tight Coupling**       | Direct file path imports crossing module boundaries, global state mutations, circular dependencies.               | HIGH     |
| 10 | **Bad Comments**         | Comments that restate code (`// increment i`), TODO comments older than the current branch, misleading JSDoc.     | LOW      |

#### Language-Specific Additions

**JavaScript/TypeScript:**
- `any` type usage (TypeScript) — flag as smell unless explicitly justified
- Callback hell instead of async/await
- `var` instead of `const`/`let`
- Missing `===` (using `==` for non-null checks)

**Python:**
- Mutable default arguments (`def foo(items=[])`)
- Bare `except:` clauses
- Star imports (`from module import *`)
- Missing type hints on public functions

**Shell/Bash:**
- Missing `set -euo pipefail`
- Unquoted variables (`$var` instead of `"$var"`)
- Using `ls` in scripts instead of globbing
- Missing `shellcheck` compliance

### Step 3: Score — Rate Each File

Assign a score based on the analysis:

| Score              | Criteria                                                    | Action          |
|--------------------|-------------------------------------------------------------|-----------------|
| 🟢 **CLEAN**       | 0 smells, or only LOW severity cosmetic issues              | Proceed freely  |
| 🟡 **MINOR_SMELLS**| 1–3 LOW severity smells, no MEDIUM or HIGH                  | Note and proceed|
| 🟠 **NEEDS_REFACTOR**| Any MEDIUM smell, or 4+ LOW smells                        | Warn, allow with justification |
| 🔴 **CRITICAL**    | Any HIGH smell, or 3+ MEDIUM smells                         | Block and fix   |

**Scoring rules:**
- A single HIGH smell makes the file CRITICAL regardless of other scores
- Aggregate across the file, not per-function
- Consider context: a 10-line script has different standards than a core module

### Step 4: Report — Generate Structured Output

Produce a report in this exact format:

```markdown
## 🔍 Code Smell Report — [DATE]

**Overall Status:** 🟢 CLEAN | 🟡 MINOR | 🟠 REFACTOR | 🔴 CRITICAL
**Files Analyzed:** [N]
**Smells Found:** [N]

---

### [filename.ts] — 🟡 MINOR_SMELLS (2 smells)

| Line | Smell | Severity | Description | Fix |
|------|-------|----------|-------------|-----|
| 42   | Poor Naming | LOW | Variable `d` — unclear purpose | Rename to `createdDate` or `daysDelta` |
| 87   | Magic Number | LOW | `setTimeout(fn, 3600000)` | Extract: `const ONE_HOUR_MS = 3_600_000` |

### [api/handler.py] — 🔴 CRITICAL (1 smell)

| Line | Smell | Severity | Description | Fix |
|------|-------|----------|-------------|-----|
| 15–89 | Long Function + Missing Error Handling | HIGH | `process_request()` is 74 lines with no try/except around DB calls | Split into `validate_input()`, `query_db()`, `format_response()`. Wrap DB calls in try/except. |

---

### Summary

- 🟢 CLEAN: 3 files
- 🟡 MINOR: 1 file
- 🟠 REFACTOR: 0 files
- 🔴 CRITICAL: 1 file — **commit blocked until fixed**

### Recommended Fix Order
1. `api/handler.py` — CRITICAL: add error handling first, then extract functions
2. `filename.ts` — MINOR: rename variable, extract constant (quick wins)
```

### Step 5: Decide — Gate the Commit

Based on the overall status (worst file determines overall):

**🔴 CRITICAL:**
```
⛔ COMMIT BLOCKED — Critical code smells detected.
Fix the issues listed above before committing.
Run /smell again after fixing to verify.
```
- Do NOT proceed with the commit
- Offer to fix the critical issues automatically
- After fixing, re-run the smell check

**🟠 NEEDS_REFACTOR:**
```
⚠️ COMMIT WARNING — Code smells detected that should be addressed.
You may proceed if you acknowledge these are known trade-offs.
Consider creating a follow-up issue for the refactoring.
```
- Ask the user: "Proceed anyway? I can create a refactor issue."
- If user agrees, commit with a note in the commit body
- If auto-committing (agent-driven), create a TODO issue and proceed

**🟡 MINOR_SMELLS or 🟢 CLEAN:**
- Proceed with the commit without interruption
- Mention minor smells in passing but don't block

### Step 6: Log — Record Patterns

If any smells were found, append a brief entry to `knowledge/patterns.md`:

```markdown
## [DATE] — Code Smell: [Type]
- **File:** [filename]
- **Pattern:** [What was wrong]
- **Fix:** [How it was resolved]
- **Prevention:** [How to avoid this in future]
```

This builds a project-specific pattern library over time.

## Common Pitfalls

- ⚠️ **Don't over-engineer fixes** — A smell report should suggest minimal changes.
  Don't propose a full architectural rewrite for a naming issue.
- ⚠️ **Don't refactor unrelated code** — Only touch the files that are changed.
  If you spot smells in untouched files, note them separately but don't fix them now.
- ⚠️ **Don't be dogmatic about line counts** — A 35-line function that reads clearly
  is better than 5 tiny functions with confusing control flow. Use judgment.
- ⚠️ **Context matters** — A prototype/spike has different standards than production
  code. A one-off script doesn't need the same rigor as a core module.
- ⚠️ **Don't flag style preferences as smells** — Tabs vs spaces, trailing commas,
  quote style — these are linter concerns, not code smells. Focus on logic and structure.
- ⚠️ **Don't block on LOW severity alone** — Even 10 LOW smells shouldn't block a
  commit. They're informational, not actionable blockers.

## Examples

### Example: Running /smell Before a Commit

**Context:** User has staged 2 files and is about to commit.

```
User: /smell

Agent: Analyzing 2 staged files...

## 🔍 Code Smell Report — 2026-07-01

**Overall Status:** 🟡 MINOR_SMELLS
**Files Analyzed:** 2
**Smells Found:** 1

### src/utils/format.ts — 🟢 CLEAN
No smells detected. Clean code! ✨

### src/api/users.ts — 🟡 MINOR_SMELLS (1 smell)

| Line | Smell     | Severity | Description                    | Fix                          |
|------|-----------|----------|--------------------------------|------------------------------|
| 23   | Dead Code | LOW      | Unused import: `lodash.merge`  | Remove the unused import     |

### Summary
- 🟢 CLEAN: 1 file
- 🟡 MINOR: 1 file

Looks good overall. Minor note: unused import on line 23 of users.ts.
Proceeding with commit.
```

## Related Skills

- `git_workflow.md` — Smell check is Step 3 of the feature branch workflow
- `debug_loop.md` — If smells reveal potential bugs, switch to debug mode
