---
name: buildit-feature-ship
description: "Use when validation passed (status to-ship) — checks shared-context readiness, cleans shared-context, migrates durable constraints to guidelines, runs retro, commits. Does NOT push or create the PR. Accepts optional feature name: /buildit-feature-ship [feature-name]."
---

# Feature Ship

Readiness checklist, shared-context cleanup, constraint migration, retro, commit. Push and PR remain manual.

## When to use

After `buildit-feature-validate` returned GO + PASS overall (status `to-ship` in the tracking file).

## Running as a subagent

When launched as a subagent (e.g. by `buildit-feature-run`), no human can answer. Any step below that says to wait for confirmation returns the blocked signal instead:
- Do not commit, do not move the tracking file, and leave the status `to-ship`.
- Write a `## Last error` section to the tracking file with the single line `buildit-feature-ship: blocked — <precise reason>`, replacing any existing `## Last error` section.
- End with a final message starting with `SHIP BLOCKED: <precise reason>`.

**Deliberate stops:** every stop after a tracking file is selected — the migration note (0a) and the base branch not found (step 1) — keeps the status `to-ship`, commits nothing, writes its own `## Last error` line (given at each stop) and, as a subagent, ends with a final message starting with `SHIP BLOCKED: <same reason>`. Step 0 clears a stale `## Last error` before these stops run, so the line always describes this run.

## Steps

### 0. Identify the feature

**Tracking file discovery rule**
1. Search only the top level of the project root `.scratch/`: never its subdirectories (`done/`, `plan/`, `audits/`) and never a worktree's `.scratch/`.
2. A candidate is a file named `DD-MM-YYYY-<slug>.md` (two-digit day, two-digit month, four-digit year, a dash, a non-empty slug) whose content has a `## Status` heading followed by a feature status: `to-build`, `building`, `to-validate`, `validating`, `to-fix` or `to-ship`. `shared-context.md`, audit reports (`.scratch/audits/`) and plan files (`.scratch/plan/`) can therefore never be selected.
3. With a `feature-name` argument: select the candidate named exactly `DD-MM-YYYY-<feature-name>.md` — the whole slug equals the name, never a substring match (`context` does not match `shared-context.md` nor `24-11-2026-my-context-x.md`).
4. Without a `feature-name`: consider every candidate. Never pick a file by modification date.
5. Exactly one match → use it. No match → stop with: "No tracking file found — expected `.scratch/DD-MM-YYYY-<feature-name>.md` with a `## Status` heading and a feature status." Several matches → list each file with its status and ask which one to use; as a subagent (no human can answer), stop instead of guessing and list the matching files in the final message.

As a subagent, a stop from this rule ends with a final message starting with `SHIP BLOCKED: <precise reason>` (no tracking file is selected, so there is no `## Last error` to write).

If the selected file does not have status `to-ship`, warn: "The selected file does not have status `to-ship` — is this the feature you want to ship?" and wait for confirmation before continuing (as a subagent: return the blocked signal — see "Running as a subagent").

If the tracking file has a `## Last error` section, remove it: it describes a previous run.

**Worktree path:** read the `## Worktree path` value from the tracking file once and store it as `WORKTREE_PATH` (`none` = no worktree). `<worktree-path>` below stands for this value. Step 6 reuses it — never re-read it from the tracking file, which step 4 moves to `.scratch/done/`.

**Working directory:** `.scratch/` and `.buildit/config.md` are always read and written in the project root, even in worktree mode. If `WORKTREE_PATH` is not `none`, edit code files inside the worktree and run every git command on feature code (`add`, `status`, `diff`, `commit`) with `git -C <worktree-path>` — each worktree has its own index, so staged work is only visible there.

**Feature branch:** read the `## Branch` value from the tracking file (the line below the heading, a bare branch name — contract in `buildit-feature-start` step 3) and store it as `<feature-branch>`. Legacy tracking file without `## Branch`: fall back to `git -C <worktree-path> branch --show-current` in worktree mode, `git branch --show-current` otherwise, and warn once: "No `## Branch` in the tracking file — using the checked-out branch `<feature-branch>`."

### 0a. Detect environment paths

**Operating mode rule**
- The mode is the identity of the agent running this skill, never a property of the repository: a Claude / Claude Code agent → **Claude mode** (`MODE` = `claude`); any other agent (Copilot, generic) → **Generic mode** (`MODE` = `generic`).
- Claude mode: rules file `.claude/CLAUDE.md`, skills directory `.claude/skills/`. Generic mode: rules file `.agents/guidelines/project-rules.md`, skills directory `.agents/skills/`.
- Never infer the mode from the presence of `.claude/` or `.agents/`: a dual-deployment repository contains both directories, so such a check always answers Claude.
- The mode is never persisted (not in `.buildit/config.md` nor in any other file): every skill applies this rule for the agent that runs it.

`<rules-file>` = the rules file of your mode.

In all cases: `<guidelines-dir>` = `.buildit/guidelines/`

**Migration note:** If `.buildit/guidelines/` does not exist but `.claude/guidelines/` or `.agents/guidelines/` does, warn the user:
> "Guidelines found at [old-path] instead of `.buildit/guidelines/`. Run `/buildit-project-bootstrap` to migrate them before continuing."
Then write a `## Last error` section to the tracking file with the single line `buildit-feature-ship: guidelines found at <old-path>, migration required`, replacing any existing `## Last error` section (as a subagent, end with `SHIP BLOCKED: guidelines found at <old-path>, migration required`), and stop.

Use `<rules-file>` and `<guidelines-dir>` as shorthand for these paths in all steps below.

---

### 1. Readiness check

Read `.scratch/shared-context.md` in full. If `.scratch/shared-context.md` does not exist, treat it as empty: no other branch rows, APIs or constraints to check.

**Base branch:** read `.buildit/config.md` and take the first non-empty, non-comment line after the `## Base branch` heading, read only within that heading (stop at the next heading); a line starting with `#` is never a value (Config value rule, `.buildit/guidelines/language-framework.md`), as `<base-branch>`. If the file or the heading is absent, or the heading is empty, `<base-branch>` defaults to `main`. If `git rev-parse --verify <base-branch>` fails, write a `## Last error` section to the tracking file with the single line `buildit-feature-ship: base branch <base-branch> not found locally`, replacing any existing `## Last error` section (as a subagent, end with `SHIP BLOCKED: base branch <base-branch> not found locally`), and stop with: "Base branch `<base-branch>` not found locally — set `## Base branch` in `.buildit/config.md` or fetch the branch."

Retrieve the files touched by this feature: `git diff --cached --merge-base <base-branch> --name-only`. This covers the branch commits and the staged changes — the work is still staged at this point (the commit happens in step 5).

**File overlap — dynamic computation:**
For each `IN_PROGRESS` branch listed in "Merge readiness" other than `<feature-branch>` (skip this feature's own row), compute its touched files dynamically: `git diff --name-only --merge-base <base-branch> <branch>`. Compare the two file lists. If any files overlap, report the overlapping files as a warning. If a branch cannot be resolved locally, warn and skip it rather than failing.

**Limitation:** the other-branch check only sees commits — files that are only staged in another worktree are invisible to it.

Fallback for git < 2.30 (no `--merge-base` option): `git diff --cached --name-only $(git merge-base <base-branch> HEAD)` for this feature, `git diff --name-only $(git merge-base <base-branch> <branch>) <branch>` for other branches.

**APIs:**
Are there entries in "API & Contracts modified" by other branches that are not yet accounted for in this feature's code?

**Constraints:**
Are there entries in "Constraints discovered" that apply to this feature's scope without having been addressed?

**Verdict:**
- **✓ OK to ship** — no blocking point
- **⚠ Blocking: [precise reason]** — if a point blocks

If blocking: explain the issue and wait for human confirmation before continuing. As a subagent, return the blocked signal instead (see "Running as a subagent") — do not commit.

### 2. Clean shared-context.md

Edit the project root `.scratch/shared-context.md` (other features read it there). If `.scratch/shared-context.md` does not exist, treat it as empty: there is nothing to clean or migrate — skip to step 3. Make the migrations below to `<guidelines-dir>` and `<rules-file>` inside the worktree in worktree mode, in the project root otherwise — step 4 stages them.

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

### 3. Light retro

Answer these three questions:
- What slowed down the loop on this feature?
- Would a configuration have prevented that slowdown?
- Was the initial plan precise enough?

### 3b. Update configurations if needed

If any answer above indicates that a configuration was missing or insufficient, identify and immediately update the relevant files:
- `<rules-file>` → cross-cutting rules (security, global behaviour)
- `<guidelines-dir>/team-practices.md` → team conventions, test patterns, naming
- `<guidelines-dir>/language-framework.md` → stack constraints, APIs, versions

In worktree mode, edit the files under `<guidelines-dir>` and `<rules-file>` inside the worktree. Step 4 stages them with the rest of the closing changes.

### 4. Stage the closing changes

Move `.scratch/DD-MM-YYYY-[feature-name].md` to `.scratch/done/` in the project root.

`.scratch/shared-context.md` is never staged: it is gitignored local state, and step 2 edited only the project-root copy.

Stage with explicit paths only — never `git add -A` or `git add .`, which would sweep in other features' tracking files and plan files.

**Without worktree** (`WORKTREE_PATH` is `none`):
- Tracking file: `git add .scratch/done/DD-MM-YYYY-[feature-name].md`, then `git rm --cached --quiet --ignore-unmatch -- .scratch/DD-MM-YYYY-[feature-name].md` (drops the old path if it was ever tracked; no-op otherwise).
- Migrations and configuration updates (steps 2 and 3b): `git add <file>...` for each guideline or rules file touched.

**Worktree mode** (`WORKTREE_PATH` is not `none`):
- Tracking file: copy only `.scratch/done/DD-MM-YYYY-[feature-name].md` from the project root into the worktree at the same path, then `git -C <worktree-path> add .scratch/done/DD-MM-YYYY-[feature-name].md`.
- Migrations and configuration updates (steps 2 and 3b): `git -C <worktree-path> add <file>...` for each guideline or rules file touched inside the worktree.

### 5. Commit

`git [-C <worktree-path>] commit` — message: `type(scope): short description`; the description explains the WHY, not the what. The commit holds the feature work staged by build plus the closing changes staged in step 4.

### 6. Worktree cleanup

Only if `WORKTREE_PATH` (stored at step 0) is not `none`:
1. In the project root, remove the root copy of `.scratch/done/DD-MM-YYYY-[feature-name].md`: the feature branch now carries it, and an untracked copy in the root would block merging that branch.
2. Remove the worktree:

```
git worktree remove <WORKTREE_PATH>
```

If the removal fails (e.g. uncommitted changes or worktree already removed), warn the user but do not block the ship process.

`shared-context.md` stays in the project root — it is untracked local coordination state.

## End of skill

Commit done, shared-context cleaned.
Push and PR creation are yours to do.

If blocked as a subagent: nothing committed, `SHIP BLOCKED: <precise reason>` reported.
