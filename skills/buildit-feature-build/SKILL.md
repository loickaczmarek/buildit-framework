---
name: buildit-feature-build
description: "Use when implementing a feature or applying fixes after a buildit-feature-validate NO-GO — runs TDD cycle (status to-build) or fix cycle (status to-fix). Accepts optional feature name: /buildit-feature-build [feature-name]."
---

# Feature Build

Implements the feature (TDD mode) or fixes issues identified by feature-validate (fix mode).

## When to use

- First implementation: after `buildit-feature-start` and creation of the isolated worktree
- Fix: after `buildit-feature-validate` returned NO-GO or FAIL and documented the issues in `.scratch/`

## Steps

### 0. Prerequisite check

If `.scratch/shared-context.md` does not exist, stop with:
> "Shared context file not found — run `/buildit-project-bootstrap` to initialize the project."

### 1. Identify the tracking file and detect the mode

**Tracking file discovery rule**
1. Search only the top level of the project root `.scratch/`: never its subdirectories (`done/`, `plan/`, `audits/`) and never a worktree's `.scratch/`.
2. A candidate is a file named `DD-MM-YYYY-<slug>.md` (two-digit day, two-digit month, four-digit year, a dash, a non-empty slug) whose content has a `## Status` heading followed by a feature status: `to-build`, `building`, `to-validate`, `validating`, `to-fix` or `to-ship`. `shared-context.md`, audit reports (`.scratch/audits/`) and plan files (`.scratch/plan/`) can therefore never be selected.
3. With a `feature-name` argument: select the candidate named exactly `DD-MM-YYYY-<feature-name>.md` — the whole slug equals the name, never a substring match (`context` does not match `shared-context.md` nor `24-11-2026-my-context-x.md`).
4. Without a `feature-name`: consider every candidate. Never pick a file by modification date.
5. Exactly one match → use it. No match → stop with: "No tracking file found — expected `.scratch/DD-MM-YYYY-<feature-name>.md` with a `## Status` heading and a feature status." Several matches → list each file with its status and ask which one to use; as a subagent (no human can answer), stop instead of guessing and list the matching files in the final message.

**Before modifying the status**, read the file and check the current status:
- If the current status is not `to-build` or `to-fix`, warn: "Current status is `[status]` — buildit-feature-build expects `to-build` or `to-fix`. Continue anyway?" and wait for user confirmation before proceeding.

Then detect the mode:
- Presence of a "Problems to fix" section → **fix mode**
- Absence of this section → **normal TDD mode**

Then set the status to `building` in that file.

**Working directory:** `.scratch/` and `.buildit/config.md` are always read and written in the project root, even in worktree mode. Read `## Worktree path` from the tracking file: if it is not `none`, edit code files inside the worktree and run every git command on feature code (`add`, `status`, `diff`) with `git -C <worktree-path>` — each worktree has its own index, so staged work is only visible there. Run the test command with the worktree as working directory (`cd <worktree-path> && <test command>`) — the project root holds base-branch code, so tests run there never see this feature's changes.

### 2. Check API changes

Read `.scratch/shared-context.md` section "API & Contracts modified".

Have any APIs used in this feature's plan been modified by other branches? If so, adapt the implementation to use the new signatures.

### 3. Proceed according to the detected mode

---

## Normal TDD mode

### 3a. Write the tests

Read the "Acceptance Tests" section of the tracking file.

For each acceptance test, write the corresponding test. Tests must fail. Verify that each test fails for the right reason: the test executes and fails on the assertion — not on a syntax error or missing dependency.

### 3b. Implement

Write the minimal implementation to make the tests pass. Follow the plan step by step. After each significant file modified, re-run the tests and verify progress.

### 3c. Craft-principles self-review

Before moving to step 4, verify the implementation against the three craft principles defined in `<guidelines-dir>/craft-principles.md`:

- **DRY** — Is any logic or knowledge duplicated? If so, extract it.
- **KISS** — Is any part unnecessarily complex? If so, simplify.
- **YAGNI** — Does the code implement anything not required by the acceptance tests? If so, remove it.

If a violation is found, fix it before proceeding. Do not move to step 4 with a known violation.

---

## Fix mode

### 3a. Read the problems

Read the "Problems to fix" section in the tracking file.

### 3b. Fix

Fix the code, targeted on the listed problems. Re-run tests after each modification. Do not restructure beyond what the fixes require.

After the fixes pass, apply the same craft-principles self-review as in normal mode (DRY, KISS, YAGNI — see `<guidelines-dir>/craft-principles.md`) before proceeding to step 4.

---

### 4. Capture new practices

> **Sequential access:** `shared-context.md` has no locking mechanism. When running parallel features, ensure only one skill session writes to this file at a time. Stagger phases that modify `shared-context.md` (start, build capture, ship cleanup) to avoid overwrites.

Before closing the session, ask:

> "Have I intentionally introduced a new practice in this implementation — architecture, naming convention, code pattern, file organisation?"

If yes, document in `.scratch/shared-context.md` section "Decisions & Conventions":

~~~markdown
### [branch-name] — [DD-MM-YYYY]
- **Decision**: precise description (e.g. list components use the Container/Presenter pattern)
- **Reason**: why this choice was made
- **Affects**: files or modules concerned
~~~

If no, move to the next step without modifying `shared-context.md`.

### 5. Stage the work and update the tracking file

`buildit-feature-validate` starts with a staging guard that returns NO-GO on any untracked or unstaged file outside `.scratch/`. Hand over staged work:

1. **Stage** every file created or modified during this build: `git [-C <worktree-path>] add <path>...` with explicit paths — never `git add -A` or `git add .`, which would sweep in unrelated files. Files under `.scratch/` are workflow state committed by ship; do not stage them here.
2. **Check** with `git [-C <worktree-path>] status --porcelain`, ignoring paths under `.scratch/`: no line may be untracked (`??`) or have unstaged changes (second status column non-blank) — the same criteria as validate's guard. Stage any remaining entry that belongs to the feature. If an entry is unrelated to the feature, do not stage it: leave the status at `building` and stop with:
   > "Unrelated untracked or unstaged files block validation: [paths]. Stage, ignore, or remove them, then re-run `/buildit-feature-build [feature-name]`."
3. Set the status to `to-validate` and clear the "Problems to fix" section if it existed.

## End of skill

> "Implementation complete, tests passing. Status set to `to-validate`.
> Close this session and run `/buildit-feature-validate [feature-name]`."

> If a new practice was documented in `shared-context.md`: "Note: I added an entry in 'Decisions & Conventions' — it will be migrated into the guidelines at ship time."
