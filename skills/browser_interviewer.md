---
name: browser-interviewer
trigger: "web research, documentation lookup, competitive analysis, learning new tech, or when user asks to investigate a topic"
requires: [curl]
---

# Browser Interviewer — Structured Web Research

## Overview

This skill turns the agent into a disciplined researcher. Instead of giving answers
from training data (which may be outdated or wrong), it systematically gathers
information from authoritative sources, cross-references findings, and presents a
synthesized report with citations. Inspired by Matt Pocock's browser interviewer
pattern: treat every web source like an interview subject — ask specific questions,
verify claims, and note contradictions.

## Prerequisites

- [ ] `curl` is available for fetching web content, OR
- [ ] Browser tool / `read_url_content` is available for rendered page reading
- [ ] Network access is available
- [ ] Optional: `jq` for parsing JSON API responses

---

## Procedure

### Step 1: Define — Frame the Research Question

Before opening any URLs, write down exactly what you need to learn.

**Research brief format:**
```markdown
## Research Brief

**Question:** [Specific question to answer]
**Context:** [Why we need this — what project/decision depends on it]
**Scope:** [What's in/out of scope]
**Deliverable:** [What the output should look like]
**Known so far:** [What we already know, to avoid re-researching]
```

**Good questions:**
- "What is the recommended way to handle file uploads in Next.js 14 App Router?"
- "How does Prisma handle connection pooling with PostgreSQL in serverless?"
- "What are the trade-offs between Zustand vs Jotai for state management in 2026?"

**Bad questions (too vague):**
- "How does React work?"
- "What's the best database?"
- "Tell me about authentication"

**If the question is vague:** Ask the user to narrow it down. Provide 2–3
specific sub-questions they might mean.

### Step 2: Source — Identify 3–5 Authoritative Sources

Identify the best sources for the topic. Prefer primary sources over secondary.

**Source hierarchy (prefer higher):**

| Tier | Source Type                      | Examples                                  | Trust Level |
|------|----------------------------------|-------------------------------------------|-------------|
| 1    | Official documentation           | docs.prisma.io, react.dev, nodejs.org     | HIGH        |
| 2    | Author's own writing             | Blog posts by the library author          | HIGH        |
| 3    | Official examples / repos        | GitHub repos from the org                 | HIGH        |
| 4    | Reputable tech blogs             | web.dev, engineering blogs (Netflix, etc.)| MEDIUM      |
| 5    | Community answers (verified)     | Stack Overflow (accepted + high votes)    | MEDIUM      |
| 6    | Tutorials and courses            | FreeCodeCamp, Fireship, etc.              | MEDIUM      |
| 7    | Random blog posts                | Personal blogs, Medium articles           | LOW         |
| 8    | AI-generated content             | ChatGPT answers, AI blog posts            | VERY LOW    |

**Rules for source selection:**
- Always include at least 1 Tier-1 source (official docs)
- Never rely on a single source for factual claims
- Prefer sources dated within the last 12 months for fast-moving tech
- Check the date — an article from 2022 about Next.js may be completely wrong now
- For code examples: only trust sources that show the version/runtime they tested on

**Finding sources:**
```bash
# Search the web for sources:
# Use search_web tool with specific queries

# Fetch a URL's content:
# Use read_url_content tool

# For API documentation:
curl -s "https://api.example.com/docs" | head -100
```

### Step 3: Extract — Gather Key Facts from Each Source

For each source, extract these elements:

```markdown
### Source: [Title] — [URL]
**Date:** [Publication/last updated date]
**Authority:** [Tier 1-8, why]

**Key Facts:**
1. [Factual claim with specific details]
2. [Another fact — include version numbers, config values, etc.]

**Code Examples:**
\`\`\`language
// Relevant code snippet from this source
\`\`\`

**Gotchas/Warnings:**
- [Something this source warns about]
- [Edge case or limitation mentioned]

**Contradicts:** [Note if this contradicts another source, and how]
```

**Extraction rules:**
- Don't just copy-paste — distill into the key facts
- Note version numbers and dates — "works in v14" is useless if we're on v15
- Capture code examples but verify they match the current API
- Record gotchas — these are often the most valuable findings
- If a source is paywalled or empty, note that and move on

### Step 4: Cross-Reference — Compare Findings

After extracting from all sources, look for:

**Consensus (3+ sources agree):**
- These are likely reliable facts
- Note them as HIGH confidence

**Conflicts (sources disagree):**
- Flag these explicitly
- Determine which source is more authoritative/recent
- If unresolvable, present both positions with context

**Gaps (no source covers this):**
- Note what we still don't know
- Suggest where to look next (different search terms, asking a maintainer)

```markdown
### Cross-Reference Matrix

| Claim                          | Source 1 | Source 2 | Source 3 | Confidence |
|--------------------------------|----------|----------|----------|------------|
| Use Server Actions for forms   | ✅        | ✅        | ✅        | HIGH       |
| Cache invalidation uses revalidatePath | ✅ | ✅      | ❌ (uses revalidateTag) | MEDIUM |
| Connection pooling needs pgbouncer | ✅   | —        | ❌ (built-in is fine) | LOW — needs testing |
```

### Step 5: Synthesize — Build Structured Notes

Combine findings into a coherent summary. This is the primary deliverable.

```markdown
## Research Report: [Topic]

**Date:** [YYYY-MM-DD]
**Confidence:** HIGH | MEDIUM | LOW
**Sources consulted:** [N]

### Summary

[2–4 paragraph synthesis of what we learned. Lead with the answer to the
research question. Include nuance and trade-offs.]

### Key Findings

1. **[Finding]** — [Explanation with specifics] (Sources: [1, 3])
2. **[Finding]** — [Explanation] (Source: [2])
3. **[Finding]** — [Explanation, note any caveats] (Sources: [1, 2, 4])

### Recommended Approach

[Based on the findings, what should we actually DO? Be specific and
actionable. Include code snippets if relevant.]

\`\`\`language
// Recommended implementation based on research
\`\`\`

### Caveats and Unknowns

- [Something we're not sure about — needs testing]
- [Something that might change soon — track this issue/RFC]
- [Platform-specific concern]

### Sources

1. [Title](URL) — [Date] — [One-line summary of what this contributed]
2. [Title](URL) — [Date] — [Summary]
3. ...
```

### Step 6: Update — Feed Knowledge Graph

If the research revealed important entities, relationships, or patterns,
update the relevant knowledge files:

```bash
# Add to memory if this is a reusable insight:
# Append to knowledge/memory.md

# Add to patterns if this is a coding pattern:
# Append to knowledge/patterns.md

# Add to entities if new tools/libraries were discovered:
# Update knowledge/ files as needed
```

**What's worth recording:**
- Library version requirements and compatibility notes
- Configuration patterns that aren't obvious from docs
- Performance characteristics learned from benchmarks
- Common mistakes and their fixes
- Decision rationale ("We chose X over Y because Z")

### Step 7: Present — Share Findings with User

Present the research report. Adjust depth based on what the user asked:

- **Quick lookup** ("what's the syntax for X?"): Skip the full report, give the answer
  with a source link
- **Decision support** ("should we use X or Y?"): Full report with comparison matrix
- **Deep dive** ("explain how X works"): Full report, transition to `teach.md` skill
- **Implementation** ("how do we add X?"): Report + code, transition to building it

---

## Output Format

The minimum output for any research task:

```markdown
## 🔍 Research: [Topic]

**Answer:** [Direct answer to the question]

**Key Details:**
- [Important detail 1]
- [Important detail 2]

**Source:** [Primary source URL]

**Confidence:** HIGH | MEDIUM | LOW
**Caveat:** [Any important caveats]
```

The full output for comprehensive research follows the template in Step 5.

---

## Common Pitfalls

- ⚠️ **Don't trust single sources** — Even official docs can be outdated or wrong.
  Always cross-reference, especially for configuration and API details.
- ⚠️ **Don't trust training data over live sources** — The agent's knowledge has a
  cutoff. Always verify with current documentation, especially for version-specific
  features.
- ⚠️ **Verify code examples actually work** — Don't copy code from a source and
  present it without checking the API/function signatures match the current version.
  Many tutorial code examples are broken.
- ⚠️ **Check dates on everything** — A 2023 article about Next.js is probably wrong
  for Next.js 15. Note the date of every source.
- ⚠️ **Don't over-research** — Set a scope before starting. If the user asked a simple
  question, don't produce a 10-page report. Match depth to the question.
- ⚠️ **Distinguish facts from opinions** — "React is better than Vue" is an opinion.
  "React uses a virtual DOM" is a fact. Label opinions as such.
- ⚠️ **Note when you can't access a source** — If a URL is behind a paywall, returns
  a 403, or is otherwise inaccessible, say so. Don't silently skip sources.
- ⚠️ **Don't plagiarize** — Synthesize in your own words. Direct quotes should be
  short and attributed.

## Examples

### Example: Quick Documentation Lookup

**User:** "How do I use the new `use` hook in React 19?"

```
Agent:

## 🔍 Research: React 19 `use` Hook

**Answer:** The `use` hook lets you read resources (Promises, Context) during
render. It replaces `useContext` and enables Suspense-based data loading.

**Key Details:**
- `use(promise)` — unwraps a Promise, triggers Suspense boundary while pending
- `use(context)` — reads context (replaces useContext, works in conditionals)
- Can be called inside if/else and loops (unlike other hooks)
- The Promise must be created outside the component or cached

**Example:**
\`\`\`tsx
import { use, Suspense } from 'react';

function UserProfile({ userPromise }) {
  const user = use(userPromise);  // Suspends until resolved
  return <h1>{user.name}</h1>;
}

// Usage:
<Suspense fallback={<Loading />}>
  <UserProfile userPromise={fetchUser(id)} />
</Suspense>
\`\`\`

**Source:** https://react.dev/reference/react/use
**Confidence:** HIGH (official docs)
**Caveat:** The Promise must be stable across re-renders — create it in a
Server Component, route loader, or useMemo.
```

### Example: Decision Support Research

**User:** "Should I use Drizzle or Prisma for my Next.js project?"

The agent would:
1. Define question: "Trade-offs between Drizzle ORM and Prisma for Next.js 15"
2. Source: Drizzle docs, Prisma docs, comparison blog posts, benchmark data
3. Extract: Features, performance, DX, edge compatibility, migration story
4. Cross-reference: Build comparison matrix
5. Synthesize: Full report with recommendation based on project needs
6. Present: Comparison table + recommendation + code examples for both

## Related Skills

- `teach.md` — When research transitions to explaining a concept in depth
- `debug_loop.md` — When researching a bug or error message
- `code_smell.md` — When researching best practices for code quality
