# buildit — Multi-Agent Development Workflow

A framework of 9 skills that drive the development loop feature by feature. The default path is `buildit-feature-run` — it orchestrates the full cycle unattended. A manual sequence (start → build → validate → ship) is available for features needing mid-cycle human judgement.

## Setup

After cloning, activate the pre-push test guard:

```bash
bash scripts/install-hooks.sh
```

This configures git to use `scripts/hooks/` as the hooks directory. Every `git push` will run the full test suite and abort on failure.

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
        └─ ship     → readiness check + commit + shared-context cleanup + retro
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
   TDD + implementation                               │
        │                                             │
   🔄 CLEAR CONTEXT                                   │
        │                                             │
        ▼                                             │
[buildit-feature-validate]                                    │
   6-dimension review + acceptance tests              │
        │                                             │
   ┌────┴────┐                                        │
  GO        NO-GO / FAIL                              │
   │          │                                       │
   │    updates configs                               │
   │    writes problems to .scratch/                  │
   │    🔄 CLEAR CONTEXT ──────────────────────────── ┘
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
7. Creates or updates the workflow files integrating what was detected — including `.buildit/config.md` with the confirmed test command
8. Commits everything: `chore(config): bootstrap project configuration from workflow v2`

For `shared-context.md`, active features (`IN_PROGRESS`) are always preserved.

---

### `buildit-project-audit`

**Trigger:** `/buildit-project-audit [scope]`

**When to use:** for periodic health checks, before major refactoring, after shipping a batch of features, or to assess a specific file/directory/concern area on demand. Not for project setup — use `buildit-project-bootstrap` for that.

**What it does:**
1. Detects agent identity (Claude vs other agent) and checks for `.scratch/shared-context.md`
2. Determines audit scope: uses the provided argument (file, directory, keyword) or launches a subagent for hotspot analysis (git churn + complexity heuristics, capped at top 10 files)
3. Writes a placeholder to `.scratch/DD-MM-YYYY-audit-issues.md` to trigger file-write permission early (before subagent work begins)
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
1. Detects mode (Claude vs generic) and checks for an existing plan (resume detection)
2. Collects input: any structured document (PRD, specs, user stories, bullet points) or ad-hoc request
3. Offers two decomposition paths: fast (auto-decompose then validate) or coaching (collaborative question-driven)
4. Decomposes into tasks with name, description, acceptance tests, priority, and readiness (`ready` or `needs-scoping`)
5. Groups tasks into epics if 3 or more tasks; uses flat list otherwise
6. Creates `.scratch/plan/task-{name}.md` per task and `.scratch/plan/plan.md` with epic index and progress counters
7. On resume: reads existing plan, proposes cleanup of `.scratch/done/` files older than 7 days and completed epics, enters coaching mode for modifications, re-syncs progress counters

**Ends with:** explicit handoff listing actionable tasks — suggests `/buildit-feature-discover [task-name]` for `needs-scoping` tasks and `/buildit-feature-run [task-name]` for `ready` tasks.

**Design spec:** `docs/buildit/specs/2026-10-22-buildit-plan-design.md`

---

### `buildit-feature-discover`

**Trigger:** `/buildit-feature-discover [feature-name]`

**When to use:** before `buildit-feature-start`, when the feature idea is vague or needs validation against project conventions. If the brief is already clear (name + description + acceptance tests), skip this skill and invoke `/buildit-feature-start` directly.

**What it does:**
1. Short-circuits if a complete brief is already provided as argument
2. Reads `shared-context.md`, guidelines, and scans existing skills to extract constraints, conventions and potential overlaps
3. Asks whether external documentation is available (specs, user stories, design doc)
4. Poses targeted functional questions (problem, users, expected behaviour, success criteria) — adapted to what Phase 1 revealed
5. Translates functional answers into a technical description anchored in project conventions, and surfaces actionable risks
6. Produces a structured brief: kebab-case name, technical description, acceptance tests, risks & constraints
7. Presents the brief for user validation; iterates on contested sections only

**Ends with:** the user chooses between `/buildit-feature-run [feature-name]` (full cycle unattended, recommended) or `/buildit-feature-start [feature-name]` (manual cycle, session by session).

---

### `buildit-feature-run`

**Trigger:** `/buildit-feature-run [feature-name] [--max-cycles N]`

**When to use:** the default path for most features. Runs the full cycle (start → build → validate → ship) unattended in a single session. Each phase runs in a fresh subagent for context isolation. Fall back to the manual flow only when mid-cycle human judgement is needed.

**What it does:**
1. Collects inputs (worktree, name, description, acceptance tests) before launching any subagent. When a matching plan task exists (`.scratch/plan/task-{name}.md`), pre-fills inputs and tracks task status automatically
2. Delegates `buildit-feature-start` to a fresh subagent; detects the tracking file and worktree path after completion
3. Runs a build/fix loop (max N cycles, default 3): delegates `buildit-feature-build`, reads status, delegates `buildit-feature-validate`, reads status; routes `to-fix` back to build and `to-ship` to the next step
4. On GO + PASS: delegates `buildit-feature-ship`, updates plan task status to done if applicable, then reminds the user that push and PR creation are manual

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

**Design spec:** `docs/buildit/specs/2026-09-08-buildit-feature-run-design.md`

---

### Manual flow skills

The following skills are used individually in the manual flow, or invoked internally by `buildit-feature-run`:

### `buildit-feature-start`

**Trigger:** `/buildit-feature-start [feature-name]`

**When to use:** at the start of each new feature, from the main branch or a dedicated branch, before creating the implementation worktree.

**What it does:**
1. Proposes working in an isolated worktree (recommended for non-trivial features) — if yes, calls the internal `buildit-worktree` skill to create and configure it (no external dependency)
2. Reads `shared-context.md` to detect changed APIs, constraints and decisions/conventions introduced by other branches that affect the plan
3. Collects the feature name, description and acceptance tests (or uses the provided argument)
4. Generates the tracking file `.scratch/DD-MM-YYYY-[feature-name].md` with the plan, including the worktree path in a dedicated `## Worktree path` field
5. Critiques the plan: wrong assumptions, edge cases, vague steps, underestimated risks
6. Updates the plan with the corrections
7. Adds the branch in `shared-context.md` section "Merge readiness" (`IN_PROGRESS`)

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
5. Craft-principles self-review (DRY, KISS, YAGNI — see `.buildit/guidelines/craft-principles.md`) before transitioning to `to-validate`

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

**Test suite** — runs the project's tests before the review using a two-tier detection: first reads the configured command from `.buildit/config.md` (set by bootstrap); if absent, falls back to ecosystem marker heuristic (same 6 ecosystems as bootstrap). If no test runner is detected, warns and proceeds.

**Review phase** — evaluates the diff (`git diff main...HEAD`) on 6 dimensions without reading the plan (unbiased review):

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
3. Counts build/fix cycles — warns if 3rd cycle or more (risk of contextual noise)
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
- File overlap with `IN_PROGRESS` branches
- Branches declaring they are waiting for this branch
- APIs modified by other branches not yet accounted for
- Discovered constraints not addressed in this scope

Verdict: **✓ OK to ship** or **⚠ Blocking: [precise reason]**. If blocking, waits for human confirmation.

**2. Commit** — format `type(scope): description` (the WHY, not the what). Moves the tracking file to `.scratch/done/`.

**3. Shared-context.md cleanup** (in the same commit):
- "Merge readiness" → removes the line for this branch
- "API & Contracts modified" → removes the section for this branch
- "Constraints discovered" → decision tree:
  - Feature-specific → delete
  - Durable → migrate into the appropriate guideline (`language-framework.md`, `team-practices.md`, dedicated guideline, or rules file), then delete
- "Decisions & Conventions" → always durable, always migrate into the appropriate guideline, then delete

**4. Light retro** — three questions: what slowed down the loop? would a configuration have prevented it? was the plan precise enough? If a configuration needs changing, the update is included in the commit.

**Ends with:** push and PR creation are manual.

**Use cases:**
- Closing a validated feature
- Coordination with other parallel features (the readiness check blocks if needed)
- Automatic enrichment point for project guidelines

---

## Continuous improvement loop

Guidelines are automatically enriched with each feature, without a dedicated step:

- **`buildit-feature-validate` NO-GO** → updates configs in the same session (before closing)
- **`buildit-feature-ship`** → migrates durable constraints from `shared-context.md` into the appropriate guidelines

Over time, `language-framework.md`, `team-practices.md` and `craft-principles.md` reflect the real constraints of the project — not anticipations, but accumulated real work.

---

### `buildit-worktree` (internal)

**Trigger:** called internally by `buildit-feature-start` — not invoked directly by users.

**When to use:** automatically invoked when the user opts into worktree isolation during `buildit-feature-start`. Can also be invoked standalone when setting up a worktree outside the standard cycle.

**What it does:**
1. Derives the branch name `feature/YYYY-MM-DD-[feature-name]` from the current date
2. Ensures `.worktrees/` is listed in `.gitignore` (appends and commits if absent)
3. Creates the worktree: `git worktree add .worktrees/feature/YYYY-MM-DD-[feature-name] -b feature/...`
4. Resolves and returns the absolute worktree path (`WORKTREE_PATH`)
5. Instructs the calling agent to use `git -C <WORKTREE_PATH>` for all git commands inside the worktree

**Design rationale:** replaces the external dependency on `superpowers:using-git-worktrees`. Worktree management is now fully internal to the buildit framework, ensuring consistent behaviour regardless of which superpowers skills are installed.

---

## References

- buildit-plan design: `docs/buildit/specs/2026-10-22-buildit-plan-design.md`
- buildit-feature-run design: `docs/buildit/specs/2026-09-08-buildit-feature-run-design.md`
- Generic test runner detection: `docs/buildit/specs/2026-10-14-generic-test-runner-detection.md`
- Audit parallel pipeline: `docs/buildit/specs/2026-10-19-audit-parallel-pipeline.md`
- Audit calibration: `docs/buildit/specs/2026-10-19-audit-calibration.md`
