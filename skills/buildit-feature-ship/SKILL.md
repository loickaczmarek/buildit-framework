---
name: buildit-feature-ship
description: "Use when validation passed (status to-ship) — checks shared-context readiness, commits, cleans shared-context, migrates durable constraints to guidelines, runs retro. Does NOT push or create the PR. Accepts optional feature name: /buildit-feature-ship [feature-name]."
---

# Feature Ship

Readiness checklist, commit, shared-context cleanup, constraint migration, retro. Push and PR remain manual.

## When to use

After `buildit-feature-validate` returned GO + PASS overall (status `to-ship` in the tracking file).

## Running as a subagent

When launched as a subagent (e.g. by `buildit-feature-run`), no human can answer. Any step below that says to wait for confirmation returns the blocked signal instead:
- Do not commit, do not move the tracking file, and leave the status `to-ship`.
- Add a `## Last error` section to the tracking file with the single line `buildit-feature-ship: blocked — <precise reason>`.
- End with a final message starting with `SHIP BLOCKED: <precise reason>`.

## Steps

### 0. Identify the feature

- If a `feature-name` was provided as argument (`/feature-ship feature-name`) → look for `.scratch/*feature-name*.md`
- Otherwise → scan `.scratch/` and take the most recent `.md` outside of `done/`, then verify its status is `to-ship`

If the most recent file does not have status `to-ship`, warn: "The most recent file does not have status `to-ship` — is this the feature you want to ship?" and wait for confirmation before continuing (as a subagent: return the blocked signal — see "Running as a subagent").

If the tracking file has a `## Last error` section, remove it: it describes a previous run.

**Feature branch:** read the `## Branch` value from the tracking file (the line below the heading, a bare branch name — contract in `buildit-feature-start` step 3) and store it as `<feature-branch>`. Legacy tracking file without `## Branch`: fall back to `git -C <worktree-path> branch --show-current` in worktree mode, `git branch --show-current` otherwise, and warn once: "No `## Branch` in the tracking file — using the checked-out branch `<feature-branch>`."

**Working directory:** `.scratch/` and `.buildit/config.md` are always read and written in the project root, even in worktree mode. Read `## Worktree path` from the tracking file: if it is not `none`, edit code files inside the worktree and run every git command on feature code (`add`, `status`, `diff`, `commit`, `commit --amend`) with `git -C <worktree-path>` — each worktree has its own index, so staged work is only visible there.

### 0a. Prerequisite check

If `.scratch/shared-context.md` does not exist, stop with:
> "Shared context file not found — run `/buildit-project-bootstrap` to initialize the project."

### 0b. Detect environment paths

Determine your operating mode from your agent identity:
- You are a **Claude / Claude Code** agent → **Claude mode**: `<rules-file>` = `.claude/CLAUDE.md`
- You are any **other agent** (Copilot, generic) → **Generic mode**: `<rules-file>` = `.agents/guidelines/project-rules.md`

In all cases: `<guidelines-dir>` = `.buildit/guidelines/`

**Migration note:** If `.buildit/guidelines/` does not exist but `.claude/guidelines/` or `.agents/guidelines/` does, warn the user:
> "Guidelines found at [old-path] instead of `.buildit/guidelines/`. Run `/buildit-project-bootstrap` to migrate them before continuing."
Then stop.

Use `<rules-file>` and `<guidelines-dir>` as shorthand for these paths in all steps below.

---

### 1. Readiness check

Read `.scratch/shared-context.md` in full.

**Base branch:** read `.buildit/config.md` and take the first non-empty, non-comment line after the `## Base branch` heading, read only within that heading (stop at the next heading); a line starting with `#` is never a value (Config value rule, `.buildit/guidelines/language-framework.md`), as `<base-branch>`. If the file or the heading is absent, or the heading is empty, `<base-branch>` defaults to `main`. If `git rev-parse --verify <base-branch>` fails, stop with: "Base branch `<base-branch>` not found locally — set `## Base branch` in `.buildit/config.md` or fetch the branch."

Retrieve the files touched by this feature: `git diff --cached --merge-base <base-branch> --name-only`. This covers the branch commits and the staged changes — the work is still staged at this point (the commit happens in step 2).

**File overlap — dynamic computation:**
For each `IN_PROGRESS` branch listed in "Merge readiness" other than `<feature-branch>` (skip this feature's own row), compute its touched files dynamically: `git diff --name-only --merge-base <base-branch> <branch>`. Compare the two file lists. If any files overlap, report the overlapping files as a warning. If a branch cannot be resolved locally, warn and skip it rather than failing.

**Limitation:** the other-branch check only sees commits — files that are only staged in another worktree are invisible to it.

Fallback for git < 2.30 (no `--merge-base` option): `git diff --cached --name-only $(git merge-base <base-branch> HEAD)` for this feature, `git diff --name-only $(git merge-base <base-branch> <branch>) <branch>` for other branches.

**Declared dependencies:**
Are there branches that declare `Waiting for: [this branch]` in "Merge readiness"?

**APIs:**
Are there entries in "API & Contracts modified" by other branches that are not yet accounted for in this feature's code?

**Constraints:**
Are there entries in "Constraints discovered" that apply to this feature's scope without having been addressed?

**Verdict:**
- **✓ OK to ship** — no blocking point
- **⚠ Blocking: [precise reason]** — if a point blocks

If blocking: explain the issue and wait for human confirmation before continuing. As a subagent, return the blocked signal instead (see "Running as a subagent") — do not commit.

### 2. Commit

Message: `type(scope): short description` — the description explains the WHY, not the what.

Move `.scratch/DD-MM-YYYY-[feature-name].md` to `.scratch/done/`.

The shared-context.md cleanup (step 3) is included in this same commit.

**Worktree mode** (`## Worktree path` is not `none`): the `.scratch/` changes and guideline migrations land in the feature commit, exactly as without a worktree.
- Make the step 3 migrations to `<guidelines-dir>` and `<rules-file>` inside the worktree, not in the project root.
- Do the move and the step 3 cleanup in the project root `.scratch/` (other features read it there). Then copy `.scratch/shared-context.md` and `.scratch/done/DD-MM-YYYY-[feature-name].md` from the project root `.scratch/` into the worktree at the same paths, stage them with `git -C <worktree-path> add -A .scratch/`, and commit with `git -C <worktree-path> commit`.
- After the commit, remove the root copy of `.scratch/done/DD-MM-YYYY-[feature-name].md`: the feature branch now carries it, and an untracked copy in the root would block merging that branch. `shared-context.md` stays modified in the project root on purpose — it is the live coordination file.

### 3. Clean shared-context.md

> **Sequential access:** `shared-context.md` has no locking mechanism. When running parallel features, ensure only one skill session writes to this file at a time. Stagger phases that modify `shared-context.md` (start, build capture, ship cleanup) to avoid overwrites.

**"Merge readiness" section** → remove the line for `<feature-branch>` (this feature's own row only).

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

### 3b. Worktree cleanup

Read the `## Worktree path` value from the tracking file. If the value is not `none`, remove the worktree:

```
git worktree remove <path>
```

If the removal fails (e.g. uncommitted changes or worktree already removed), warn the user but do not block the ship process.

Run this step after step 4b: a configuration update there amends the feature commit, which needs the worktree.

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

Amend the feature commit to include these changes: `git add <files> && git commit --amend --no-edit`.
In worktree mode, edit the files under `<guidelines-dir>` and `<rules-file>` inside the worktree and run both commands with `git -C <worktree-path>`, then run step 3b.

## End of skill

Commit done, shared-context cleaned.
Push and PR creation are yours to do.

If blocked as a subagent: nothing committed, `SHIP BLOCKED: <precise reason>` reported.
