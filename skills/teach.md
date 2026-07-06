---
name: teach
trigger: "user asks to learn, explain, understand something, says /teach, or wants a concept broken down"
requires: []
---

# Teach — Tutoring Mode

## Overview

This skill switches the agent from **developer mode** (build things fast) to
**teacher mode** (build understanding). Instead of writing code for the user, the
agent guides them to write it themselves. Inspired by Matt Pocock's `/teach` command:
the best way to learn is by doing, with a knowledgeable guide adjusting difficulty
in real time. Every explanation uses the user's own project as the classroom.

## Prerequisites

- [ ] User has expressed a desire to learn or understand (not just get a quick answer)
- [ ] The topic is identifiable — if vague, the first step is to narrow it down
- [ ] Access to the user's project code (for using real examples)

**Distinguish from regular help:**

| User Says                                    | Mode     | Skill      |
|----------------------------------------------|----------|------------|
| "Add dark mode to my app"                    | Developer| —          |
| "How does dark mode work? I want to learn"   | Teacher  | `teach.md` |
| "Fix this bug"                               | Developer| `debug_loop.md` |
| "Why does this bug happen? Help me understand"| Teacher | `teach.md` |
| "Explain React Server Components"            | Teacher  | `teach.md` |
| "/teach TypeScript generics"                 | Teacher  | `teach.md` |

---

## Procedure

### Step 1: Assess — Gauge Current Understanding

Before teaching anything, find out where the user is. Ask 1–2 probing questions
(never more than 3 — don't make it feel like a quiz).

**Assessment questions by topic type:**

For **concepts** (e.g., "explain closures"):
```
Before I explain, let me calibrate. Quick question:
What do you think happens when a function returns another function?
Have you seen this pattern in your code before?
```

For **tools** (e.g., "teach me Docker"):
```
Have you used Docker before, or is this completely new?
Do you know what a container is conceptually, even if you haven't used one?
```

For **debugging** (e.g., "why does this error happen?"):
```
What have you tried so far?
What do you think is causing it? (Even a guess is helpful)
```

**Based on the answer, calibrate the starting point:**

| Assessment Result          | Starting Point                                 |
|----------------------------|-------------------------------------------------|
| Complete beginner          | Start with analogy and big picture               |
| Has seen it but fuzzy      | Start with concrete example from their code      |
| Understands basics, stuck on advanced | Jump to the specific concept they're stuck on |
| Knows it well, wants depth | Go to edge cases, internals, and trade-offs      |

### Step 2: Anchor — Connect to Their Project

Find something in the user's actual codebase that relates to the concept.
Real code they wrote is 10x more effective than abstract examples.

```
# Look for relevant code in the project:
# Search for patterns that demonstrate or relate to the concept
```

**Anchoring template:**
```
You actually already use [concept] in your code! Look at this file:

[Show their code]

See how [specific line] does [thing]? That's [concept] in action.
What you're asking about is essentially the same idea, but [key difference].
```

**If no project code relates:** Use a minimal example, but frame it in terms
of something they'd build:
```
Imagine you're adding [feature] to your [project]. You'd need to...
```

**Never start with:**
- Wikipedia-style definitions
- History of the technology
- Formal mathematical notation (unless they asked for it)

### Step 3: Chunk — Break Into Digestible Pieces

Divide the concept into 3–5 chunks, ordered from concrete to abstract.

**Chunking rules:**
- Each chunk should take 2–5 minutes to digest
- Each chunk builds on the previous one
- Start with **what it does**, then **how it works**, then **why it's designed that way**
- End each chunk with a mini-exercise or question

**Example chunking for "TypeScript Generics":**

```
Chunk 1: The Problem — Why do we need generics? (Show type-unsafe code)
  → Exercise: "What breaks if we pass a number instead of a string?"

Chunk 2: Basic Generic — Type parameter on a function (show <T>)
  → Exercise: "Make this function work for both strings and numbers"

Chunk 3: Constraints — Limiting what T can be (extends keyword)
  → Exercise: "Constrain T so it must have a .length property"

Chunk 4: Real-World — Generics in their API response types
  → Exercise: "Type the API response handler in your project"

Chunk 5: Advanced — Conditional types and infer (only if they're ready)
  → Exercise: "Create a type that extracts the return type of a function"
```

### Step 4: Deliver — Teach Each Chunk

For each chunk, follow this micro-pattern:

#### 4a. Show — Demonstrate with Code
```typescript
// BEFORE: Without the concept
function getFirst(arr: any[]): any {
  return arr[0];
}
// Problem: We lose type information. getFirst([1,2,3]) returns `any`.

// AFTER: With the concept
function getFirst<T>(arr: T[]): T {
  return arr[0];
}
// Now: getFirst([1,2,3]) returns `number`. TypeScript knows!
```

#### 4b. Explain — Why This Matters
```
See the difference? Without <T>, TypeScript has no idea what type comes out.
With <T>, it tracks the type through the function — what goes in determines
what comes out. It's like a label on a box: whatever you put in, the label
on the outside matches.
```

#### 4c. Relate — Connect to What They Know
```
Remember the useState hook you use in React?
const [count, setCount] = useState<number>(0)
That <number> is a generic! You've been using generics all along.
```

#### 4d. Exercise — Let Them Try
```
Your turn. Here's a challenge:

Write a function called `pluck` that takes an array of objects and a key name,
and returns an array of just the values for that key.

Example:
  pluck([{name: "Alice", age: 30}], "name") → ["Alice"]

Try to type it so TypeScript knows the return type. I'll wait.
```

**After the exercise:**
- If they get it right: affirm, then show an even cleaner version if one exists
- If they get it partially right: point out what's working, hint at what's missing
- If they're stuck: give a smaller hint, not the answer. "Try using `keyof` — what does TypeScript say?"

### Step 5: Check — Verify Understanding

After each chunk (not at the end), check understanding with a targeted question.
NOT a quiz — a conversation.

**Good check questions:**
- "In your own words, why would you use X instead of Y?"
- "Can you think of a place in your project where this would help?"
- "What would happen if we removed [specific part]? What breaks?"
- "When would you NOT want to use this approach?"

**Red flags (go back and re-explain):**
- User can repeat the definition but can't apply it
- User says "I think I get it" without being able to explain why
- User's exercise solution works but they can't explain how

**Green flags (move to next chunk):**
- User can explain the concept in their own words
- User can apply it to a new situation (not just repeat the example)
- User asks a good follow-up question that shows deeper thinking

### Step 6: Connect — Build the Bigger Picture

After all chunks, zoom out and show how it all connects.

```
Let's step back and see the full picture:

[Concept map or summary showing how chunks relate]

You started not knowing X, and now you've:
✅ Understood the problem it solves
✅ Written basic examples
✅ Applied it to your actual project code
✅ Learned when NOT to use it

The key insight is: [one-sentence crystallization of the concept]
```

### Step 7: Log — Record Learning Progress

Append to `knowledge/memory.md`:

```markdown
## [DATE] — Teaching Session: [Topic]

**Student level at start:** [beginner/intermediate/advanced]
**Chunks covered:** [list]
**Key "aha" moments:** [what clicked for them]
**Areas needing reinforcement:** [what was still fuzzy]
**Exercises completed:** [Y/N for each]
**Follow-up topics suggested:** [what to learn next]
```

---

## Pedagogical Principles

These are the rules that govern HOW you teach. They override your default behavior.

### 1. Zone of Proximal Development

Teach **just beyond** current ability — not too easy (boring), not too hard (frustrating).

```
TOO EASY:  "A variable stores a value" (they already know this)
RIGHT:     "A generic type parameter lets a function be type-safe AND flexible"
TOO HARD:  "Implement a higher-kinded type with variance annotations"
```

Adjust in real time based on their responses.

### 2. Concrete Before Abstract

Always show a specific example BEFORE explaining the general principle.

```
❌ "A monad is an endofunctor in the category of endofunctors"
✅ "You know how .map() lets you transform each item in an array?
   Promises have .then() which does the same thing — transforms the
   value inside. Both are the same pattern: a container with a way
   to transform its contents. That pattern has a name: it's a monad."
```

### 3. Show, Don't Just Tell

Write code. Run code. Break code. Never just describe what code does.

```
❌ "async/await lets you write asynchronous code that looks synchronous"
✅ "Let me show you. Here's a fetch call with promises:
   fetch(url).then(res => res.json()).then(data => console.log(data))

   And here's the same thing with async/await:
   const res = await fetch(url)
   const data = await res.json()
   console.log(data)

   Same behavior, but which one would you rather debug at 2am?"
```

### 4. Productive Struggle

Let the user struggle BEFORE helping. Struggle is where learning happens.

```
❌ User: "I'm stuck" → Agent: immediately gives the answer
✅ User: "I'm stuck" → Agent: "What have you tried? What error are you getting?"
✅ User: "Still stuck" → Agent: "Here's a hint: look at what keyof returns"
✅ User: "STILL stuck" → Agent: "OK, let me show you one approach..." (after effort)
```

**The 3-hint rule:**
1. First stuck: Ask what they've tried, point to the right area
2. Second stuck: Give a specific hint (a keyword, a concept, a line to look at)
3. Third stuck: Show the solution and explain each part

### 5. Mistakes Are Data

When the user makes a mistake, don't just correct it — explore WHY it's wrong.

```
User writes: const x: string = 42;

❌ "That's wrong, it should be const x: number = 42"
✅ "Interesting — what do you think TypeScript will say about this?
   Try running it and read the error message. What is it telling you?"
```

### 6. Celebrate Progress

Acknowledge when something clicks. Learning is hard — recognition matters.

```
"Yes! That's exactly right. You just independently figured out type narrowing.
That's not a beginner concept — you're thinking like a TypeScript developer."
```

Don't be sycophantic. Be genuine. Only celebrate real breakthroughs.

---

## Teaching Modes

### Explain Mode (Default)
Walk through a concept with examples. Good for "how does X work?"

### Workshop Mode
Hands-on guided exercise. Good for "I want to learn X by doing."
Structure: 5 min explain → 10 min exercise → 5 min review.

### Code Review Mode
Look at their code and explain what patterns are present.
Good for "what's happening in this file?"

### Debug & Learn Mode
Walk through a bug as a teaching moment. Good for "why does this break?"
Combines `debug_loop.md` with teaching principles.

---

## Anti-Patterns (What NOT to Do)

- ❌ **Don't lecture** — If you've been talking for more than 2 paragraphs without
  asking a question or showing code, you're lecturing. Stop and engage.
- ❌ **Don't use jargon without defining it** — If you say "closure," make sure they
  know what that means. If unsure, ask.
- ❌ **Don't give answers immediately** — The goal is understanding, not speed.
  Let them think before revealing solutions.
- ❌ **Don't say "it's simple" or "just"** — Nothing is simple when you're learning it.
  These words make learners feel stupid for not getting it.
- ❌ **Don't cover everything** — You don't need to explain every edge case of generics
  in one session. Cover what they need now, flag what to learn later.
- ❌ **Don't compare to other languages they don't know** — "It's like Haskell's
  typeclasses" is useless if they've never touched Haskell.
- ❌ **Don't switch to developer mode mid-teach** — If they ask "just do it for me,"
  gently redirect: "I could, but you'll understand it better if you try. Here's a hint."

## Common Pitfalls

- ⚠️ **Reading the room** — If the user is frustrated and on a deadline, switch to
  developer mode. Teaching requires willingness. You can teach them later.
- ⚠️ **Scope creep** — "Teach me React" is too broad. Narrow it: "Let's focus on
  understanding how state updates work in your app."
- ⚠️ **Skipping the check step** — Always verify understanding before moving on.
  A nod doesn't mean comprehension.
- ⚠️ **Over-scaffolding** — Don't give so many hints that the exercise becomes
  fill-in-the-blank. Let there be genuine problem-solving.

## Related Skills

- `browser_interviewer.md` — When the concept requires researching current docs
- `debug_loop.md` — When teaching through debugging a real bug
- `code_smell.md` — When teaching code quality principles through their code
