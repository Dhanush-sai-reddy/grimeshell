---
name: skill-template
trigger: "when creating a new skill for the SHELLLL brain"
requires: []
---

# Skill Template — How to Write a SHELLLL Skill

> This is a **meta-skill**: a template for creating new skills.
> Copy this file, rename it, and fill in each section below.

---

## How Skills Work

A skill is a **procedure document** — a step-by-step playbook the agent follows
when a specific trigger condition is met. Skills are NOT code libraries. They are
structured instructions that turn the agent into a specialist for that task.

### File Naming

- Use `snake_case.md` for filenames: `code_smell.md`, `git_workflow.md`
- Place all skills in `/skills/` at the repo root
- One skill per file — if it's getting long, split into sub-skills

---

## YAML Frontmatter (Required)

Every skill MUST start with YAML frontmatter:

```yaml
---
name: my-skill-name          # kebab-case identifier
trigger: "description of when this skill activates"
requires: [tool1, tool2]     # CLI tools this skill depends on
---
```

### Frontmatter Fields

| Field      | Required | Description                                                      |
|------------|----------|------------------------------------------------------------------|
| `name`     | ✅        | Unique kebab-case identifier for the skill                       |
| `trigger`  | ✅        | Human-readable description of activation conditions              |
| `requires` | ✅        | List of CLI tools needed (empty `[]` if none)                    |
| `version`  | ❌        | Semantic version if you want to track skill evolution            |
| `author`   | ❌        | Who wrote this skill                                             |
| `tags`     | ❌        | Categorization tags like `[git, workflow, automation]`           |

---

## Section 1: Overview (Required)

Write 2–4 sentences explaining **what** this skill does and **why** it exists.
Keep it concrete — an agent should know within 10 seconds if this is the right
skill for the task at hand.

```markdown
## Overview

This skill guides the agent through [TASK]. It exists because [REASON].
Use it whenever [TRIGGER CONDITION IN PLAIN ENGLISH].
```

---

## Section 2: Prerequisites (Required)

List everything that must be true before the skill can run. Include tool
installation commands for the user's system.

```markdown
## Prerequisites

- [ ] `tool-name` is installed — install with `paru -S tool-name`
- [ ] Environment variable `$VAR` is set
- [ ] User has authenticated with `tool auth login`
```

---

## Section 3: Procedure (Required)

The core of the skill. Write numbered steps the agent follows **in order**.
Each step should be:

- **Concrete**: include exact commands, not vague instructions
- **Conditional**: handle branching (`if X, do Y; otherwise do Z`)
- **Observable**: describe what success/failure looks like after each step

```markdown
## Procedure

### Step 1: [Verb] — [What]

[Explanation of why this step matters]

\`\`\`bash
# Exact command to run
command --with-flags argument
\`\`\`

**Expected output:** [What you should see]
**If this fails:** [What to do instead]

### Step 2: [Verb] — [What]

[Continue with the next step...]
```

### Writing Good Steps

| ✅ Do                                      | ❌ Don't                                    |
|--------------------------------------------|---------------------------------------------|
| `git diff --name-only HEAD~1`              | "check what files changed"                  |
| "If exit code is non-zero, run X instead"  | "handle errors appropriately"               |
| "Output should contain 3 lines of JSON"    | "verify it works"                           |
| Include the exact flag: `--staged`         | "use the appropriate flags"                 |

---

## Section 4: Output Format (Recommended)

Define the structured output the skill produces. Agents work better with
predictable output shapes.

```markdown
## Output Format

\`\`\`markdown
## [Skill Name] Report — [Date]

**Status:** PASS | WARN | FAIL
**Files analyzed:** N

### Findings

| File | Issue | Severity | Line | Suggestion |
|------|-------|----------|------|------------|
| ...  | ...   | ...      | ...  | ...        |

### Summary

[1–2 sentence summary of results]
\`\`\`
```

---

## Section 5: Common Pitfalls (Recommended)

List mistakes the agent is likely to make. These act as guardrails.

```markdown
## Common Pitfalls

- ⚠️ **Don't X** — because Y. Instead, do Z.
- ⚠️ **Watch out for A** — it looks like B but behaves differently.
- ⚠️ **Never assume C** — always verify with D first.
```

---

## Section 6: Examples (Optional)

Show the skill in action with a realistic scenario.

```markdown
## Examples

### Example 1: [Scenario Name]

**Context:** [What's happening]
**Input:** [What the user said or what triggered the skill]

[Walk through the procedure with real values]

**Result:** [What the agent produced]
```

---

## Section 7: Related Skills (Optional)

Link to other skills that are often used alongside this one.

```markdown
## Related Skills

- `code_smell.md` — Run before committing to catch quality issues
- `git_workflow.md` — Full Git workflow this skill fits into
```

---

## Checklist Before Shipping a Skill

- [ ] Frontmatter has `name`, `trigger`, and `requires`
- [ ] Overview explains what and why in under 4 sentences
- [ ] Every procedure step has an exact command or clear instruction
- [ ] Failure paths are documented (not just the happy path)
- [ ] Output format is defined so the agent knows what to produce
- [ ] Common pitfalls section prevents known mistakes
- [ ] Tested the procedure manually at least once
- [ ] No placeholder text remains (search for `TODO`, `FIXME`, `...`)
