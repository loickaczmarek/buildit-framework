# fix-high-audit-issues

## Status
to-ship

## Worktree path
none

## Goal
Add missing guards to buildit skills — status validation in build, shared-context existence check in 4 skills, worktree cleanup in ship. These address audit issues #4, #5, and #6 from the 2026-10-14 skills audit (all rated "High").

## Acceptance Tests
1. `buildit-feature-build` rejects status != `to-build`/`to-fix` with a warning and waits for confirmation before proceeding
2. `buildit-feature-start`, `buildit-feature-build`, `buildit-feature-validate`, `buildit-feature-ship` stop with a clear message if `.scratch/shared-context.md` does not exist, telling the user to run `/buildit-project-bootstrap`
3. `buildit-feature-ship` removes the worktree after commit if the tracking file has a `## Worktree path` value other than `none`, using `git worktree remove`

## Plan

### Step 1: Write failing tests for AT-1 (status guard in build)
- In `tests/test-buildit-feature-build.sh`, add a test that checks for the presence of a status guard in the skill file
- The test should verify: (a) the skill mentions `to-build` and `to-fix` as expected statuses, (b) the skill contains a warning/confirmation pattern for unexpected status, (c) the guard appears before (or within) the mode detection step

### Step 2: Write failing tests for AT-2 (shared-context existence check)
- In each of the 4 test files (`test-buildit-feature-start.sh`, `test-buildit-feature-build.sh`, `test-buildit-feature-validate.sh`, `test-buildit-feature-ship.sh`), add a test that checks for a guard that validates `.scratch/shared-context.md` exists
- The test should verify: the skill mentions checking for `shared-context.md` existence AND mentions `/buildit-project-bootstrap` as the remedy

### Step 3: Write failing tests for AT-3 (worktree cleanup in ship)
- In `tests/test-buildit-feature-ship.sh`, add a test that checks for the worktree cleanup step
- The test should verify: (a) the skill mentions `Worktree path`, (b) the skill references `git worktree remove`, (c) the cleanup happens after the commit step

### Step 4: Implement AT-1 — add status guard to buildit-feature-build
- In `skills/buildit-feature-build/SKILL.md`, add a guard at the beginning of step 1 (after reading the tracking file, before setting status to `building`)
- Guard text: "If status is not `to-build` or `to-fix`, warn: 'Current status is `[status]` -- buildit-feature-build expects `to-build` or `to-fix`. Continue anyway?' and wait for confirmation."

### Step 5: Implement AT-2 — add shared-context existence check to 4 skills
- In each of the 4 skills, add a guard as the very first action (before any step that reads shared-context.md):
  - `buildit-feature-start`: before step 1 (new step 0b or early in step 1)
  - `buildit-feature-build`: before step 2 (which reads shared-context.md) -- but logically should be before step 1 since the file is fundamental
  - `buildit-feature-validate`: before step 2 (which reads shared-context.md)
  - `buildit-feature-ship`: before step 1 (which reads shared-context.md in full)
- Guard text: "If `.scratch/shared-context.md` does not exist, stop with: 'Shared context file not found -- run `/buildit-project-bootstrap` to initialize the project.'"

### Step 6: Implement AT-3 — add worktree cleanup to buildit-feature-ship
- In `skills/buildit-feature-ship/SKILL.md`, add a new step after step 2 (commit) and step 3 (shared-context cleanup), before step 4 (retro)
- New step: "If the tracking file has a `## Worktree path` value other than `none`, run `git worktree remove <path>` and confirm removal."

### Step 7: Run all tests and verify everything passes

### Self-critique corrections

**Assumption risk — guard placement in start skill:** The start skill has a step 0 (worktree question) that happens before step 1 (read shared-context). The shared-context guard should be placed between step 0 and step 1, since the worktree question doesn't depend on shared-context, but step 1 does. If we place it before step 0, we block users who want to set up a worktree before the project is bootstrapped — that could be valid. Decision: place the guard as a new "step 0b" between step 0 (worktree) and step 1 (read shared-context). This way the worktree can be created first, and the guard fires before shared-context is actually read.

**Assumption risk — guard placement in build skill:** The build skill reads shared-context at step 2, but the tracking file at step 1. The shared-context guard could go before step 1 (earliest possible) or between step 1 and step 2 (just before it's needed). Decision: place it before step 1 — if the project isn't bootstrapped, there's no point in even looking for a tracking file. This also means we can fail fast.

**Edge case — worktree removal failure:** The worktree may have uncommitted changes or may have already been removed. The ship step should handle this gracefully — at minimum, warn if the removal fails rather than blocking the entire ship.

**Edge case — status guard wording:** The guard says "wait for confirmation" but in an automated/CI context there's no human to confirm. This is acceptable because buildit skills are designed for interactive use with a human-in-the-loop agent, matching the existing pattern in ship step 0.

## Progress
