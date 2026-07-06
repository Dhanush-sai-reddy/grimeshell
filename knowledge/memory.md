# Agent Memory

## Current Focus
Setting up the SHELLLL terminal-first AI agent brain repository.

## User Preferences
- Terminal-first workflow — everything through CLI
- Lightweight tools preferred (no Docker, no heavy dependencies)
- CachyOS (Arch) with zsh + oh-my-zsh
- Values clean code and quality gates
- Uses Gemini (Antigravity) as primary AI backend
- agnosterzak oh-my-zsh theme
- Package manager: paru/yay
- Tools in use: fzf, lsd, git, node/npm, python3

## Recent Decisions
- 2026-07-01: Adopted git worktrees for agent sandboxing (no Docker)
- 2026-07-01: No voice input (whisper) in scope
- 2026-07-01: AXI tools over raw MCP for token efficiency
- 2026-07-01: JSON-based knowledge graph (lightweight, no database)

## Open Tasks
- [ ] Configure gh CLI authentication
- [ ] Set up No Mistakes validation pipeline
- [ ] Test agent-launch with Gemini backend
- [ ] Install tmux, gh, gh-axi, bash-mcp, no-mistakes
- [ ] Set up pre-commit hooks

## Session Log
| Date | Agent | Summary |
|------|-------|---------|
| 2026-07-01 | Gemini (Antigravity) | Initial SHELLLL brain setup |
