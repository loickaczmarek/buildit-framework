---
name: buildit-project-bootstrap
description: "Use when starting a new project or auditing an existing one — scans guidelines, existing practices, and does a light coring of the codebase before generating or updating the configuration kit."
---

# Project Bootstrap

Scans the actual state of the project (guidelines, existing practices, source code) before generating or updating the multi-agent workflow v2 configuration kit.

## Instruction-layer constraints

> **Path guard — mandatory for all steps:**
> All file reads, writes, and shell commands must execute within the project root (the directory containing this skill's CLAUDE.md or `.buildit/`). Do not navigate outside the project root.
> External practices (Confluence pages, Notion docs, URLs) must be fetched via web tools (WebFetch / WebSearch), never via filesystem access.

## When to use

- When starting a new project, before the first feature
- On an existing project to detect drift between configurations and actual practices, and resynchronise them

## Steps

### 0. Detect environment paths

Determine your operating mode from your agent identity:
- You are a **Claude / Claude Code** agent → **Claude mode**: `<rules-file>` = `.claude/CLAUDE.md`
- You are any **other agent** (Copilot, generic) → **Generic mode**: `<rules-file>` = `.agents/guidelines/project-rules.md`

In all cases: `<guidelines-dir>` = `.buildit/guidelines/`

Then ask:
> "Detected mode: **[mode]**. Confirm? (or type `claude` / `generic` to switch)"

Use the confirmed mode for `<rules-file>` and `<guidelines-dir>` as shorthand in all steps below.

---

### 1. Scan existing guidelines

List all files present in `<guidelines-dir>` (not just the 2 expected by the template).

For each file found, note:
- Its name and apparent role
- Whether it belongs to the workflow templates (`team-practices.md`, `language-framework.md`) or is project-specific (e.g. `figma.md`, `jira.md`, `design-system.md`)

If `<guidelines-dir>` does not exist or is empty → note the absence and continue.

---

### 2. Detect workflow configuration files

Check for the existence of the 4 workflow files:
- `<rules-file>`
- `<guidelines-dir>/team-practices.md`
- `<guidelines-dir>/language-framework.md`
- `.scratch/shared-context.md`

---

### 2b. Detect autonomy settings

Run `pwd` to detect the absolute project root path. Never hardcode it.

> ⚠️ **Worktree constraint:** `settings.local.json` is gitignored and is NOT present in git worktrees. All permissions needed by subagents running inside worktrees MUST be in `settings.json` (tracked by git). Never rely on `settings.local.json` for worktree permissions.

**Claude mode:**

Check whether `.claude/settings.json` exists in the project root.

- **Absent** → ask the user:

> "Autonomy settings missing — do you want to create `.claude/settings.json` with project-scoped defaults?"

  If the user confirms, create `.claude/settings.json` using the template below, substituting `<project-root>` with the absolute path detected via `pwd`:

~~~json
{
  "permissions": {
    "allow": [
      "Bash(cd <project-root>*)",
      "Bash(cd ./*)",
      "Bash(cd */.worktrees/*)",
      "Bash(git *)",
      "Bash(npm *)",
      "Bash(yarn *)",
      "Bash(pnpm *)",
      "Bash(python3 *)",
      "Bash(make *)",
      "Bash(docker *)",
      "Bash(grep *)",
      "Bash(find *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(chmod *)"
    ]
  }
}
~~~

  Note: three `cd` patterns work together — absolute paths scoped to the project root, `Bash(cd ./*)` for relative subdirectory navigation, and `Bash(cd */.worktrees/*)` for subagents running inside git worktrees. None allows `cd ..` or parent-directory escape. The broad `Bash(cd *)` pattern is intentionally excluded.

- **Found** → Read the file and audit the `permissions.allow` array for these essential rules:
  - `"Bash(cd <project-root>*)"` — covers `cd /abs/path && git ...` in the project and its worktrees
  - `"Bash(cd ./*)"` — covers relative navigation
  - `"Bash(cd */.worktrees/*)"` — covers subagents running inside git worktrees (required for worktree isolation)
  - `"Bash(git *)"` — covers bare git commands

  - **All present** → report: "Autonomy settings: complete (`.claude/settings.json`)." — do NOT modify.
  - **Some missing** → report which rules are absent, then ask:

    > "Autonomy settings: `.claude/settings.json` found but missing [X, Y] rules. Add them? (worktree subagents need these to run without prompts)"

    If the user confirms, merge the missing rules into `permissions.allow` in the existing file — preserve all other content and existing rules.

**Generic / Copilot mode:**

Read `~/.config/github-copilot/cli/permissions-config.json`. Check whether an entry matching the current project path exists.

- **Found** → report: "Autonomy settings: found (Copilot config)".
- **Absent or file missing** → report: "Autonomy settings: absent (Copilot config — no entry for this project path)".

Generate no file in Generic mode.

---

**Fast path:** If `<guidelines-dir>` already contains `team-practices.md` and `language-framework.md`, and only `<rules-file>` is absent → ask:
> "Guidelines already exist. Do you want to (1) just regenerate the rules file [fast], or (2) also re-scan the codebase for drift [full]?"
- Fast → skip steps 3 and 4a–4d, but still run 4e and 4f — when `.buildit/config.md` already holds a non-empty `## Test command` / `## Base branch` value (Config value rule), propose that existing value for confirmation instead of re-detecting, and preserve it as-is when confirmed; then go to step 5
- Full → continue with all steps

---

### 3. Ask whether a practices directory exists

> "Is there a directory or document that lists the existing practices of the project? (e.g. `docs/`, `adr/`, `CONTRIBUTING.md`, Confluence, Notion, other)"

- **No** → continue to step 4
- **Yes** → ask for the path or URL, then ask:

> "How do you want to integrate these practices?
>
> - **Merge** — I read the content and integrate the relevant practices into the corresponding guidelines
> - **Reference** — I only add a reference link at the top of the relevant guidelines, without duplicating the content"

Store the answer to use in step 8.

---

### 4. Light coring of the source code

Read the actual state of the project to detect practices in place. Perform in order:

**4a. Directory structure**

List first-level directories, then go one level deeper into typical source folders (`src/`, `app/`, `lib/`, `packages/`, etc.).

Identify:
- The apparent organisation: by feature, by type (components/hooks/services), by domain, monorepo…
- Test directories and their location (co-located, `__tests__/`, `test/`…)

**4b. Configuration files**

Read the configuration files present: `package.json`, `pyproject.toml`, `go.mod`, `eslint.config.*`, `.prettierrc`, `tsconfig.json`, or equivalents.

Extract:
- Effective stack and version (framework, runtime, main dependencies)
- Configured style rules (lint, format)

**4c. Naming conventions**

List 10 to 15 file names in the source folders. Observe:
- Casing used: kebab-case, camelCase, PascalCase, snake_case
- Suffix patterns: `.service.ts`, `.test.tsx`, `.stories.tsx`, `.spec.ts`…

**4d. 2 representative files**

Read one main source file and one test file. Observe:
- Internal organisation (imports, exports, structure)
- Visible recurring patterns

**4e. Test command detection**

Detect the project's test command by checking ecosystem markers in priority order:

1. `tests/run-all.sh` exists -> `bash tests/run-all.sh`
2. `package.json` exists -> `npm test`
3. `pom.xml` exists -> `mvn test`
4. `build.gradle` or `build.gradle.kts` exists -> `gradle test`
5. `pyproject.toml` exists -> `pytest`
6. `Makefile` exists and contains a `test` target (`grep -q '^test:' Makefile`) -> `make test`

If a marker is detected, propose the command for confirmation:
> "Detected test command: `[command]`. Confirm or provide the correct command:"

If no ecosystem marker is detected, ask the user:
> "No test runner detected. Please provide the test command (or type `skip` to leave unconfigured):"

Store the confirmed command in `.buildit/config.md` under `## Test command` (see step 8 for the file template).

**4f. Base branch detection**

Detect the branch that validate and ship compare against: run `git symbolic-ref refs/remotes/origin/HEAD` and strip the `refs/remotes/origin/` prefix. If the command fails (no remote, or `origin/HEAD` not set), fall back to `main`.

Propose it for confirmation:
> "Detected base branch: `[branch]`. Confirm or provide the correct branch:"

Store the confirmed branch in `.buildit/config.md` under `## Base branch` (see step 8 for the file template).

---

**Coring summary:** at the end of 4a–4f, write a short summary of detected practices, organised as:
- Architecture / organisation
- Naming conventions
- Confirmed stack
- Test signals
- Test command (detected or user-provided)
- Base branch (detected or user-provided)

---

### 5. Analyse and present the full diagnostic

Cross-reference the information collected in steps 1 to 4 and present a diagnostic to the user in one go, before writing anything:

~~~
## Diagnostic

**Environment**
- Mode: Claude / Generic
- Rules file: <rules-file>
- Guidelines directory: <guidelines-dir>
- Autonomy settings: [found / absent / skipped]

**Existing guidelines**
- Workflow template files: [list]
- Project-specific files: [list or "none"]

**Practices detected in code** (coring)
- Architecture: [summary]
- Naming: [summary]
- Stack: [summary]
- Tests: [summary]

**Detected drift**
- [practice seen in code but absent from guidelines]
- [rule in guidelines that contradicts what is seen in code]
- [missing section in template files]

**Planned actions**
- [list of what will be created, updated, merged, or referenced]
~~~

Ask for confirmation:
> "I will proceed. Do you confirm?"

Wait for confirmation before continuing.

---

### 6. Collect missing information

If the stack could not be determined by coring, ask:
- Framework / stack and version
- Project type (SaaS, REST API, mobile app, etc.)

If the stack is known, simply confirm:
> "Detected stack: [stack]. Is that correct?"

### 6b. Configure task synchronization (optional)

Ask whether `.scratch/plan/` tasks should be synchronized with an external tool (see `buildit-plan` step 5b for the protocol):
- **Yes** → ask for the synchronization method (a plain-language description of the tool, target and access method — never a shell command, never secrets; authentication stays in the tool) and the tag identifying plan-owned tickets (default `technical`). Store `enabled`, the method and the tag in `.buildit/config.md`.
- **Explicitly disabled** → store `disabled`.
- **Skipped** → leave the values empty: unconfigured, not disabled (`buildit-plan` will ask again).

If the headings already exist with values, preserve them unless the user changes them.

---

### 7. Create directories if absent

- `<guidelines-dir>/`
- `.scratch/`
- `.scratch/done/`

---

### 8. Create or update files

Apply the actions announced in the diagnostic. All paths below use `<rules-file>` and `<guidelines-dir>` as detected in step 0.

**For workflow template files**, apply the following rules based on the state detected in step 2:
- File absent → create from template
- File present → update: preserve accumulated content, fill missing sections, fix identified drift

**For `shared-context.md` specifically:**
- Do not touch the "Merge readiness" section if features are active (`IN_PROGRESS`)
- Add the "Decisions & Conventions" section if it is absent (section introduced after workflow v1)

**For practices detected in code (coring):**
- Integrate detected naming conventions into `<guidelines-dir>/team-practices.md`
- Integrate confirmed stack into `<guidelines-dir>/language-framework.md`
- Integrate observed architecture patterns into the appropriate guideline

**For external practices (step 3):**
- **Merge** mode → read the content, extract relevant practices, integrate into the corresponding guidelines
- **Reference** mode → add at the top of each relevant guideline:
  ```
  > Reference: [path or URL]
  ```

**Project-specific files** (e.g. `figma.md`, `jira.md`) → do not modify, keep as-is.

**Reference templates** for workflow files (create at the detected paths):

`<rules-file>`:

~~~markdown
# Project Rules

## Guidelines

Project guidelines are shared across agents in `.buildit/guidelines/`:
- `.buildit/guidelines/team-practices.md` — team conventions, test patterns, naming
- `.buildit/guidelines/language-framework.md` — stack constraints, APIs, versions

## Agent workflow
- Development loop: plan → self-critic → failing tests → execute → review → acceptance → commit
- Tracking files in .scratch/ — format: DD-MM-YYYY-feature-name.md
- Status in each tracking file: to-build → building → to-validate → validating → to-ship (to-fix on NO-GO, loops back to building)
- Before setting status to to-validate, stage every file created or modified during the build (outside .scratch/) and confirm with git status --porcelain that no relevant untracked or unstaged file remains — the validate staging guard returns NO-GO otherwise

## Parallel coordination
- shared-context.md structured in 4 sections (API & Contracts, Constraints, Decisions & Conventions, Merge readiness)
- Cleaning shared-context.md mandatory in the closing commit
- Durable constraints → migrate into the appropriate guideline at commit

## Git
- Branch convention: feature/YYYY-MM-DD-name, bugfix/..., chore/...
- Commit format: type(scope): description — explain the WHY
~~~

`<guidelines-dir>/team-practices.md`:

~~~markdown
# Team Practices

## TDD
- Write tests before implementation
- Tests must fail for the right reasons before implementing
- Re-run tests after each significant file modification

## Review
Mandatory evaluation dimensions:
- Correctness: does the code do what is asked?
- Performance: unnecessary costly operations?
- Security: injection vectors, data exposure?
- Style: project conventions respected?
- Test coverage: edge cases tested?

## Commits
Format: type(scope): short description
Types: feat, fix, chore, refactor, test, docs
The commit description explains the WHY, not the what.

## Branches
- feature/YYYY-MM-DD-short-name
- bugfix/YYYY-MM-DD-short-name
- chore/YYYY-MM-DD-short-name

## .scratch/
File name format: DD-MM-YYYY-feature-name.md
Move to .scratch/done/ at the closing commit.

Tracking file sections: Status · Goal · Acceptance Tests · Plan · Progress
Status flow: to-build → building → to-validate → validating → to-ship (to-fix on NO-GO, loops back to building)
Progress: one entry per NO-GO cycle, added by feature-validate
~~~

`<guidelines-dir>/language-framework.md` (fill Stack with collected information):

~~~markdown
# Language & Framework

## Stack
- Framework: [detected or provided value]
- Version: [detected or provided value]
- Runtime: [detected or provided value]

## Preferred patterns
[enriched as features are shipped]

## Patterns to avoid
[enriched as features are shipped]

## Known behaviours / constraints
[automatically enriched via shared-context.md at merge]
~~~

`.scratch/shared-context.md`:

~~~markdown
# Shared Context

## API & Contracts modified
<!-- Fill when you change an interface, type, endpoint or signature -->

## Constraints discovered
<!-- Fill when you discover a technical limitation or unexpected behaviour -->

## Decisions & Conventions
<!-- Fill when you intentionally introduce a new practice: architecture, naming, code pattern -->

## Merge readiness

| Branch | Status | Main files touched | Waiting for |
|--------|--------|--------------------|-------------|
~~~

`.buildit/config.md` (create with the test command detected in step 4e, the base branch detected in step 4f, and the synchronization answers from step 6b). If `.buildit/config.md` already exists, update only the headings whose values changed and preserve every other heading and value:

~~~markdown
# Project Configuration

## Test command
<!-- Auto-detected by bootstrap, confirmed by user -->
[confirmed test command here, or empty if skipped]

## Base branch
<!-- Branch the review diff and overlap check compare against; auto-detected by bootstrap, default main when absent or empty -->
[confirmed base branch here]

## Task synchronization
<!-- enabled or disabled; empty = unconfigured (step 6b) -->
[enabled/disabled, or empty if skipped]

## Synchronization method
<!-- Plain-language description of tool, target and access method; no shell command, no secrets -->
[method description, or empty]

## Synchronization tag
<!-- Identifies plan-owned external tickets; default technical when absent or empty -->
[tag, or empty]
~~~

The test command is the raw shell command on a single line after the `## Test command` heading. Convention: the command is the first non-empty, non-comment line after the heading, read only within that heading (stop at the next heading); a line starting with `#` is never a value (Config value rule, `.buildit/guidelines/language-framework.md`); an empty `## Test command` makes validate fall back to ecosystem detection. The same convention applies to `## Base branch`, which defaults to `main` when absent or empty, and to the synchronization headings: an empty `## Task synchronization` is unconfigured, not disabled, and an empty `## Synchronization tag` means the default `technical`.

---

### 9. Commit

For Generic mode re-bootstrap: if `.agents/guidelines/team-practices.md` or `.agents/guidelines/language-framework.md` exist, remove them first (legacy format).

```bash
# Claude mode:
git add .claude/ .buildit/ .scratch/
# Generic mode:
git rm --ignore-unmatch .agents/guidelines/team-practices.md .agents/guidelines/language-framework.md
git add .agents/guidelines/project-rules.md .buildit/ .scratch/
git commit -m "chore(config): bootstrap project configuration from workflow v2"
```

## End of skill

> "Bootstrap complete. You can now run `/buildit-feature-start` for your first feature."
