---
name: buildit-project-bootstrap
description: Use when starting a new project or auditing an existing one — scans guidelines, existing practices, and does a light coring of the codebase before generating or updating the configuration kit.
---

# Project Bootstrap

Scans the actual state of the project (guidelines, existing practices, source code) before generating or updating the multi-agent workflow v2 configuration kit.

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

**Fast path:** If `<guidelines-dir>` already contains `team-practices.md` and `language-framework.md`, and only `<rules-file>` is absent → skip steps 3 and 4, go directly to step 5.

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

**Coring summary:** at the end of 4a–4d, write a short summary of detected practices, organised as:
- Architecture / organisation
- Naming conventions
- Confirmed stack
- Test signals

---

### 5. Analyse and present the full diagnostic

Cross-reference the information collected in steps 1 to 4 and present a diagnostic to the user in one go, before writing anything:

~~~
## Diagnostic

**Environment**
- Mode: Claude / Generic
- Rules file: <rules-file>
- Guidelines directory: <guidelines-dir>

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

---

### 9. Commit

```bash
# Claude mode:
git add .claude/ .buildit/ .scratch/
# Generic mode:
git add .agents/guidelines/project-rules.md .buildit/ .scratch/
git commit -m "chore(config): bootstrap project configuration from workflow v2"
```

## End of skill

> "Bootstrap complete. You can now run `/buildit-feature-start` for your first feature."
