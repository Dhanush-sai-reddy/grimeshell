# Architecture Decision Records

Lightweight ADR log for the SHELLLL brain repository.
Agents should consult this before proposing changes to architecture or tooling.

---

## ADR-001: Terminal-First Agent Architecture

**Date**: 2026-07-01
**Status**: Accepted
**Context**: Need a way to run AI agents that integrates with existing terminal workflow.
Alternatives considered: VS Code extension-only, web UI, Electron app.

**Decision**: All agent interactions go through the terminal. Agents launch in tmux sessions,
read context from files on disk, and use CLI tools for all operations.

**Consequences**:
- Agents must work with stdin/stdout — no GUI dependencies
- All configuration is file-based (markdown, JSON, shell scripts)
- tmux becomes a hard dependency for multi-session management
- Works over SSH, in containers, and on headless servers
- Faster iteration — no UI rebuilds needed

---

## ADR-002: Git Worktrees Over Docker for Sandboxing

**Date**: 2026-07-01
**Status**: Accepted
**Context**: Agents need isolated environments to make changes without risking the main branch.
Docker adds overhead and complexity. CachyOS is lightweight-focused.

**Decision**: Use `git worktree` to create lightweight sandboxes. Each agent gets a worktree
under `.sandboxes/` with a dedicated `sandbox/<name>` branch.

**Consequences**:
- Near-zero overhead — just filesystem links
- Agents can make changes freely, validated before merge
- No Docker, no containers, no VMs needed
- Limited isolation (shared filesystem) — acceptable for personal use
- Worktrees share the same git history, making merges trivial

---

## ADR-003: AXI Over Raw MCP for Token Efficiency

**Date**: 2026-07-01
**Status**: Accepted
**Context**: MCP (Model Context Protocol) tools work but produce verbose output that wastes
context window tokens. gh-axi provides the same GitHub operations with compressed output.

**Decision**: Prefer `gh axi` commands over raw MCP tool calls for GitHub operations.
Fall back to MCP only when AXI doesn't support a specific operation.

**Consequences**:
- Agents use fewer tokens per GitHub operation
- Depends on gh-axi extension being installed
- Must maintain awareness of AXI capability gaps
- Training/prompting must specify AXI preference

---

## ADR-004: JSON-Based Knowledge Graph (No Database)

**Date**: 2026-07-01
**Status**: Accepted
**Context**: Need a way to store structured knowledge (entities, relationships) that agents
can read and update. Options: SQLite, Redis, JSON files, YAML files.

**Decision**: Use plain JSON files (`entities.json`, `relations.json`) in `knowledge/graph/`.
No database server, no ORM, no migration system.

**Consequences**:
- Human-readable, git-diffable, zero dependencies
- Simple to parse from any language (jq, node, python)
- Won't scale past ~1000 entities (acceptable for personal brain)
- Must validate JSON integrity (knowledge-sync.sh handles this)
- No query language — agents grep/jq as needed

---

## Template

```markdown
## ADR-NNN: [Title]

**Date**: YYYY-MM-DD
**Status**: Proposed | Accepted | Deprecated | Superseded by ADR-NNN
**Context**: What problem are we solving? What constraints exist?

**Decision**: What did we decide?

**Consequences**: What are the trade-offs?
```
