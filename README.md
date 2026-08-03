# Skills — Multi-Agent Workflow v2

A set of 5 skills that drive the development loop feature by feature. Each skill ends by instructing the next one; mandatory clear-context steps are handled by explicit instructions to the developer.

---

## Overview

```
[buildit-project-bootstrap]          ← once per project, outside the feature flow
        │
        ▼
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
   5-dimension review + acceptance tests              │
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

**Parallelisation:** multiple features can run simultaneously on separate worktrees. Coordination goes through `.scratch/shared-context.md`.

---

## Tracking file structure

Each feature creates `.scratch/DD-MM-YYYY-[feature-name].md`:

```markdown
# [feature-name]

## Status
to-build | building | to-validate | validating | to-fix | to-ship

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

## Skills

### `buildit-project-bootstrap`

**Trigger:** `/buildit-project-bootstrap`

**When to use:** when starting a new project, or on an existing project to resynchronise configs and actual practices.

**What it does:**
1. Detects agent identity (Claude vs other agent) and asks for mode confirmation
2. Scans `.buildit/guidelines/` to detect all files present — custom files (`figma.md`, `jira.md`…) are preserved without modification
3. Asks whether a directory or document of existing practices exists, and if so proposes to **merge** it into the guidelines or **reference** it (link at the top of the guideline)
4. Performs a light coring of the source code: directory tree, config files, naming conventions, 2 representative files — to detect actual practices in place
5. Presents a complete diagnostic (drift, gaps, planned actions) and waits for confirmation before writing
6. Creates or updates the workflow files integrating what was detected
7. Commits everything: `chore(config): bootstrap project configuration from workflow v2`

**Use cases:**
- New project: detects the stack from the code, generates the pre-filled kit with actual conventions
- Existing project: cross-references configs and code to find drift, proposes resynchronisation
- Integration of external practices: merge or reference of an existing doc (Confluence, `docs/`, ADR…)

For `shared-context.md`, active features (`IN_PROGRESS`) are always preserved.

---

### `buildit-feature-start`

**Trigger:** `/buildit-feature-start [feature-name]`

**When to use:** at the start of each new feature, from the main branch or a dedicated branch, before creating the implementation worktree.

**What it does:**
1. Proposes working in an isolated worktree (recommended for non-trivial features)
2. Reads `shared-context.md` to detect changed APIs, constraints and decisions/conventions introduced by other branches that affect the plan
3. Collects the feature name, description and acceptance tests (or uses the provided argument)
4. Generates the tracking file `.scratch/DD-MM-YYYY-[feature-name].md` with the plan
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

**Review phase** — evaluates the diff (`git diff main...HEAD`) on 5 dimensions without reading the plan (unbiased review):

| Dimension | Question |
|-----------|----------|
| Correctness | Does the code do what is asked? |
| Performance | Unnecessary costly operations? |
| Security | Injection vectors, data exposure? |
| Style | Project conventions respected? |
| Test coverage | Edge cases tested? |

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

Over time, `language-framework.md` and `team-practices.md` reflect the real constraints of the project — not anticipations, but accumulated real work.

---

## References

- Bootstrap mode confirmation design: `docs/superpowers/specs/2026-08-03-bootstrap-mode-confirmation-design.md`
