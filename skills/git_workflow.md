---
name: git-workflow
trigger: "any git operation, PR creation, issue management, or branch workflow"
requires: [git, gh]
---

# Git Workflow — GitHub CLI + AXI

## Overview

This skill defines the complete Git workflow for daily development using `git` and
GitHub CLI (`gh`). It covers the full lifecycle: branching, committing, pushing,
creating PRs, managing issues, and merging. The workflow is optimized for solo
developers and small teams working with AI agents. Use `gh-axi` when available for
token-efficient GitHub operations.

## Prerequisites

- [ ] `git` is installed and configured with user name/email
- [ ] `gh` (GitHub CLI) is installed — `paru -S github-cli`
- [ ] Authenticated with GitHub — `gh auth login`
- [ ] Repository has a remote origin configured
- [ ] Optional: `gh-axi` extension — `gh extension install anthropics/gh-axi`

**Verify setup:**
```bash
git config user.name && git config user.email  # Should show your identity
gh auth status                                  # Should show "Logged in"
gh repo view --json nameWithOwner -q .nameWithOwner  # Should show owner/repo
```

---

## Procedure 1: Feature Branch Workflow

The core development loop. Every change follows this path:

### Step 1: Sync — Start from Latest Main

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main
```

**If pull fails with conflicts:** You have local commits on main. Fix with:
```bash
git stash
git pull --rebase origin main
git stash pop
```

### Step 2: Branch — Create a Feature Branch

```bash
git checkout -b <type>/<description>
```

**Branch naming convention:**

| Type       | Use Case                              | Example                        |
|------------|---------------------------------------|--------------------------------|
| `feat/`    | New feature or capability             | `feat/add-user-auth`           |
| `fix/`     | Bug fix                               | `fix/login-redirect-loop`      |
| `refactor/`| Code restructuring, no behavior change| `refactor/extract-db-layer`    |
| `docs/`    | Documentation only                    | `docs/update-api-readme`       |
| `chore/`   | Tooling, deps, CI changes             | `chore/upgrade-node-22`        |
| `test/`    | Adding or fixing tests                | `test/add-auth-unit-tests`     |
| `perf/`    | Performance improvement               | `perf/optimize-query-n-plus-1` |
| `style/`   | Formatting, no logic change           | `style/apply-prettier`         |

**Rules:**
- Use lowercase, hyphens for spaces: `feat/add-dark-mode` not `feat/Add_Dark_Mode`
- Keep descriptions under 5 words
- Be specific: `fix/null-user-crash` not `fix/bug`

### Step 3: Develop — Write Code

Work on your feature. Make small, logical commits as you go — don't wait until
everything is done.

**During development, periodically:**
```bash
# Check what you've changed
git status
git diff --stat

# Stage specific files (prefer over `git add .`)
git add <specific-files>
```

### Step 4: Smell — Check Code Quality

Before committing, run the code smell check (see `code_smell.md`):

- If **CRITICAL**: fix before continuing
- If **NEEDS_REFACTOR**: fix or document justification
- If **MINOR/CLEAN**: proceed to commit

### Step 5: Commit — Write a Conventional Commit

```bash
git commit -m "<type>(<scope>): <description>"
```

**Conventional Commits format:**

```
<type>(<scope>): <short summary>
                  │
                  └─ Present tense. No period. Under 72 chars.

[optional body]
- What changed and why (not how — the diff shows how)
- Reference issues: Closes #42, Relates to #38

[optional footer]
BREAKING CHANGE: <description of breaking change>
```

**Type must match branch type.** Examples:

```bash
# Simple feature
git commit -m "feat(auth): add OAuth2 Google login flow"

# Bug fix with context
git commit -m "fix(api): handle null user in /profile endpoint

The /profile endpoint crashed when accessed with an expired session
token because the user lookup returned null. Added a null check with
a 401 response.

Closes #127"

# Breaking change
git commit -m "refactor(db)!: migrate from MongoDB to PostgreSQL

BREAKING CHANGE: All database queries now use SQL. The MongoDB
connection module has been removed. Run migrations with:
npx prisma migrate deploy"
```

**Commit message rules:**
- First line ≤ 72 characters
- Use present tense: "add feature" not "added feature"
- Be specific: "fix null pointer in user lookup" not "fix bug"
- Body explains **why**, not **what** (the diff shows what)
- Reference issues when applicable

### Step 6: Push — Send to Remote

```bash
# First push (sets upstream):
git push -u origin $(git branch --show-current)

# Subsequent pushes:
git push
```

**If push is rejected (remote has new commits):**
```bash
git pull --rebase origin $(git branch --show-current)
# Resolve any conflicts, then:
git push
```

### Step 7: PR — Create a Pull Request

```bash
# Interactive PR creation:
gh pr create --fill

# Full PR with all details:
gh pr create \
  --title "feat(auth): add OAuth2 Google login flow" \
  --body "## Summary
Adds Google OAuth2 authentication using Passport.js.

## Changes
- Add Google OAuth strategy configuration
- Add /auth/google and /auth/google/callback routes
- Add session persistence with express-session
- Add user model with Google profile fields

## Testing
- [ ] Manual: Sign in with Google account
- [ ] Manual: Session persists after browser restart
- [ ] Manual: Sign out clears session

Closes #42" \
  --label "feature" \
  --assignee "@me"
```

**PR best practices:**
- Title should match the conventional commit format
- Body should explain WHY, not just WHAT
- Include testing steps so reviewers can verify
- Link related issues with `Closes #N` or `Relates to #N`
- Add labels: `feature`, `bugfix`, `breaking-change`, `documentation`
- Request reviewers if applicable: `--reviewer username1,username2`

**Draft PRs for work-in-progress:**
```bash
gh pr create --draft --fill
# Later, mark as ready:
gh pr ready
```

---

## Procedure 2: Issue Management

### Creating Issues

```bash
# Quick issue:
gh issue create --title "Bug: login redirect fails on mobile" --body "..."

# With labels and assignment:
gh issue create \
  --title "feat: add dark mode toggle" \
  --body "## Description
Add a dark mode toggle to the settings page.

## Acceptance Criteria
- [ ] Toggle in settings UI
- [ ] Persists preference in localStorage
- [ ] Respects prefers-color-scheme on first visit
- [ ] Smooth transition animation" \
  --label "enhancement" \
  --assignee "@me"

# From a TODO in code (agent-driven):
gh issue create \
  --title "refactor: extract database layer from handlers" \
  --body "Found during code smell check. The handler functions directly contain SQL queries instead of using a data access layer." \
  --label "tech-debt"
```

### Listing and Filtering Issues

```bash
# All open issues:
gh issue list

# Filter by label:
gh issue list --label "bug"

# Issues assigned to you:
gh issue list --assignee "@me"

# Search with query:
gh issue list --search "auth in:title"
```

### Closing Issues

```bash
# Close with comment:
gh issue close 42 --comment "Fixed in #58"

# Close as not planned:
gh issue close 42 --reason "not planned" --comment "Decided to use a different approach"
```

---

## Procedure 3: Code Review Workflow

### Reviewing PRs

```bash
# List PRs needing review:
gh pr list --search "review-requested:@me"

# View PR details:
gh pr view 58

# Check out PR locally for testing:
gh pr checkout 58

# View the diff:
gh pr diff 58
```

### Submitting Reviews

```bash
# Approve:
gh pr review 58 --approve --body "LGTM! Clean implementation."

# Request changes:
gh pr review 58 --request-changes --body "Need error handling in the auth callback. See inline comments."

# Comment without approving/rejecting:
gh pr review 58 --comment --body "Looks good overall. A few suggestions inline."
```

### Adding Review Comments

```bash
# Comment on specific lines (use gh api for inline comments):
gh api repos/{owner}/{repo}/pulls/58/comments \
  --field body="Consider using a constant here instead of the magic number" \
  --field path="src/auth/handler.ts" \
  --field line=42 \
  --field side=RIGHT
```

---

## Procedure 4: Merge Strategies

### Squash Merge (Default for Features)

Combines all branch commits into one clean commit on main:

```bash
gh pr merge 58 --squash --delete-branch
```

**Use when:**
- Feature branches with messy intermediate commits
- Bug fixes with "try this, revert, try that" history
- You want a clean, linear main branch history

### Merge Commit (For Releases)

Preserves branch history with a merge commit:

```bash
gh pr merge 58 --merge --delete-branch
```

**Use when:**
- Release branches where you want to preserve the full history
- Large features where individual commits tell an important story

### Rebase Merge (For Small Changes)

Replays commits on top of main without a merge commit:

```bash
gh pr merge 58 --rebase --delete-branch
```

**Use when:**
- Single-commit PRs
- Documentation or config changes
- You want a perfectly linear history

### After Merging

```bash
# Switch back to main and sync:
git checkout main
git pull origin main

# Clean up stale remote tracking branches:
git fetch --prune
```

---

## Procedure 5: Using gh-axi for Token-Efficient Operations

`gh-axi` is an Anthropic extension for GitHub CLI that provides AI-assisted
operations with lower token usage.

```bash
# Install if not present:
gh extension install anthropics/gh-axi

# Use for complex queries about repos:
gh axi "summarize the last 5 PRs"
gh axi "what issues are blocking the v2 release?"
gh axi "find all TODOs in the codebase and create issues for them"
```

**When to use gh-axi vs. raw gh:**
- Use `gh` for simple, structured operations (create PR, list issues)
- Use `gh axi` for queries that need interpretation or summarization
- Use `gh axi` when you'd otherwise need multiple `gh` calls

---

## Procedure 6: Emergency Workflows

### Undo Last Commit (Not Pushed)

```bash
# Keep changes staged:
git reset --soft HEAD~1

# Keep changes unstaged:
git reset HEAD~1

# Discard changes entirely (DANGEROUS):
git reset --hard HEAD~1
```

### Undo Last Commit (Already Pushed)

```bash
# Create a revert commit (safe, preserves history):
git revert HEAD
git push
```

### Fix Commit Message

```bash
# Last commit only, not pushed:
git commit --amend -m "fix(auth): correct OAuth callback URL"

# Already pushed (CAUTION: force push):
git commit --amend -m "fix(auth): correct OAuth callback URL"
git push --force-with-lease
```

### Recover Deleted Branch

```bash
# Find the last commit on the branch:
git reflog | grep "branch-name"

# Recreate from that commit:
git checkout -b branch-name <commit-hash>
```

### Stash Work in Progress

```bash
# Save current work:
git stash push -m "WIP: auth feature halfway done"

# List stashes:
git stash list

# Restore:
git stash pop           # Most recent
git stash pop stash@{2} # Specific stash
```

---

## Quick Reference Card

```
DAILY WORKFLOW
─────────────────────────────────────────
git checkout main && git pull         sync
git checkout -b feat/my-thing         branch
  ... code ...                        develop
  /smell                              check quality
git add <files> && git commit         commit
git push -u origin $(git branch --show-current)  push
gh pr create --fill                   PR

CONVENTIONAL COMMITS
─────────────────────────────────────────
feat(scope): add new feature
fix(scope): fix a bug
refactor(scope): restructure code
docs(scope): update documentation
chore(scope): maintenance task
test(scope): add/fix tests
perf(scope): performance improvement

GH SHORTCUTS
─────────────────────────────────────────
gh pr create --fill          Quick PR
gh pr list                   List PRs
gh pr checkout N             Test a PR
gh pr merge N --squash       Squash merge
gh issue create --title "x"  New issue
gh issue list --label "bug"  Filter issues
```

## Common Pitfalls

- ⚠️ **Don't commit to main directly** — Always use a feature branch, even for
  "quick fixes." The branch provides a clean revert path.
- ⚠️ **Don't use `git add .`** — Stage specific files. This prevents accidentally
  committing debug logs, `.env` files, or unrelated changes.
- ⚠️ **Don't force push to shared branches** — Use `--force-with-lease` if you must,
  but prefer revert commits on shared branches.
- ⚠️ **Don't leave branches behind** — Delete merged branches. Use `--delete-branch`
  with merge commands. Run `git fetch --prune` regularly.
- ⚠️ **Don't write commit messages in past tense** — "add feature" not "added feature."
  Think of it as completing the sentence: "This commit will..."
- ⚠️ **Don't squash when history matters** — Release branches and large features
  benefit from preserved history. Use merge commits for those.

## Related Skills

- `code_smell.md` — Run before Step 5 (commit) to gate quality
- `debug_loop.md` — When a bug is found during code review
- `tmux_session.md` — Run git operations in a dedicated pane
