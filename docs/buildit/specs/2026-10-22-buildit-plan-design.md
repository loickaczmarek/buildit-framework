# Design Spec: buildit-plan

**Date:** 2026-10-22
**Feature:** buildit-plan
**Status:** Draft

## Problem

The buildit cycle operates feature-by-feature, but there is no structured way to decompose a larger request (PRD, spec document, roadmap) into ordered tasks before entering the feature loop. Users must manually identify and sequence features, which is error-prone and loses traceability back to the original request.

## Design decisions

### Input flexibility

The skill accepts any structured document as input: PRDs, user stories, specs, bullet-point lists, or even an ad-hoc conversational request. There is no schema requirement. The skill detects input type from conversation context (length, structure, formality) rather than a flag. This preserves the low-friction invocation pattern used by all other buildit skills.

### Epic vs flat threshold

When the decomposition produces fewer than 3 tasks, the plan uses a flat task list (no epic grouping). At 3 or more tasks, tasks are grouped into epics with descriptions and per-epic progress counters. The threshold is intentionally low because epics add cognitive overhead for small plans, but provide necessary structure once task count grows.

### Fast path vs coaching path

Two decomposition modes:

- **Fast path:** the agent auto-decomposes the input into tasks/epics, then presents the full decomposition for user validation. Iterate only on contested parts. Optimised for users who want speed and have a clear input document.
- **Coaching path:** iterative question-driven decomposition. The agent asks targeted questions to collaboratively identify tasks, boundaries, and priorities. Optimised for vague or exploratory inputs.

The user chooses at step 2. Both paths converge at step 4 (task file creation).

### Resume detection

At step 0, the skill checks for `.scratch/plan/` existence. If found AND at least one `task-*.md` file exists inside it, the skill enters resume flow (step 7). If `plan.md` exists but no task files are present, this indicates an incomplete or corrupt plan state — the skill warns and offers to restart or repair.

This singleton design (one active plan at a time) is deliberate: it avoids namespace conflicts and keeps the mental model simple. Users who need parallel plans should use separate worktrees.

### Progress synchronisation

`plan.md` progress counters (`X/Y done`) are computed from individual task file statuses, not maintained independently. On every resume, the skill re-reads all task files and recomputes counters. This eliminates sync bugs where `plan.md` and task files diverge.

### `.scratch/done/` cleanup

On resume, the skill checks `.scratch/done/` for files older than 7 days (using file modification time). Cleanup is confirmation-gated: the skill lists candidate files and waits for explicit user approval before deletion. This prevents accidental loss of tracking history while keeping the scratch directory manageable.

### Completed epic cleanup

On resume, if all tasks within an epic have status `done`, the skill proposes removing the epic and its task files from `.scratch/plan/`. This is also confirmation-gated. The rationale: completed epics add noise to the plan view and slow down resume analysis.

### Task name uniqueness

Task names are kebab-case slugs used as filenames (`task-{name}.md`). Since all tasks live in a flat directory, names must be globally unique across all epics. The skill enforces uniqueness during decomposition — if a collision is detected, it appends a disambiguating suffix or asks the user to rename.

### Readiness criteria

Each task is marked with a readiness status:

- **`ready`**: scope is bounded, acceptance tests are clear and verifiable, technical approach is understood.
- **`needs-scoping`**: description is vague, scope is unbounded, acceptance tests are missing, or technical approach is uncertain.

Tasks marked `needs-scoping` trigger a suggestion to run `/buildit-feature-discover [task-name]` before `/buildit-feature-run`. This integrates naturally with the existing buildit cycle.

### Integration with the buildit cycle

Each task in the plan maps directly to a buildit cycle invocation:
- `needs-scoping` tasks -> `/buildit-feature-discover [task-name]`
- `ready` tasks -> `/buildit-feature-run [task-name]`

The handoff step (step 6) makes these suggestions explicit, creating a clear bridge from planning to execution.

## Integration with buildit-feature-run

When `buildit-feature-run` receives a `feature-name` argument, it checks for a matching `.scratch/plan/task-{feature-name}.md` file at step 0 (initialise). This is the detection mechanism: exact filename match, no glob expansion.

### Status lifecycle

The plan task status tracks the feature through the buildit cycle:

- **Step 0 (initialise):** `todo` -> `in-progress`. The task file's `## Status` is updated. If `plan.md` exists, progress counters are re-synced from all task files. The checkbox remains `- [ ]` (in-progress is not done).
- **Step 6 (after ship):** `in-progress` -> `done`. The task file's `## Status` is updated. If `plan.md` exists, the checkbox changes from `- [ ]` to `- [x]` and progress counters are re-synced.

If the task is already `in-progress` or `done`, the orchestrator warns but proceeds.

### Plan.md sync behaviour

The `plan.md` sync uses the same mechanism as the plan skill's resume flow: re-read all task file statuses, recompute `X/Y done` for each epic or flat list. This avoids independent counter maintenance that could drift.

Checkbox semantics are binary: `- [ ]` for not-done (todo or in-progress), `- [x]` for done. There is no intermediate checkbox state for in-progress.

### Pre-fill inputs

At step 1 (collect inputs), when a plan task is detected, the description and acceptance tests from the task file are pre-filled and presented for user confirmation. The worktree question is always asked regardless of plan data.

### Backward compatibility

If no matching task file exists, `PLAN_TASK_FILE` is set to `none` and the orchestrator falls through to existing behavior unchanged. No error, no warning.

If the task file exists but `plan.md` does not (e.g., it was deleted or the task was created manually), only the task file is updated -- no error is raised for missing `plan.md`.

## File structure

```
.scratch/plan/
  plan.md          # epic index + progress counters (or flat task list)
  task-{name}.md   # one per task
```

## References

- Tracking file: `.scratch/22-10-2026-buildit-plan.md`
- Skill file: `skills/buildit-plan/SKILL.md`
