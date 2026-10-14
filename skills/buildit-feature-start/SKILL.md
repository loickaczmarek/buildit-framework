---
name: buildit-feature-start
description: Use when starting a new feature — creates the .scratch/ tracking file with plan and self-critique, initialises shared-context entry. Accepts optional feature name: /buildit-feature-start [feature-name].
---

# Feature Start

Plans a new feature: plan, self-critic, shared-context initialisation.

## When to use

At the start of each new feature, from the main branch or a dedicated branch, before creating the implementation worktree.

## Steps

### 0. Worktree?

Ask the user:

> "Do you want to work in an isolated worktree for this feature? (recommended for non-trivial features or parallel work)"

- **Yes** → invoke `buildit-worktree [feature-name]` now. Capture the returned "Worktree created at: <path>" line and store the absolute path as `WORKTREE_PATH`. Continue the following steps inside the created worktree.
- **No** → retrieve the current branch (`git branch --show-current`) and inform the user: "You will work directly on `[branch]`." Set `WORKTREE_PATH=none`. Then continue to step 1.

### 1. Read shared-context.md

Read `.scratch/shared-context.md` and check:
- **"API & Contracts modified"** → have any signatures changed that would affect this feature?
- **"Constraints discovered"** → do any known constraints apply to the scope of this feature?
- **"Decisions & Conventions"** → have any architecture decisions or naming conventions been introduced by other branches? If so, the plan must conform to them from the start.

Integrate this information into the plan where relevant.

### 2. Collect feature information

If a `feature-name` was provided as argument (`/feature-start feature-name`), use it directly.

Otherwise, ask:
- Short feature name (kebab-case slug, will be the `.scratch/` file name)
- Feature description
- Acceptance tests (precise list of criteria — being exhaustive here determines the quality of all subsequent steps)

### 3. Generate the tracking file

Create `.scratch/DD-MM-YYYY-[feature-name].md`:

~~~markdown
# [feature-name]

## Status
to-build

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

### 4. Self-critic of the plan

Re-read the plan and identify:
- Assumptions that could be wrong
- Edge cases not covered in the acceptance tests or the plan
- Steps too vague to be executed as-is
- Underestimated technical risks

Update the "Plan" section with the corrections.

### 5. Update shared-context.md

> **Sequential access:** `shared-context.md` has no locking mechanism. When running parallel features, ensure only one skill session writes to this file at a time. Stagger phases that modify `shared-context.md` (start, build capture, ship cleanup) to avoid overwrites.

Retrieve the current branch: `git branch --show-current`

Add a line in the "Merge readiness" section of `.scratch/shared-context.md`:

~~~markdown
| [branch-name] | IN_PROGRESS | — | — |
~~~

## End of skill

> "Plan validated and recorded in `.scratch/DD-MM-YYYY-[feature-name].md`.
>
> Close this session and run `/buildit-feature-build [feature-name]`."
