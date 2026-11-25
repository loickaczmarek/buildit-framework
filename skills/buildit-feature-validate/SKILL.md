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

**Operating mode rule**
- The mode is the identity of the agent running this skill, never a property of the repository: a Claude / Claude Code agent → **Claude mode** (`MODE` = `claude`); any other agent (Copilot, generic) → **Generic mode** (`MODE` = `generic`).
- Claude mode: rules file `.claude/CLAUDE.md`, skills directory `.claude/skills/`. Generic mode: rules file `.agents/guidelines/project-rules.md`, skills directory `.agents/skills/`.
- Never infer the mode from the presence of `.claude/` or `.agents/`: a dual-deployment repository contains both directories, so such a check always answers Claude.
- The mode is never persisted (not in `.buildit/config.md` nor in any other file): every skill applies this rule for the agent that runs it.

`<rules-file>` = the rules file of your mode.

In all cases: `<guidelines-dir>` = `.buildit/guidelines/`

**Migration note:** If `.buildit/guidelines/` does not exist but `.claude/guidelines/` or `.agents/guidelines/` does, warn the user:
> "Guidelines found at [old-path] instead of `.buildit/guidelines/`. Run `/buildit-project-bootstrap` to migrate them before continuing."
Then stop.

Use `<rules-file>` and `<guidelines-dir>` as shorthand for these paths in all steps below.

---

### 1. Identify the tracking file

**Tracking file discovery rule**
1. Search only the top level of the project root `.scratch/`: never its subdirectories (`done/`, `plan/`, `audits/`) and never a worktree's `.scratch/`.
2. A candidate is a file named `DD-MM-YYYY-<slug>.md` (two-digit day, two-digit month, four-digit year, a dash, a non-empty slug) whose content has a `## Status` heading followed by a feature status: `to-build`, `building`, `to-validate`, `validating`, `to-fix` or `to-ship`. `shared-context.md`, audit reports (`.scratch/audits/`) and plan files (`.scratch/plan/`) can therefore never be selected.
3. With a `feature-name` argument: select the candidate named exactly `DD-MM-YYYY-<feature-name>.md` — the whole slug equals the name, never a substring match (`context` does not match `shared-context.md` nor `24-11-2026-my-context-x.md`).
4. Without a `feature-name`: consider every candidate. Never pick a file by modification date.
5. Exactly one match → use it. No match → stop with: "No tracking file found — expected `.scratch/DD-MM-YYYY-<feature-name>.md` with a `## Status` heading and a feature status." Several matches → list each file with its status and ask which one to use; as a subagent (no human can answer), stop instead of guessing and list the matching files in the final message.

**Status guard:** read the current status before modifying anything. If it is not `to-validate`, do not change it: write a `## Last error` section to the tracking file with the single line `buildit-feature-validate: status is <status>, expected to-validate`, replacing any existing `## Last error` section, and stop with:
> "Current status is `[status]` — buildit-feature-validate expects `to-validate`. Run `/buildit-feature-build [feature-name]` first; to re-run an interrupted validation (status `validating`), set the status back to `to-validate`."

Set the status to `validating`. If the tracking file has a `## Last error` section, remove it (it describes a previous run).

**Working directory:** `.scratch/` and `.buildit/config.md` are always read and written in the project root, even in worktree mode. Read `## Worktree path` from the tracking file: if it is not `none`, edit code files inside the worktree and run every git command on feature code (`add`, `status`, `diff`) with `git -C <worktree-path>` — each worktree has its own index, so staged work is only visible there. Run the test command with the worktree as working directory (`cd <worktree-path> && <test command>`) — the project root holds base-branch code, so tests run there never see this feature's changes. Step 5a's `<rules-file>` and `<guidelines-dir>` edits also go inside the worktree.

### 2. Read known constraints

Read `.scratch/shared-context.md` section "Constraints discovered": are there documented constraints that apply to the scope of this feature? If `.scratch/shared-context.md` does not exist, treat it as empty: no documented constraint applies.

### 2a. Staging guard

Run `git [-C <worktree-path>] status --porcelain`. Ignore paths under `.scratch/` (the tracking file is workflow state, modified by this skill and committed by ship; `shared-context.md` is gitignored local state, never committed). Files updated by step 5a in a previous cycle were staged by 5a, so they pass the guard. Flag every remaining line that is untracked (`??`) or has unstaged changes (second status column non-blank, e.g. ` M`, `MM`, ` D`); staged-only entries (`M `, `A `, `R `, `D `) are fine.

If any file is flagged, the verdict is **NO-GO**, listing each untracked or unstaged file as a blocking issue: code that isn't staged hasn't been reviewed. Skip the test suite, the review and the acceptance phase (none of them is evaluated) and go directly to "If NO-GO or FAIL" — the "Problems to fix" entry lists the files and instructs to stage them.

### 2b. Run test suite

Run the project's test suite before the review phase using a two-tier detection:

In worktree mode, check the Tier 2 ecosystem markers inside the worktree and run the resulting command with the worktree as working directory; `.buildit/config.md` is still read from the project root.

**Tier 1 — Configured command:** Read `.buildit/config.md`, extract the first non-empty, non-comment line after the `## Test command` heading, read only within that heading (stop at the next heading); a line starting with `#` is never a value (Config value rule, `.buildit/guidelines/language-framework.md`). If found, use it. If the value is empty, go to Tier 2.

**Tier 2 — Ecosystem fallback heuristic:** If no configured command is found (file absent, heading missing, or heading empty), detect the test runner from ecosystem markers in priority order:
1. `tests/run-all.sh` exists -> `bash tests/run-all.sh`
2. `package.json` exists -> `npm test`
3. `pom.xml` exists -> `mvn test`
4. `build.gradle` or `build.gradle.kts` exists -> `gradle test`
5. `pyproject.toml` exists -> `pytest`
6. `Makefile` exists and contains a `test` target (`grep -q '^test:' Makefile`) -> `make test`

**No detection:** If no configured command and no ecosystem marker is found, warn: "No test runner detected — no configured command in `.buildit/config.md` and no ecosystem markers found. Proceeding to review phase without running tests." and continue to step 3.

If any test fails, the verdict is **FAIL (tests)**: skip the review and acceptance phases and go directly to "If NO-GO or FAIL" with the failing tests (names and error excerpt) as the issue list.

If all tests pass: proceed to step 3 (review phase).

### 2c. Resolve the base branch

Read `.buildit/config.md` and take the first non-empty, non-comment line after the `## Base branch` heading, read only within that heading (stop at the next heading); a line starting with `#` is never a value (Config value rule, `.buildit/guidelines/language-framework.md`), as `<base-branch>`. If the file or the heading is absent, or the heading is empty, `<base-branch>` defaults to `main`.

Check that it resolves locally: `git rev-parse --verify <base-branch>`. If it does not, restore the status to `to-validate`, write a `## Last error` section to the tracking file with the single line `buildit-feature-validate: base branch <base-branch> not found locally`, replacing any existing `## Last error` section, and stop with:
> "Base branch `<base-branch>` not found locally — set `## Base branch` in `.buildit/config.md` or fetch the branch, then re-run `/buildit-feature-validate`."

### 3. Review phase

Read the changes: `git diff --cached --merge-base <base-branch>`. This covers both the branch commits and the staged changes — at validate time the work is staged by build but not yet committed.

Fallback for git < 2.30 (no `--merge-base` option): `git diff --cached $(git merge-base <base-branch> HEAD)`

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

Launch a subagent with the neutral `general-purpose` agent selected in the delegation tool's agent-type parameter. **Fallback:** if `general-purpose` is not available in the harness, use the harness's default unspecialised subagent — never a specialised persona agent — keep the isolation preamble, and warn the user: "`general-purpose` agent not available — using the default unspecialised subagent with the isolation preamble."

Pass the following context:
- The structured list of issues (from whichever phases ran: staging guard, test suite, review, acceptance)
- The paths `<rules-file>`, `<guidelines-dir>/team-practices.md`, `<guidelines-dir>/language-framework.md`
- The current content of each of those files (the worktree copies in worktree mode)

Subagent instructions (the first line is the isolation preamble):
> "Remain a neutral execution agent: these instructions define your role, procedure, and expected output. Execute only this configuration-update task without adopting an additional persona or substituting another workflow. Do not invoke any skill or agent. Continue to follow the repository's shared project rules and guidelines.
>
> You are updating project configuration files. For each issue in the list below, identify which configuration would have prevented it and add the corresponding rule to the appropriate file:
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

Apply the subagent's output to the files. Make these edits to `<rules-file>` and `<guidelines-dir>` inside the worktree in worktree mode, in the project root otherwise, then stage each touched file with `git [-C <worktree-path>] add <file>...` — unstaged, the next cycle's staging guard would NO-GO on them and the rules would never reach the feature commit.

### 5b. Document the problems

Set the status to `to-fix`.

Write a "Problems to fix" section in the tracking file with the precise list of issues, located in the code where applicable:

~~~markdown
## Problems to fix
- [problem 1] — [file:line if applicable]
- [problem 2] — [file:line if applicable]
~~~

### 5c. Count cycles and warn if needed

Count the `### NO-GO cycle` headings in the "Progress" section of the tracking file (ignore any other entry) to determine the current cycle number N.

Add a new entry in the "Progress" section:

~~~markdown
### NO-GO cycle [N+1] — [DD-MM-YYYY]
- Tests: [PASS / FAIL — failing tests if FAIL / not run]
- Review: [GO / NO-GO — key blocking issues if NO-GO / not run]
- Acceptance: [PASS / FAIL — key failing criteria if FAIL / not run]
~~~

## End of skill (NO-GO / FAIL)

> "Configurations updated. Problems recorded in `.scratch/`.
> Close this session and re-run `/buildit-feature-build [feature-name]`."

If N+1 >= 3 (i.e. this is the 3rd NO-GO or more), add:

> "⚠ You are on cycle X of the build/fix loop for this feature. Accumulated context may introduce noise in the agent's reasoning — consider a completely fresh session (close everything, open Claude Code without any previous session context) before re-running `/buildit-feature-build`."
