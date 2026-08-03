---
name: feature-ship
description: Use when validation passed (status to-ship) — checks shared-context readiness, commits, cleans shared-context, migrates durable constraints to guidelines, runs retro. Does NOT push or create the PR. Accepts optional feature name: /feature-ship [feature-name].
---

# Feature Ship

Readiness checklist, commit, shared-context cleanup, constraint migration, retro. Push and PR remain manual.

## When to use

After `feature-validate` returned GO + PASS overall (status `to-ship` in the tracking file).

## Steps

### 0. Identify the feature

- If a `feature-name` was provided as argument (`/feature-ship feature-name`) → look for `.scratch/*feature-name*.md`
- Otherwise → scan `.scratch/` and take the most recent `.md` outside of `done/`, then verify its status is `to-ship`

If the most recent file does not have status `to-ship`, warn: "The most recent file does not have status `to-ship` — is this the feature you want to ship?" and wait for confirmation before continuing.

### 0b. Detect environment paths

Check whether `.claude/` exists at the project root:
- If yes → **Claude mode**: rules file = `.claude/CLAUDE.md`, guidelines directory = `.claude/guidelines/`
- If no → **Generic mode**: rules file = `.agents/guidelines/project-rules.md`, guidelines directory = `.agents/guidelines/`

Use `<rules-file>` and `<guidelines-dir>` as shorthand for these paths in all steps below.

---

### 1. Readiness check

Read `.scratch/shared-context.md` in full.

Retrieve the files touched by this feature: `git diff main...HEAD --name-only`

**File overlap:**
Are there `IN_PROGRESS` branches in "Merge readiness" whose touched files overlap with this feature's files?

**Declared dependencies:**
Are there branches that declare `Waiting for: [this branch]` in "Merge readiness"?

**APIs:**
Are there entries in "API & Contracts modified" by other branches that are not yet accounted for in this feature's code?

**Constraints:**
Are there entries in "Constraints discovered" that apply to this feature's scope without having been addressed?

**Verdict:**
- **✓ OK to ship** — no blocking point
- **⚠ Blocking: [precise reason]** — if a point blocks

If blocking: explain the issue and wait for human confirmation before continuing.

### 2. Commit

Message: `type(scope): short description` — the description explains the WHY, not the what.

Move `.scratch/DD-MM-YYYY-[feature-name].md` to `.scratch/done/`.

The shared-context.md cleanup (step 3) is included in this same commit.

### 3. Clean shared-context.md

**"Merge readiness" section** → remove the line for this branch.

**"API & Contracts modified" section** → remove the section for this branch (the change is now in the committed code).

**"Constraints discovered" section** → for each constraint from this branch, apply the decision tree:

```
Is the constraint durable (beyond this feature)?
│
├─ No → delete
│
└─ Yes → identify the right destination:
    │
    ├─ Lib / framework / external API / version
    │   → <guidelines-dir>/language-framework.md
    │
    ├─ Team convention / test pattern / naming rule
    │   → <guidelines-dir>/team-practices.md
    │
    ├─ External tool (design system, internal API...)
    │   → dedicated guideline (create if it doesn't exist)
    │
    └─ Cross-cutting project rule (security, perf, global behaviour)
        → <rules-file>

    → Migrate to the destination, then delete from shared-context.md
```

**"Decisions & Conventions" section** → always durable, always migrate. Identify the right destination based on the nature of the decision:

```
Nature of the decision?
│
├─ Architecture pattern, file organisation, naming convention
│   → <guidelines-dir>/team-practices.md
│
├─ Framework or library-related pattern
│   → <guidelines-dir>/language-framework.md
│
└─ Structural decision for the whole project (design system, internal API, cross-cutting tool)
    → dedicated guideline (create if it doesn't exist)

→ Migrate to the destination, then delete from shared-context.md
```

### 4. Light retro

Answer these three questions:
- What slowed down the loop on this feature?
- Would a configuration have prevented that slowdown?
- Was the initial plan precise enough?

### 4b. Update configurations if needed

If any answer above indicates that a configuration was missing or insufficient, identify and immediately update the relevant files:
- `<rules-file>` → cross-cutting rules (security, global behaviour)
- `<guidelines-dir>/team-practices.md` → team conventions, test patterns, naming
- `<guidelines-dir>/language-framework.md` → stack constraints, APIs, versions

Include these changes in this feature's commit (same commit as step 2).

## End of skill

Commit done, shared-context cleaned.
Push and PR creation are yours to do.
