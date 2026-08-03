---
name: feature-build
description: Use when implementing a feature or applying fixes after a validate NO-GO — runs TDD cycle (status to-build) or fix cycle (status to-fix). Accepts optional feature name: /feature-build [feature-name].
---

# Feature Build

Implements the feature (TDD mode) or fixes issues identified by feature-validate (fix mode).

## When to use

- First implementation: after `feature-start` and creation of the isolated worktree
- Fix: after `feature-validate` returned NO-GO or FAIL and documented the issues in `.scratch/`

## Steps

### 1. Identify the tracking file and detect the mode

- If a `feature-name` was provided as argument (`/feature-build feature-name`) → look for `.scratch/*feature-name*.md`
- Otherwise → scan `.scratch/` and take the most recent `.md` outside of `done/`

**Before modifying the status**, read the file and detect the mode:
- Presence of a "Problems to fix" section → **fix mode**
- Absence of this section → **normal TDD mode**

Then set the status to `building` in that file.

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

---

## Fix mode

### 3a. Read the problems

Read the "Problems to fix" section in the tracking file.

### 3b. Fix

Fix the code, targeted on the listed problems. Re-run tests after each modification. Do not restructure beyond what the fixes require.

---

### 4. Capture new practices

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

### 5. Update the tracking file

- Set the status to `to-validate`
- Clear the "Problems to fix" section if it existed

## End of skill

> "Implementation complete, tests passing. Status set to `to-validate`.
> Close this session and run `/feature-validate [feature-name]`."

> If a new practice was documented in `shared-context.md`: "Note: I added an entry in 'Decisions & Conventions' — it will be migrated into the guidelines at ship time."
