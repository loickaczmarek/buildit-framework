---
name: buildit-feature-validate
description: "Use when implementation is complete (status to-validate) — reviews code on 6 dimensions, validates each acceptance test, updates configs on failure. Routes to buildit-feature-ship (GO) or buildit-feature-build with documented fixes (NO-GO/FAIL). Accepts optional feature name: /buildit-feature-validate [feature-name]."
---

# Feature Validate

Code review and acceptance test validation. Routes to the build/fix loop or opens the path to feature-ship.

## When to use

After `buildit-feature-build` has completed its cycle (status `to-validate` in the tracking file).

## Steps

### 0. Detect environment paths

Determine your operating mode from your agent identity:
- You are a **Claude / Claude Code** agent → **Claude mode**: `<rules-file>` = `.claude/CLAUDE.md`
- You are any **other agent** (Copilot, generic) → **Generic mode**: `<rules-file>` = `.agents/guidelines/project-rules.md`

In all cases: `<guidelines-dir>` = `.buildit/guidelines/`

**Migration note:** If `.buildit/guidelines/` does not exist but `.claude/guidelines/` or `.agents/guidelines/` does, warn the user:
> "Guidelines found at [old-path] instead of `.buildit/guidelines/`. Run `/buildit-project-bootstrap` to migrate them before continuing."
Then stop.

Use `<rules-file>` and `<guidelines-dir>` as shorthand for these paths in all steps below.

---

### 0b. Prerequisite check

If `.scratch/shared-context.md` does not exist, stop with:
> "Shared context file not found — run `/buildit-project-bootstrap` to initialize the project."

### 1. Identify the tracking file

- If a `feature-name` was provided as argument (`/buildit-feature-validate feature-name`) → look for `.scratch/*feature-name*.md`
- Otherwise → scan `.scratch/` and take the most recent `.md` outside of `done/`

Set the status to `validating`.

### 2. Read known constraints

Read `.scratch/shared-context.md` section "Constraints discovered": are there documented constraints that apply to the scope of this feature?

### 2b. Run test suite

Run the project's test suite before the review phase using a two-tier detection:

**Tier 1 — Configured command:** Read `.buildit/config.md`, extract the first non-empty, non-comment line after the `## Test command` heading. If found and non-empty, use it.

**Tier 2 — Ecosystem fallback heuristic:** If no configured command is found (file absent, heading missing, or no command under it), detect the test runner from ecosystem markers in priority order:
1. `tests/run-all.sh` exists -> `bash tests/run-all.sh`
2. `package.json` exists -> `npm test`
3. `pom.xml` exists -> `mvn test`
4. `build.gradle` or `build.gradle.kts` exists -> `gradle test`
5. `pyproject.toml` exists -> `pytest`
6. `Makefile` exists and contains a `test` target (`grep -q '^test:' Makefile`) -> `make test`

**No detection:** If no configured command and no ecosystem marker is found, warn: "No test runner detected — no configured command in `.buildit/config.md` and no ecosystem markers found. Proceeding to review phase without running tests." and continue to step 3.

If any test fails: set status to `to-fix`, write a "Problems to fix" section in the tracking file with the test failure details, and stop — do not proceed to the review phase.

If all tests pass: proceed to step 3 (review phase).

### 3. Review phase

Read the changes: `git diff main...HEAD`

**Do not read the plan** — the review is about what was done, not what was intended. The absence of bias is what gives value to this step.

Evaluate on these 6 dimensions:

| Dimension | Question |
|-----------|----------|
| **Correctness** | Does the code do what is asked? |
| **Performance** | Are there unnecessary costly operations? |
| **Security** | Are there injection vectors, data exposure, obvious vulnerabilities? |
| **Style** | Does the code follow project conventions (`<guidelines-dir>`)? |
| **Test coverage** | Are edge cases tested? |
| **Craft principles** | Does the code respect DRY, KISS, and YAGNI? (see `<guidelines-dir>/craft-principles.md`) |

Conclude with **GO** or **NO-GO** with the list of blocking issues if NO-GO.

### 4. Acceptance phase

Read the "Acceptance Tests" section of the tracking file.

For each criterion: **PASS** or **FAIL** with justification.

Conclude with **PASS overall** or **FAIL** with the list of unsatisfied criteria.

---

## If GO + PASS overall

Set the status to `to-ship`.

> "Validation successful. Status set to `to-ship`.
> Close this session and run `/buildit-feature-ship [feature-name]`."

---

## If NO-GO or FAIL

Act within the same context, before closing the session.

### 5a. Update configurations via subagent

Before documenting problems, produce a structured list of the issues found — this is the subagent's input.

Launch a subagent with the following context:
- The structured list of issues (from the review and acceptance phases above)
- The paths `<rules-file>`, `<guidelines-dir>/team-practices.md`, `<guidelines-dir>/language-framework.md`
- The current content of each of those files

Subagent instructions:
> "You are updating project configuration files. For each issue in the list below, identify which configuration would have prevented it and add the corresponding rule to the appropriate file:
> - `<rules-file>` → cross-cutting rules (security, global behaviour)
> - `<guidelines-dir>/team-practices.md` → team conventions, test patterns
> - `<guidelines-dir>/language-framework.md` → stack constraints, APIs, versions
>
> Only add rules that are absent from the files. For each rule to add, return it in this format:
> FILE: <path>
> SECTION: <section name to append to>
> RULE: <rule text to insert>
> Do not return the full file content — additions only.
>
> Issues to process:
> [structured issue list]
>
> Current file contents:
> [current file contents]"

Apply the subagent's output to the files.

### 5b. Document the problems

Set the status to `to-fix`.

Write a "Problems to fix" section in the tracking file with the precise list of issues, located in the code where applicable:

~~~markdown
## Problems to fix
- [problem 1] — [file:line if applicable]
- [problem 2] — [file:line if applicable]
~~~

### 5c. Count cycles and warn if needed

Count the number of existing entries in the "Progress" section of the tracking file to determine the current cycle number N.

Add a new entry in the "Progress" section:

~~~markdown
### NO-GO cycle [N+1] — [DD-MM-YYYY]
- Review: [GO / NO-GO — key blocking issues if NO-GO]
- Acceptance: [PASS / FAIL — key failing criteria if FAIL]
~~~

## End of skill (NO-GO / FAIL)

> "Configurations updated. Problems recorded in `.scratch/`.
> Close this session and re-run `/buildit-feature-build [feature-name]`."

If N+1 >= 3 (i.e. this is the 3rd NO-GO or more), add:

> "⚠ You are on cycle X of the build/fix loop for this feature. Accumulated context may introduce noise in the agent's reasoning — consider a completely fresh session (close everything, open Claude Code without any previous session context) before re-running `/buildit-feature-build`."
