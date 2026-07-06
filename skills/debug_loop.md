---
name: debug-loop
trigger: "bugs, errors, unexpected behavior, test failures, crashes, or user says /debug"
requires: [git]
---

# Debug Loop — Systematic Debugging

## Overview

This skill enforces a disciplined debugging process. Instead of random guessing
(shotgun debugging), it follows a structured loop: REPRODUCE → ISOLATE → HYPOTHESIZE
→ TEST → FIX → VERIFY → DOCUMENT. Every step must complete before moving to the next.
The #1 rule: **never fix what you can't reproduce, never guess what you can test.**

## Prerequisites

- [ ] `git` is available for bisect, stash, and diff operations
- [ ] The bug is reported with enough detail to start investigating
- [ ] The project builds/runs (if it doesn't, fix that first)

---

## Procedure

### Step 1: REPRODUCE — Can You Reliably Trigger the Bug?

**This step is non-negotiable.** You cannot debug what you cannot reproduce.

#### Gather Bug Information

```markdown
## Bug Report

**Observed behavior:** [What actually happens]
**Expected behavior:** [What should happen]
**Steps to reproduce:**
1. [Exact step]
2. [Exact step]
3. [Bug manifests here]

**Environment:**
- OS: [e.g., CachyOS Linux]
- Runtime: [e.g., Node 22.x, Python 3.12]
- Browser: [if applicable]
- Relevant versions: [framework, library versions]

**Error output:**
\`\`\`
[Exact error message, stack trace, or log output]
\`\`\`

**Frequency:** Always | Sometimes | Once (unable to reproduce yet)
**Regression:** Was this working before? When did it break?
```

#### Reproduce the Bug

```bash
# Run the failing scenario exactly as reported:
# [exact command or steps]

# Verify: did you see the same error?
# If YES → proceed to Step 2
# If NO → the bug is environment-specific or intermittent
```

**If you CANNOT reproduce:**
1. Check environment differences (versions, OS, config)
2. Check for race conditions (add logging, try with delays)
3. Check for state-dependent bugs (database state, cache, cookies)
4. Ask the user for more details — screen recording, exact sequence
5. If still unreproducible after 15 minutes, document what you tried and escalate

**If the bug is intermittent:**
- Add logging around the suspected area
- Try to increase frequency (load testing, rapid repeated execution)
- Look for timing issues, race conditions, or resource exhaustion
- Note: intermittent bugs are often the hardest — budget extra time

**Output of this step:**
```markdown
**Reproduction:** ✅ Confirmed | ❌ Cannot reproduce | ⚡ Intermittent
**Reproduction steps:** [Minimal steps that trigger the bug every time]
**Reproduction rate:** [X out of Y attempts]
```

### Step 2: ISOLATE — Narrow to the Smallest Failing Unit

The goal: go from "the app is broken" to "line 47 in handler.ts is broken."

#### Strategy A: Binary Search (Top-Down)

Start broad, cut in half each time:

```
Is the bug in the frontend or backend?
  → Backend
Is it in the API handler or the database layer?
  → API handler
Is it in request parsing or response formatting?
  → Request parsing
Is it in the JSON parsing or the validation?
  → Validation — line 47 validates email format incorrectly
```

#### Strategy B: Git Bisect (For Regressions)

If the bug used to work and now doesn't:

```bash
# Start bisect:
git bisect start

# Mark current (broken) commit as bad:
git bisect bad

# Mark a known-good commit (when it last worked):
git bisect good <commit-hash-or-tag>

# Git checks out a middle commit. Test it:
# [run reproduction steps]
# If bug exists:
git bisect bad
# If bug doesn't exist:
git bisect good

# Repeat until git identifies the first bad commit:
# "abc1234 is the first bad commit"

# End bisect:
git bisect reset
```

**Automated bisect (if you have a test):**
```bash
git bisect start
git bisect bad HEAD
git bisect good v1.0.0
git bisect run npm test -- --grep "test that fails"
```

#### Strategy C: Minimal Reproduction

Strip away everything until only the bug remains:

1. Comment out unrelated code
2. Hardcode inputs instead of using real data
3. Remove middleware, plugins, decorators one by one
4. If the bug disappears when you remove X, X is involved
5. Create a minimal script that demonstrates the bug in isolation

```bash
# Create a minimal repro script:
cat > /tmp/repro.js << 'EOF'
// Minimal reproduction of the bug
// This should be < 20 lines if possible
const result = buggyFunction(specificInput);
console.log(result); // Shows the bug
EOF
node /tmp/repro.js
```

#### Strategy D: Diff Analysis

If you suspect a recent change caused it:

```bash
# What changed recently?
git log --oneline -10

# What files changed in the last N commits?
git diff --name-only HEAD~5

# Show changes in the suspected file:
git diff HEAD~5 -- src/handler.ts

# Show the blame for the buggy line:
git blame src/handler.ts -L 45,50
```

**Output of this step:**
```markdown
**Isolated to:** [file:line or function name]
**Isolation method:** [bisect | binary search | minimal repro | diff analysis]
**Related code:**
\`\`\`
[The specific code that's causing the bug]
\`\`\`
```

### Step 3: HYPOTHESIZE — Form 2–3 Theories

Don't jump to fixing. Generate multiple theories and rank them.

**Hypothesis format:**
```markdown
### Hypotheses (ranked by likelihood)

1. **[Most likely]** — [Theory about root cause]
   - Evidence for: [What supports this theory]
   - Evidence against: [What contradicts this theory]
   - Test: [How to confirm or deny this]

2. **[Second most likely]** — [Theory]
   - Evidence for: [...]
   - Evidence against: [...]
   - Test: [...]

3. **[Least likely but possible]** — [Theory]
   - Evidence for: [...]
   - Evidence against: [...]
   - Test: [...]
```

**Hypothesis generation checklist:**
- Is the input what we expected? (Bad data in)
- Is the logic correct? (Bad computation)
- Is the environment different? (Works on my machine)
- Is there a race condition? (Timing-dependent)
- Is it a type error? (Especially in dynamic languages)
- Is it a null/undefined/None issue? (Missing data)
- Is it an off-by-one error? (Boundary conditions)
- Is it a state mutation issue? (Shared mutable state)
- Is it a dependency version issue? (API changed)
- Is it a configuration issue? (Wrong env var, missing setting)

**Rules:**
- Always generate at least 2 hypotheses — if you can only think of one, you're anchored
- The most "obvious" fix is wrong ~40% of the time
- Consider non-code causes: infrastructure, data, timing, environment

### Step 4: TEST — Confirm or Deny Top Hypothesis

Design a test that **specifically** confirms or denies hypothesis #1.

```bash
# Add targeted logging:
console.log('DEBUG [handler.ts:47]', { email, validationResult, typeof_email: typeof email });

# Or write a unit test:
test('email validation handles null input', () => {
  expect(validateEmail(null)).toBe(false);  // If this passes, hypothesis is wrong
});

# Or modify the code temporarily:
# Hardcode the suspected bad value and see if the bug reproduces
```

**Testing rules:**
- The test must be **dispositive** — it clearly says YES or NO to the hypothesis
- Don't test multiple hypotheses at once — you won't know which one was confirmed
- If hypothesis #1 is denied, move to hypothesis #2
- If ALL hypotheses are denied, go back to Step 2 (your isolation was too broad)

**Output of this step:**
```markdown
**Hypothesis tested:** #[N] — [description]
**Test performed:** [What you did]
**Result:** ✅ Confirmed | ❌ Denied
**Root cause:** [If confirmed, the actual root cause]
```

### Step 5: FIX — Apply a Minimal Fix

Now — and ONLY now — write the fix.

**Fix rules:**
1. **Minimal change** — Fix the bug and nothing else. Don't refactor while fixing.
2. **One logical change** — The fix should be explainable in one sentence.
3. **Don't fix symptoms** — Fix the root cause. A try/catch around a null pointer
   is a bandaid, not a fix.
4. **Preserve behavior** — The fix should change the broken behavior to the expected
   behavior. It should NOT change any other behavior.

```bash
# Make the fix:
# [edit the specific file/line]

# Stage ONLY the fix:
git add <specific-file>

# Don't stage unrelated changes
```

**Fix validation checklist:**
- [ ] The fix addresses the root cause identified in Step 4
- [ ] The fix is the smallest change that resolves the issue
- [ ] No unrelated code was modified
- [ ] The fix doesn't introduce new warnings or type errors

### Step 6: VERIFY — Confirm the Fix Works

Run the exact reproduction steps from Step 1:

```bash
# Reproduce the original bug:
# [exact same steps as Step 1]

# Expected: bug no longer occurs
# If bug still occurs: go back to Step 3, your root cause was wrong

# Run the test suite:
npm test           # or pytest, go test, cargo test, etc.

# Run the specific test you wrote in Step 4:
npm test -- --grep "email validation handles null input"

# Check for regressions:
git stash           # Temporarily revert fix
# [run tests]       # Do they fail on the bug? (They should)
git stash pop       # Restore fix
# [run tests]       # Do they pass? (They should)
```

**Verification requirements:**
- [ ] Original bug no longer reproduces
- [ ] Test suite passes (no regressions)
- [ ] The specific test for this bug passes
- [ ] Manual smoke test of related features passes
- [ ] Fix works in the same environment where the bug was reported

**If verification fails:**
- The root cause hypothesis was wrong or incomplete
- Go back to Step 3 and re-hypothesize
- This counts as one "fix attempt" (see Escalation rules)

### Step 7: DOCUMENT — Record for Future Prevention

Append to `knowledge/mistakes.md`:

```markdown
## [DATE] — Bug: [Short Description]

**Symptom:** [What the user saw]
**Root Cause:** [The actual underlying problem]
**Fix:** [What was changed, with file:line reference]
**Prevention:** [How to prevent this class of bug in the future]
**Time to fix:** [How long it took from report to fix]
**Hypotheses tried:** [N] (correct was #[N])

### Lessons Learned
- [What this bug teaches about the codebase]
- [What process improvement could catch this earlier]
```

**Commit the fix:**
```bash
git commit -m "fix(<scope>): <description of what was fixed>

Root cause: <one-line explanation of why it was broken>
Closes #<issue-number>"
```

---

## Escalation Rules

### The 3-Attempt Rule

If you've tried 3 different fixes and none of them work:

```
🛑 ESCALATION — I've attempted 3 fixes without success.

Here's what I've tried:
1. [Fix attempt 1] — [Why it didn't work]
2. [Fix attempt 2] — [Why it didn't work]
3. [Fix attempt 3] — [Why it didn't work]

My current best theory is: [theory]

I recommend:
- [ ] Getting a second pair of eyes on this
- [ ] Checking [specific external factor] that I can't test
- [ ] Considering whether this is a known issue in [dependency]
```

**STOP and ask the user.** Don't keep trying — you're likely anchored on the wrong
root cause.

### The Time Box Rule

If you've been debugging for more than 30 minutes on a single bug:
- Summarize what you know so far
- Document your hypotheses and test results
- Ask the user if this is worth continuing or if there's a workaround

### The Severity Rule

Not all bugs need the full loop:

| Severity   | Process                                     |
|------------|---------------------------------------------|
| **Trivial**| Typo, missing import — fix directly, skip Steps 3-4 |
| **Minor**  | Small logic error — abbreviated loop         |
| **Major**  | Feature broken — full loop                   |
| **Critical**| App crash, data loss — full loop + immediate escalation |

---

## Anti-Patterns — What NOT to Do

### ❌ Shotgun Debugging
Making random changes hoping something works.
```
"Let me try changing this... nope. How about this... nope. Maybe if I..."
```
**Instead:** Form a hypothesis FIRST, then make ONE targeted change.

### ❌ Fixing Symptoms Not Causes
```
// BAD: Swallowing the error
try {
  riskyOperation();
} catch (e) {
  // TODO: figure this out later
}

// GOOD: Understanding and handling the error
try {
  riskyOperation();
} catch (e) {
  if (e instanceof ValidationError) {
    return { error: e.message, field: e.field };
  }
  throw e; // Re-throw unexpected errors
}
```

### ❌ Not Reproducing First
"I think I know what's wrong" → changes code → introduces new bug.
**Always reproduce first.** Your intuition is wrong 40% of the time.

### ❌ Changing Multiple Things at Once
Changed 3 files to fix the bug. Now it works. But which change fixed it?
**One change at a time.** Test after each change.

### ❌ Not Reverting Failed Fixes
Tried a fix, it didn't work, left the code in. Now there are TWO problems.
**Always revert failed fixes** before trying the next approach.
```bash
git checkout -- <file>   # Revert unstaged changes
git stash                # Or stash if you might need them later
```

### ❌ Debugging in Production
Making changes to live systems to "test" a fix.
**Always debug locally** with production-like data if needed.

### ❌ Printf Debugging Without Cleanup
Adding 47 console.log statements and forgetting to remove them.
```bash
# After fixing, clean up debug logging:
git diff --cached | grep "console.log\|print(\|debugger" # Should find nothing
```

---

## Quick Reference

```
THE DEBUG LOOP
─────────────────────────────────────────
1. REPRODUCE  → Can you trigger it reliably?
2. ISOLATE    → What specific code is failing?
3. HYPOTHESIZE → Why might it be failing? (2-3 theories)
4. TEST       → Which theory is correct?
5. FIX        → Minimal change to fix root cause
6. VERIFY     → Bug gone? Tests pass? No regressions?
7. DOCUMENT   → Log to knowledge/mistakes.md

RULES
─────────────────────────────────────────
- Never fix what you can't reproduce
- Never guess what you can test
- One change at a time
- Revert failed fixes
- Escalate after 3 attempts
- Time-box at 30 minutes

GIT TOOLS
─────────────────────────────────────────
git bisect start/bad/good   Find regression commit
git blame file -L N,M       Who changed these lines
git log --oneline -10       Recent changes
git diff HEAD~5 -- file     What changed recently
git stash / git stash pop   Save/restore work
```

## Common Pitfalls

- ⚠️ **Confirmation bias** — You'll naturally seek evidence for your first theory.
  Actively try to DISPROVE your hypothesis, not prove it.
- ⚠️ **Premature optimization of the fix** — Get it working first, make it pretty
  later. A correct ugly fix beats a beautiful wrong fix.
- ⚠️ **Debugging the wrong thing** — Make sure the error you're seeing is the ACTUAL
  problem, not a cascade from an earlier failure. Read the FIRST error in the stack.
- ⚠️ **Stale state** — Clear caches, restart servers, rebuild. Many "bugs" are just
  stale builds or cached data.
- ⚠️ **Environment differences** — "Works on my machine" is real. Check Node version,
  env vars, file permissions, OS differences.

## Related Skills

- `code_smell.md` — Run after fixing to ensure fix quality
- `git_workflow.md` — Commit the fix using proper workflow
- `teach.md` — If the user wants to understand the bug, switch to teaching mode
