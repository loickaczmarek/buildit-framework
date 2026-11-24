---
name: buildit-feature-start
description: "Use when starting a new feature — creates the .scratch/ tracking file with plan and self-critique, initialises shared-context entry. Accepts optional feature name: /buildit-feature-start [feature-name]."
---

# Feature Start

Plans a new feature: plan, self-critic, shared-context initialisation.

## When to use

At the start of each new feature, from the main branch or a dedicated branch, before creating the implementation worktree.

## Steps

### 0. Prerequisite check

If `.scratch/shared-context.md` does not exist, stop with:
> "Shared context file not found — run `/buildit-project-bootstrap` to initialize the project."

### 1. Read shared-context.md

Read `.scratch/shared-context.md` and check:
- **"API & Contracts modified"** → have any signatures changed that would affect this feature?
- **"Constraints discovered"** → do any known constraints apply to the scope of this feature?
- **"Decisions & Conventions"** → have any architecture decisions or naming conventions been introduced by other branches? If so, the plan must conform to them from the start.

Integrate this information into the plan where relevant.

### 2. Collect feature information

If a non-empty `feature-name` was provided as argument (`/feature-start feature-name`), use it directly. An empty or whitespace-only argument counts as missing.

Otherwise, ask:
- Short feature name (kebab-case slug, will be the `.scratch/` file name)
- Feature description
- Acceptance tests (precise list of criteria — being exhaustive here determines the quality of all subsequent steps)

Empty feature name → ask again: the slug must be non-empty, since it names both the tracking file and the worktree branch.

### 2b. Worktree?

Runs only after the prerequisite check passed (step 0) and once the feature name is collected (step 2), so a failed or cancelled start never leaves an orphan worktree or a `feature/YYYY-MM-DD-` branch with an empty slug.

Ask the user:

> "Do you want to work in an isolated worktree for this feature? (recommended for non-trivial features or parallel work)"

- **Yes** → invoke `buildit-worktree [feature-name]` now. Capture the returned "Worktree created at: <path>" line and store the absolute path as `WORKTREE_PATH`. Capture the returned `Branch: <BRANCH>` line and store the branch name as `BRANCH`. The `.scratch/` files written by the following steps (tracking file, `shared-context.md`) stay in the project root; only implementation work happens inside the worktree.
- **No** → store the current branch as `BRANCH` (`git branch --show-current`) and inform the user: "You will work directly on `[BRANCH]`." Set `WORKTREE_PATH=none`. If `BRANCH` is empty (detached HEAD), stop with: "Detached HEAD — check out a branch first: the Merge readiness row and ship's overlap check need a branch name." Then continue to step 3.

### 3. Generate the tracking file

Create `.scratch/DD-MM-YYYY-[feature-name].md`:

~~~markdown
# [feature-name]

## Status
to-build

## Branch
[BRANCH — bare branch name, no backticks]

## Worktree path
[WORKTREE_PATH — absolute path, or "none" if no worktree]

## Goal
[feature description]

## Acceptance Tests
[criteria as provided]

## Plan
[detailed implementation steps]

## Progress
[empty at start]
~~~

**`## Branch` contract** — the value is the line below the `## Branch` heading: a bare branch name without backticks (e.g. `feature/2026-11-24-my-widget`). Start writes it once, here, from `BRANCH`; it is never rewritten by other phases. Readers: step 5 below (Merge readiness row key) and `buildit-feature-ship` (row removal, overlap self-skip). In worktree mode the project root is usually on another branch, so readers must use `## Branch`, never `git branch --show-current` in the project root.

### 4. Self-critic of the plan

Re-read the plan and identify:
- Assumptions that could be wrong
- Edge cases not covered in the acceptance tests or the plan
- Steps too vague to be executed as-is
- Underestimated technical risks

Update the "Plan" section with the corrections.

### 5. Update shared-context.md

> **Sequential access:** `shared-context.md` has no locking mechanism. When running parallel features, ensure only one skill session writes to this file at a time. Stagger phases that modify `shared-context.md` (start, build capture, ship cleanup) to avoid overwrites.

This step runs after the worktree exists (step 2b) and the tracking file exists (step 3), so a failed or cancelled start leaves no row behind.

Read the `## Branch` value from the tracking file and add a line keyed by it in the "Merge readiness" section of `.scratch/shared-context.md`:

~~~markdown
| [## Branch value] | IN_PROGRESS | — | — |
~~~

## End of skill

> "Plan validated and recorded in `.scratch/DD-MM-YYYY-[feature-name].md`.
>
> Close this session and run `/buildit-feature-build [feature-name]`."
