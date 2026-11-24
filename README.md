# buildit — Multi-Agent Development Workflow

A framework of 10 skills (9 user-facing + the internal `buildit-worktree`) that drive the development loop feature by feature. The default path is `buildit-feature-run` — it orchestrates the full cycle unattended. A manual sequence (start → build → validate → ship) is available for features needing mid-cycle human judgement.

## Setup

After cloning, activate the pre-push test guard:

```bash
bash scripts/install-hooks.sh
```

This configures git to use `scripts/hooks/` as the hooks directory. Every `git push` will run the full test suite and abort on failure.

---

## Running tests

```bash
bash tests/run-all.sh
```

`tests/run-all.sh` runs every `tests/test-*.sh` file and aggregates the results; it exits non-zero on any failure.

**Content-assertion convention:** skills are markdown, so tests assert on their content rather than executing them. Each skill has a `tests/test-<skill>.sh` that checks its `SKILL.md` (and the README or guidelines when a feature documents itself there) for the required instructions, wording and ordering. `tests/test-readme.sh` covers the README.

Shared helpers live in `tests/lib/assertions.sh`: `require_file`, `require_text` (fixed string), `require_regex` (extended regex) and `require_absent` (regex that must not match). Each test file sources it and ends with a `Results: N passed, M failed` line.

---

## Default flow — `buildit-feature-run`

The recommended path for most features — runs the full cycle unattended:

```
[buildit-project-bootstrap]  ← new project or resync
        │
        ▼
[buildit-plan]  (optional) ← decompose PRD/spec → ordered tasks
        │
        ▼
[buildit-feature-discover]  (optional) ← scope vague feature → structured brief
        │
        ▼
[buildit-feature-run]  ← full cycle unattended
        │
        ├─ start    → plan + self-critic + init shared-context
        ├─ build    → TDD + implementation + craft-principles self-review
        ├─ validate → 6-dimension review + acceptance tests
        │    ├─ GO     → ship
        │    └─ NO-GO  → loop back to build (max N cycles, default 3)
        └─ ship     → readiness check + shared-context cleanup + retro + commit
                      (push + PR remain manual)
```

Each phase runs in a fresh subagent for context isolation — no manual clear-context needed. The orchestrator reads the tracking file status between phases to route GO/NO-GO decisions automatically.

**Parallelisation:** multiple features can run simultaneously on separate worktrees. Worktree management is handled internally by the framework via the `buildit-worktree` skill — no external tooling needed. Coordination goes through `.scratch/shared-context.md`.

---

## Manual flow (advanced)

For complex features where mid-cycle human judgement is needed, run each skill separately with a context-clear between phases:

```
[buildit-feature-start]              ← plan + self-critic + init shared-context
        │
   🔄 CLEAR CONTEXT
        │
        ▼
[buildit-feature-build]  ◄───────────────────────────────────┐
   TDD + implementation                                      │
        │                                                    │
   🔄 CLEAR CONTEXT                                          │
        │                                                    │
        ▼                                                    │
[buildit-feature-validate]                                   │
   staging guard + 6-dimension review + acceptance tests     │
        │                                                    │
   ┌────┴────┐                                               │
  GO        NO-GO / FAIL                                     │
   │          │                                              │
   │    updates configs                                      │
   │    writes problems to .scratch/                         │
   │    🔄 CLEAR CONTEXT ────────────────────────────────────┘
   │
   ▼
[buildit-feature-ship]
   readiness + commit + shared-context cleanup + retro
   (push + PR are manual)
```

**Why clear-context?** Each session accumulates contextual noise. Cutting between phases keeps reasoning clean, especially across build/fix cycles.

---

## Tracking file structure

Each feature creates `.scratch/DD-MM-YYYY-[feature-name].md`:

```markdown
# [feature-name]

## Status
to-build | building | to-validate | validating | to-fix | to-ship

## Worktree path
[absolute path, or "none" if no worktree]

## Goal
[short description]

## Acceptance Tests
[list of criteria]

## Plan
[implementation steps]

## Progress
[session notes, decisions]

## Problems to fix
[filled by feature-validate on NO-GO/FAIL — cleared at the start of the next cycle]
```

**Status lifecycle:**

| Skill | Transition |
|-------|-----------|
| `buildit-feature-start` (end) | → `to-build` |
| `buildit-feature-build` (start) | `to-build` or `to-fix` → `building` |
| `buildit-feature-build` (end) | → `to-validate` |
| `buildit-feature-validate` (start) | → `validating` |
| `buildit-feature-validate` GO + PASS | → `to-ship` |
| `buildit-feature-validate` NO-GO or FAIL | → `to-fix` |
| `buildit-feature-ship` | file moved to `.scratch/done/` |

---

## Parallel coordination — `shared-context.md`

`.scratch/shared-context.md` is the coordination zone between parallel worktrees. It has **4 fixed sections**:

- **API & Contracts modified** — signature changes, endpoints, types that impact other branches
- **Constraints discovered** — technical limitations or unexpected behaviours that could waste other teams' time
- **Decisions & Conventions** — new practices intentionally introduced: architecture, naming, code patterns
- **Merge readiness** — status table per branch (`IN_PROGRESS` → `READY`)

The distinction between "Constraints" and "Decisions" is intentional: constraints are reactive (discovered in response to a problem), decisions are proactive (deliberate choices). Both migrate into guidelines at ship time, but via different decision trees.

This file must be empty between parallel sprints. Cleanup happens in each feature's closing commit (`buildit-feature-ship`).

---

## Autonomy configuration

`buildit-feature-run` passes an autonomy instruction to each phase subagent so it can execute commands without prompting for permission at every step.

### Subagent autonomy instruction

Each subagent receives this block in its prompt (with `[PROJECT_ROOT]` and `[MODE]` substituted at runtime):

```
Autonomy: you are operating within the project directory `[PROJECT_ROOT]` (mode: [MODE]).
Execute bash, python3, and cd commands freely within this directory and its subdirectories.
Use relative paths for script invocations. Do not cd outside the project root — paths outside require explicit user permission.
```

- **`PROJECT_ROOT`** — absolute path detected via `pwd` at orchestrator start
- **`MODE`** — `claude` if `.claude/` directory exists at project root, `generic` otherwise

### Subagent isolation

Every subagent launched by `buildit-feature-run`, `buildit-project-audit`, and `buildit-feature-validate` (config-update step) uses the neutral `general-purpose` agent and receives an isolation preamble as the first line of its prompt: it executes only the requested skill or task, adopts no extra persona, and invokes no other skill or agent (phase subagents may still use the buildit skills and subagents their phase skill explicitly references or instructs them to launch, e.g. `buildit-worktree` or the `buildit-feature-validate` config-update subagent). If `general-purpose` is unavailable, the harness's default unspecialised subagent is used with the same preamble, and the user is warned.

### settings.json permission file (Claude mode only)

In Claude mode, a `.claude/settings.json` allowlist reduces per-command permission prompts during automated runs. Run `/buildit-project-bootstrap` to auto-generate this file if absent.

Template (substitute `<project-root>` with the absolute project path):

```json
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
```

Three `cd` patterns work together: `Bash(cd <project-root>*)` for absolute paths scoped to the project root, `Bash(cd ./*)` for relative subdirectory navigation, and `Bash(cd */.worktrees/*)` for subagents running inside git worktrees. None allows `cd ..` or parent-directory escape. The broad `Bash(cd *)` pattern is intentionally excluded.

---

## Project configuration

`.buildit/config.md` holds project-level settings. Each value is the first non-empty, non-comment line after its `## Heading`, read only within that heading (stop at the next heading); a line starting with `#` is never a value; an empty value is treated as absent — no YAML/JSON. Never store secrets (tokens, passwords, API keys) in this file: describe access methods in plain language instead.

| Key | Meaning | When absent or empty | Written by |
|-----|---------|----------------------|------------|
| `## Test command` | Shell command that runs the test suite | Validate falls back to ecosystem detection | `buildit-project-bootstrap` (step 4e) |
| `## Base branch` | Branch the review diff and overlap check compare against | `main` | `buildit-project-bootstrap` (step 4f, from `origin/HEAD`) |
| `## Task synchronization` | `enabled` or `disabled` | Unconfigured | `buildit-project-bootstrap` (step 6b) or `buildit-plan` |
| `## Synchronization method` | Plain-language description of tool, target and access method — never a shell command | — | `buildit-project-bootstrap` (step 6b) or `buildit-plan` |
| `## Synchronization tag` | Tag identifying plan-owned external tickets | `technical` | `buildit-project-bootstrap` (step 6b) or `buildit-plan` |

**Unconfigured, not disabled:** an absent, empty or unrecognized `## Task synchronization` means the choice was never made. Only `buildit-plan` and `buildit-project-bootstrap` prompt to configure it; every other skill treats unconfigured as disabled and never prompts.

Example:

```markdown
# Project Configuration

## Test command
bash tests/run-all.sh

## Base branch
main

## Task synchronization
enabled

## Synchronization method
GitHub issues of this repository, via the gh CLI already authenticated on the machine

## Synchronization tag
technical
```

---

## Plan files

`buildit-plan` writes its decomposition to `.scratch/plan/`:

- `plan.md` — source reference, epics (3 or more tasks) or a flat list, and one line per task: `- [ ] task-{name} (priority) [ready|needs-scoping] — Title`, with `Progress: X/N done` counters computed from task statuses
- `task-{name}.md` — one file per task:

```markdown
# [Title]

## Status
todo

## Priority
high

## Parent epic
none

## Description
[task description]

## Acceptance tests
[verifiable criteria]

## Readiness
ready

## Synchronization
Link: <tool/target> <stable-ID-or-URL>
Pending: status → in-progress (24-11-2026)
```

**Status lifecycle:** `todo` → `in-progress` (when `buildit-feature-run` starts the task) → `done` (after ship).

**Readiness:** `ready` (bounded scope, verifiable acceptance tests) or `needs-scoping` (vague, unbounded, or missing acceptance tests). `buildit-feature-discover` turns a `needs-scoping` task into `ready` and updates the `plan.md` tag accordingly.

**`## Synchronization`** (optional, only once a link to an external ticket is confirmed):
- `Link:` — external tool/target and the ticket's stable ID or URL, used as identity (never the title)
- `Pending: <field> → <value> (DD-MM-YYYY)` — an external write that was refused or failed; one line per field, the latest replaces the previous one. Only `buildit-plan` clears them

**Field ownership** — locally and in external writes when synchronization is enabled:

| Skill | Owns |
|-------|------|
| `buildit-feature-run` | Status (and the `plan.md` checkbox and counters) |
| `buildit-feature-discover` | Description, Acceptance tests, Readiness (and the `plan.md` readiness tag) |
| `buildit-plan` | Full bidirectional reconcile with the external tool (step 5b) |

External writes happen from the orchestrator, never inside a subagent, after one explicit confirmation per invocation, and only for tasks with a `Link:`. A refusal or failure records a `Pending:` entry and never blocks the local flow.

---

## Skills

### `buildit-project-bootstrap`

**Trigger:** `/buildit-project-bootstrap`

**When to use:** at three distinct moments in a project's lifecycle:

| Use case | When | What happens |
|----------|------|-------------|
| **New project** | Before the first feature | Detects the stack from the code, generates the pre-filled configuration kit with actual conventions |
| **Audit / resync** | When guidelines have drifted from actual practices | Cross-references configs and code to find drift, proposes resynchronisation |
| **External practices integration** | When adopting practices from an existing doc (Confluence, `docs/`, ADR…) | Merges content into guidelines or adds a reference link |

**What it does:**
1. Detects agent identity (Claude vs other agent) and asks for mode confirmation
2. Scans `.buildit/guidelines/` to detect all files present — custom files (`figma.md`, `jira.md`…) are preserved without modification
3. Checks autonomy settings (`.claude/settings.json` in Claude mode) — creates or audits the permission allowlist for worktree subagents
4. Asks whether a directory or document of existing practices exists, and if so proposes to **merge** it into the guidelines or **reference** it (link at the top of the guideline)
5. Performs a light coring of the source code: directory tree, config files, naming conventions, 2 representative files, and **test command detection** — auto-detects the project's test runner from ecosystem markers (`tests/run-all.sh`, `package.json`, `pom.xml`, `build.gradle`, `pyproject.toml`, `Makefile`), proposes the command for user confirmation, and stores it in `.buildit/config.md`
6. Presents a complete diagnostic (drift, gaps, planned actions) and waits for confirmation before writing
7. Optionally configures task synchronization with an external tool (enabled/disabled, plain-language method, tag — default `technical`); skipping leaves it unconfigured
8. Creates or updates the workflow files integrating what was detected — including `.buildit/config.md` with the confirmed test command and synchronization headings
9. Commits everything: `chore(config): bootstrap project configuration from workflow v2`

For `shared-context.md`, active features (`IN_PROGRESS`) are always preserved.

---

### `buildit-project-audit`

**Trigger:** `/buildit-project-audit [scope]`

**When to use:** for periodic health checks, before major refactoring, after shipping a batch of features, or to assess a specific file/directory/concern area on demand. Not for project setup — use `buildit-project-bootstrap` for that.

**What it does:**
1. Detects agent identity (Claude vs other agent) and checks for `.scratch/shared-context.md`
2. Determines audit scope: uses the provided argument (file, directory, keyword) or launches a subagent for hotspot analysis (git churn + complexity heuristics, capped at top 10 files)
3. Writes a placeholder to `.scratch/audits/DD-MM-YYYY-audit-issues.md` to trigger file-write permission early (before subagent work begins)
4. Defines severity criteria (Critical/High/Medium/Low) with evidence requirements — all downstream subagents enforce these
5. Launches 3 parallel category subagents — code quality (6 dimensions), architecture health, and project health — each returning structured findings
6. As each category completes, launches a per-category critique subagent (receives only that category's findings, enforces evidence-based downgrading) and presents the critiqued results progressively
7. Runs a cross-cutting execution trace subagent to catch cross-file interaction bugs (implicit dependencies, order-of-operations, mock-masked bugs) that parallel categories miss
8. Runs a calibration subagent that normalizes severity across all findings — can downgrade/escalate but cannot add new findings
9. Compiles all findings into the final report grouped by severity, with "Critique integration" and "Calibration" sections

**Ends with:** the final report path and summary. This is a standalone assessment — no status transition. Use findings to plan fixes via `/buildit-feature-start` or `/buildit-feature-run`.

**Design specs:** `docs/buildit/specs/2026-10-19-audit-parallel-pipeline.md`, `docs/buildit/specs/2026-10-19-audit-calibration.md`

---

### `buildit-plan`

**Trigger:** `/buildit-plan [plan-name]`

**When to use:** before starting a batch of features, when the scope is larger than a single feature. Decomposes a PRD, spec, or ad-hoc request into ordered tasks with progress tracking. If the request is already a single well-defined feature, skip this and use `/buildit-feature-discover` or `/buildit-feature-start` directly.

**What it does:**
1. Detects mode (Claude vs generic), reads the task synchronization configuration from `.buildit/config.md` (asks to configure it when unconfigured), and checks for an existing plan (resume detection)
2. Collects input: any structured document (PRD, specs, user stories, bullet points) or ad-hoc request
3. Offers two decomposition paths: fast (auto-decompose then validate) or coaching (collaborative question-driven)
4. Decomposes into tasks with name, description, acceptance tests, priority, and readiness (`ready` or `needs-scoping`)
5. Groups tasks into epics if 3 or more tasks; uses flat list otherwise
6. Creates `.scratch/plan/task-{name}.md` per task and `.scratch/plan/plan.md` with epic index and progress counters
7. When synchronization is enabled, synchronizes selected tasks with the external tool (step 5b) — full reconcile, see [Plan files](#plan-files)
8. On resume: reads existing plan, proposes human-readable titles for slug-only tasks, shows a read-only synchronization drift report, proposes cleanup of `.scratch/done/` files older than 7 days and completed epics, enters coaching mode for modifications, re-syncs progress counters

**Ends with:** explicit handoff listing actionable tasks — suggests `/buildit-feature-discover [task-name]` for `needs-scoping` tasks and `/buildit-feature-run [task-name]` for `ready` tasks.

**Design specs:** `docs/buildit/specs/2026-10-22-buildit-plan-design.md`, `docs/buildit/specs/2026-11-24-plan-task-synchronization.md`

---

### `buildit-feature-discover`

**Trigger:** `/buildit-feature-discover [feature-name]`

**When to use:** before `buildit-feature-start`, when the feature idea is vague or needs validation against project conventions. If the brief is already clear (name + description + acceptance tests), skip this skill and invoke `/buildit-feature-start` directly.

**What it does:**
1. Detects a matching plan task (`.scratch/plan/task-{name}.md`, created by `/buildit-plan`): locks the feature name to the task name, warns and asks confirmation if the task is already `in-progress` or `done`, and short-circuits to `/buildit-feature-run [task-name]` if the task is already `ready` (re-scope remains possible). Otherwise, short-circuits if a complete brief is already provided as argument
2. Reads `shared-context.md`, guidelines, and scans existing skills to extract constraints, conventions and potential overlaps
3. Asks whether external documentation is available (specs, user stories, design doc)
4. Poses targeted functional questions (problem, users, expected behaviour, success criteria) — adapted to what Phase 1 revealed — starting from the plan task description and acceptance tests when a task is detected, without re-asking what they already answer
5. Translates functional answers into a technical description anchored in project conventions, and surfaces actionable risks
6. Produces a structured brief: kebab-case name, technical description, acceptance tests, risks & constraints
7. Presents the brief for user validation; iterates on contested sections only
8. On validation, when a plan task is detected: writes the brief (description, acceptance tests, risks & constraints) into the task file, sets its Readiness to `ready`, and switches its `plan.md` tag from `[needs-scoping]` to `[ready]`. Never touches the task Status (owned by `buildit-feature-run`); nothing is written if the brief is not validated
9. When task synchronization is enabled and the task is linked, pushes its own fields to the external ticket after one confirmation — see [Plan files](#plan-files) for field ownership and `Pending:` entries

**Ends with:** the user chooses between `/buildit-feature-run [feature-name]` (full cycle unattended, recommended) or `/buildit-feature-start [feature-name]` (manual cycle, session by session). When a plan task is detected, `/buildit-feature-run [task-name]` is recommended so the task status is tracked.

---

### `buildit-feature-run`

**Trigger:** `/buildit-feature-run [feature-name] [--max-cycles N]`

**When to use:** the default path for most features. Runs the full cycle (start → build → validate → ship) unattended in a single session. Each phase runs in a fresh subagent for context isolation. Fall back to the manual flow only when mid-cycle human judgement is needed.

**What it does:**
1. Collects inputs (worktree, name, description, acceptance tests) before launching any subagent. When a matching plan task exists (`.scratch/plan/task-{name}.md`), pre-fills inputs and tracks task status automatically. When task synchronization is enabled and the task is linked, pushes only the status after one confirmation — see [Plan files](#plan-files)
2. Delegates `buildit-feature-start` to a fresh subagent; detects the tracking file and worktree path after completion
3. Runs a build/fix loop (max N cycles, default 3): delegates `buildit-feature-build`, reads status, delegates `buildit-feature-validate`, reads status; routes `to-fix` back to build and `to-ship` to the next step
4. On GO + PASS: delegates `buildit-feature-ship`, then verifies that ship committed (new commit on the feature branch + tracking file archived in `.scratch/done/`) — otherwise stops with "Unexpected state after ship" and leaves the plan task and external ticket unchanged — then updates plan task status to done if applicable, then reminds the user that push and PR creation are manual

**Guards:**
- Stops if the tracking file is not found after start (possible subagent failure)
- Stops if the status is unchanged after any phase (stale state detection)
- Stops with an explanation after N cycles without a GO

#### Configuration — `--max-cycles`

| Setting | Value |
|---------|-------|
| Default | `--max-cycles 3` — mirrors the warning threshold in `buildit-feature-validate` |
| Override | Pass `--max-cycles N` as argument (e.g. `--max-cycles 5` for complex features, `--max-cycles 1` for quick iterations) |
| Validation | N < 1 → orchestrator warns and resets to 3 |
| On exhaustion | Orchestrator stops with an explanation; user resumes manually with `/buildit-feature-build` then `/buildit-feature-validate` |

**Guidance:**
- Simple features with narrow acceptance tests → 1–2 cycles expected
- Complex features with broad acceptance tests → allow 3–5 cycles
- If cycles are regularly exhausted, consider splitting the feature into smaller deliverables

**Ends with:** push and PR creation are manual.

---

**Manual flow skills** — the following skills are used individually in the manual flow, or invoked internally by `buildit-feature-run`:

### `buildit-feature-start`

**Trigger:** `/buildit-feature-start [feature-name]`

**When to use:** at the start of each new feature, from the main branch or a dedicated branch, before creating the implementation worktree.

**What it does:**
1. Checks that `.scratch/shared-context.md` exists (otherwise points to `/buildit-project-bootstrap`)
2. Reads `shared-context.md` to detect changed APIs, constraints and decisions/conventions introduced by other branches that affect the plan
3. Collects the feature name, description and acceptance tests (or uses the provided argument; an empty name is asked again)
4. Only then proposes working in an isolated worktree (recommended for non-trivial features) — if yes, calls the internal `buildit-worktree` skill to create and configure it (no external dependency), so a failed start leaves no orphan worktree
5. Generates the tracking file `.scratch/DD-MM-YYYY-[feature-name].md` with the plan, including the feature branch in `## Branch` and the worktree path in a dedicated `## Worktree path` field
6. Critiques the plan: wrong assumptions, edge cases, vague steps, underestimated risks
7. Updates the plan with the corrections
8. Adds the branch (the `## Branch` value) in `shared-context.md` section "Merge readiness" (`IN_PROGRESS`)

**Ends with:** instruction to close the session and run `/buildit-feature-build [feature-name]`.

**Use cases:**
- Starting a standard feature
- Starting a feature in parallel with other active worktrees (the skill reads modified APIs before planning)

---

### `buildit-feature-build`

**Trigger:** `/buildit-feature-build [feature-name]`

**When to use:**
- After `buildit-feature-start` for the first implementation (status `to-build`)
- After `buildit-feature-validate` returned NO-GO or FAIL (status `to-fix`)

**What it does:**

Automatically detects the mode based on the tracking file status. At the end of each mode, explicitly asks whether a new practice was introduced and documents it in `shared-context.md` section "Decisions & Conventions" if so.

**Normal TDD mode** (status `to-build`):
1. Reads the plan and acceptance tests
2. Checks API changes in `shared-context.md`
3. Writes tests — they must fail for the right reasons
4. Implements to make the tests pass, re-runs after each significant file
5. Craft-principles self-review (DRY, KISS, YAGNI — see `.buildit/guidelines/craft-principles.md`)
6. Stages every created/modified file (explicit paths, `.scratch/` excluded) and checks `git status --porcelain` before transitioning to `to-validate` — matching validate's staging guard

**Fix mode** (status `to-fix`, "Problems to fix" section present):
1. Reads the list of problems documented by `buildit-feature-validate`
2. Fixes targeted at the listed problems
3. Re-runs tests after each modification — no restructuring beyond what is necessary

**Ends with:** instruction to close the session and run `/buildit-feature-validate [feature-name]`.

**Use cases:**
- Initial implementation of a feature (TDD mode)
- Resuming after a validation NO-GO (fix mode)
- Re-entry on 2nd, 3rd cycle if the feature requires multiple iterations

---

### `buildit-feature-validate`

**Trigger:** `/buildit-feature-validate [feature-name]`

**When to use:** after `buildit-feature-build` has finished (status `to-validate`).

**What it does:**

**Staging guard** — first, runs `git status --porcelain`; any untracked or unstaged file outside `.scratch/` is an immediate NO-GO listing those files (tests, review and acceptance are skipped), because code that isn't staged hasn't been reviewed.

**Test suite** — runs the project's tests before the review using a two-tier detection: first reads the configured command from `.buildit/config.md` (set by bootstrap); if absent, falls back to ecosystem marker heuristic (same 6 ecosystems as bootstrap). If no test runner is detected, warns and proceeds. A test failure skips review and acceptance and goes through the same NO-GO path below.

**Base branch** — read from `## Base branch` in `.buildit/config.md` (default `main`). If it does not resolve locally, validate restores `to-validate`, records a `## Last error` line in the tracking file (reported by `buildit-feature-run`) and stops.

**Review phase** — evaluates the staged diff against the base branch (`git diff --cached --merge-base <base-branch>`, covering branch commits and staged changes; fallback for git < 2.30) on 6 dimensions without reading the plan (unbiased review):

| Dimension | Question |
|-----------|----------|
| Correctness | Does the code do what is asked? |
| Performance | Unnecessary costly operations? |
| Security | Injection vectors, data exposure? |
| Style | Project conventions respected? |
| Test coverage | Edge cases tested? |
| Craft principles | DRY, KISS, YAGNI respected? |

**Acceptance phase** — for each acceptance test: PASS or FAIL with justification.

**If GO + PASS overall:**
- Status → `to-ship`
- Instruction: close the session and run `/buildit-feature-ship [feature-name]`

**If NO-GO or FAIL (in the same session, before closing):**
1. Launches a subagent with the structured issue list and current guideline files — subagent produces updated file content, main agent applies it
2. Status → `to-fix`, writes the "Problems to fix" section with precise locations
3. Counts build/fix cycles (`### NO-GO cycle` entries in "Progress") — warns if 3rd cycle or more (risk of contextual noise)
4. Instruction: close the session and re-run `/buildit-feature-build [feature-name]`

**Use cases:**
- Systematic validation after each implementation
- Quality checkpoint before shipping
- Trigger for continuous improvement of configurations (issues found enrich guidelines)

---

### `buildit-feature-ship`

**Trigger:** `/buildit-feature-ship [feature-name]`

**When to use:** after `buildit-feature-validate` returned GO + PASS overall (status `to-ship`).

**What it does:**

**1. Readiness check** — reads `shared-context.md` in full and checks:
- File overlap with the other `IN_PROGRESS` branches (this feature's own `## Branch` row is skipped) — this feature's files come from `git diff --cached --merge-base <base-branch> --name-only` (Base branch from `.buildit/config.md`, default `main`), other branches' from `git diff --name-only --merge-base <base-branch> <branch>`, which only sees their commits
- Branches declaring they are waiting for this branch
- APIs modified by other branches not yet accounted for
- Discovered constraints not addressed in this scope

Verdict: **✓ OK to ship** or **⚠ Blocking: [precise reason]**. If blocking, waits for human confirmation — or, when running as a subagent, commits nothing, records the reason in `## Last error` and returns `SHIP BLOCKED: <reason>`.

**2. Shared-context.md cleanup** (root file):
- "Merge readiness" → removes the line for this branch (`## Branch`)
- "API & Contracts modified" → removes the section for this branch
- "Constraints discovered" → decision tree:
  - Feature-specific → delete
  - Durable → migrate into the appropriate guideline (`language-framework.md`, `team-practices.md`, dedicated guideline, or rules file), then delete
- "Decisions & Conventions" → always durable, always migrate into the appropriate guideline, then delete

**3. Light retro** — three questions: what slowed down the loop? would a configuration have prevented it? was the plan precise enough? If a configuration needs changing, it is updated now, before the commit (no amend).

**4. Stage the closing changes** — moves the tracking file to `.scratch/done/` and stages it, the guideline migrations and configuration updates with explicit paths (`git [-C <worktree>] add`, never `add -A`). Shared-context rule: the commit carries only this feature's removals from `shared-context.md` — never the root file as a whole, which holds other features' uncommitted rows (when it does, ship updates the index only via `git update-index --cacheinfo`). In worktree mode, only the archived tracking file is copied into the worktree.

**5. Commit** — format `type(scope): description` (the WHY, not the what).

**6. Worktree cleanup** — worktree mode only: removes the root copy of the archived tracking file, then `git worktree remove` on the `## Worktree path` read once at the start.

**Ends with:** push and PR creation are manual.

**Use cases:**
- Closing a validated feature
- Coordination with other parallel features (the readiness check blocks if needed)
- Automatic enrichment point for project guidelines

---

**Internal** — not invoked directly by users:

### `buildit-worktree`

**Trigger:** called internally by `buildit-feature-start` — not invoked directly by users.

**When to use:** automatically invoked when the user opts into worktree isolation during `buildit-feature-start`. Can also be invoked standalone when setting up a worktree outside the standard cycle.

**What it does:**
1. Derives the branch name `feature/YYYY-MM-DD-[feature-name]` from the current date — refuses an empty feature name and creates nothing
2. Ensures `.worktrees/` is listed in `.gitignore` (appends and commits if absent — `git commit ... -- .gitignore`, so already-staged changes are never swept in)
3. Creates the worktree: `git worktree add .worktrees/feature/YYYY-MM-DD-[feature-name] -b feature/...`
4. Resolves and returns the absolute worktree path (`WORKTREE_PATH`)
5. Instructs the calling agent to use `git -C <WORKTREE_PATH>` for all git commands inside the worktree

**Working directory in worktree mode:** `.scratch/` and `.buildit/config.md` stay in the project root; build, validate and ship run git commands on feature code with `git -C <WORKTREE_PATH>` (each worktree has its own index). Ship copies only the archived tracking file into the worktree and applies this feature's `shared-context.md` removals to the worktree's own copy, so the feature commit never carries other features' rows.

**Design rationale:** replaces the external dependency on `superpowers:using-git-worktrees`. Worktree management is now fully internal to the buildit framework, ensuring consistent behaviour regardless of which superpowers skills are installed.

---

## Continuous improvement loop

Guidelines are automatically enriched with each feature, without a dedicated step:

- **`buildit-feature-validate` NO-GO** → updates configs in the same session (before closing)
- **`buildit-feature-ship`** → migrates durable constraints from `shared-context.md` into the appropriate guidelines

Over time, `language-framework.md`, `team-practices.md` and `craft-principles.md` reflect the real constraints of the project — not anticipations, but accumulated real work.

---

## References

- buildit-plan design: `docs/buildit/specs/2026-10-22-buildit-plan-design.md`
- Plan task synchronization: `docs/buildit/specs/2026-11-24-plan-task-synchronization.md`
- Generic test runner detection: `docs/buildit/specs/2026-10-14-generic-test-runner-detection.md`
- Audit parallel pipeline: `docs/buildit/specs/2026-10-19-audit-parallel-pipeline.md`
- Audit calibration: `docs/buildit/specs/2026-10-19-audit-calibration.md`
