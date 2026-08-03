---
name: feature-validate
description: Use when implementation is complete (status to-validate) — reviews code on 5 dimensions, validates each acceptance test, updates configs on failure. Routes to feature-ship (GO) or feature-build with documented fixes (NO-GO/FAIL). Accepts optional feature name: /feature-validate [feature-name].
---

# Feature Validate

Code review and acceptance test validation. Routes to the build/fix loop or opens the path to feature-ship.

## When to use

After `feature-build` has completed its cycle (status `to-validate` in the tracking file).

## Steps

### 0. Detect environment paths

Check whether `.claude/` exists at the project root:
- If yes → **Claude mode**: rules file = `.claude/CLAUDE.md`, guidelines directory = `.claude/guidelines/`
- If no → **Generic mode**: rules file = `.agents/guidelines/project-rules.md`, guidelines directory = `.agents/guidelines/`

Use `<rules-file>` and `<guidelines-dir>` as shorthand for these paths in all steps below.

---

### 1. Identify the tracking file

- If a `feature-name` was provided as argument (`/feature-validate feature-name`) → look for `.scratch/*feature-name*.md`
- Otherwise → scan `.scratch/` and take the most recent `.md` outside of `done/`

Set the status to `validating`.

### 2. Read known constraints

Read `.scratch/shared-context.md` section "Constraints discovered": are there documented constraints that apply to the scope of this feature?

### 3. Review phase

Read the changes: `git diff main...HEAD`

**Do not read the plan** — the review is about what was done, not what was intended. The absence of bias is what gives value to this step.

Evaluate on these 5 dimensions:

| Dimension | Question |
|-----------|----------|
| **Correctness** | Does the code do what is asked? |
| **Performance** | Are there unnecessary costly operations? |
| **Security** | Are there injection vectors, data exposure, obvious vulnerabilities? |
| **Style** | Does the code follow project conventions (`<guidelines-dir>`)? |
| **Test coverage** | Are edge cases tested? |

Conclude with **GO** or **NO-GO** with the list of blocking issues if NO-GO.

### 4. Acceptance phase

Read the "Acceptance Tests" section of the tracking file.

For each criterion: **PASS** or **FAIL** with justification.

Conclude with **PASS overall** or **FAIL** with the list of unsatisfied criteria.

---

## If GO + PASS overall

Set the status to `to-ship`.

> "Validation successful. Status set to `to-ship`.
> Close this session and run `/feature-ship [feature-name]`."

---

## If NO-GO or FAIL

Act within the same context, before closing the session.

### 5a. Update configurations

Identify which configurations would have prevented these issues had they existed. Update immediately:
- `<rules-file>` → cross-cutting rules (security, global behaviour)
- `<guidelines-dir>/team-practices.md` → team conventions, test patterns
- `<guidelines-dir>/language-framework.md` → stack constraints, APIs, versions

### 5b. Document the problems

Set the status to `to-fix`.

Write a "Problems to fix" section in the tracking file with the precise list of issues, located in the code where applicable:

~~~markdown
## Problems to fix
- [problem 1] — [file:line if applicable]
- [problem 2] — [file:line if applicable]
~~~

### 5c. Count cycles and warn if needed

Count the number of previous occurrences of the "Problems to fix" section in the "Progress" history of the file (note the current cycle in "Progress" to ease future counting).

## End of skill (NO-GO / FAIL)

> "Configurations updated. Problems recorded in `.scratch/`.
> Close this session and re-run `/feature-build [feature-name]`."

If this is the **3rd build/fix cycle or more**, add:

> "⚠ You are on cycle X of the build/fix loop for this feature. Accumulated context may introduce noise in the agent's reasoning — consider a completely fresh session (close everything, open Claude Code without any previous session context) before re-running `/feature-build`."
