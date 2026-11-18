# plan-run-integration

## Status
to-ship

## Worktree path
none

## Goal
Modifies buildit-feature-run to detect and update plan task status (todo -> in-progress -> done) when a matching .scratch/plan/task-{name}.md exists, and to pre-fill inputs from the plan task file. Backward-compatible: no plan = existing behavior unchanged.

## Acceptance Tests
- AT-1: At step 0, if .scratch/plan/task-{feature-name}.md exists, reads description, acceptance tests, and readiness from the task file
- AT-2: At step 0, updates plan task status from todo to in-progress
- AT-3: At step 0, updates corresponding checkbox and progress counter in .scratch/plan/plan.md
- AT-4: At step 1, pre-fills description and acceptance tests from plan task file — user confirms or overrides
- AT-5: At step 1, still asks for worktree even when plan task provides other inputs
- AT-6: At step 6 (after ship), updates plan task status from in-progress to done
- AT-7: At step 6, updates corresponding checkbox (- [ ] -> - [x]) and progress counter in plan.md
- AT-8: If feature-name doesn't match any plan task file, falls through to existing behavior unchanged
- AT-9: If plan task status is already in-progress or done, warns but proceeds
- AT-10: If plan.md doesn't exist but task file does, updates task file only — no error
- AT-11: All existing buildit-feature-run tests continue to pass (backward compatibility)
- AT-12: New tests added to tests/test-buildit-feature-run.sh for plan integration
- AT-13: Dual-deployment maintained (skills/ + .claude/skills/)
- AT-14: Design spec updated at docs/buildit/specs/2026-10-22-buildit-plan-design.md (integration section)
- AT-15: README updated if skill description needs clarification

## Plan

### 1. Modify step 0 (Initialise) in SKILL.md

After the existing "Detect operating mode" paragraph, add a new sub-section "**Detect plan task**":

- Check if `.scratch/plan/task-{feature-name}.md` exists (only when `feature-name` is provided as argument).
- If found:
  - Read the task file. Extract `## Description`, `## Acceptance tests`, `## Readiness`, and `## Status`.
  - Store as `PLAN_TASK_FILE`, `PLAN_DESCRIPTION`, `PLAN_ACCEPTANCE_TESTS`, `PLAN_READINESS`.
  - **Status guard:** if current status is `in-progress` or `done`, warn: "Plan task '{feature-name}' is already marked '{status}' — proceeding anyway." but continue.
  - Update `## Status` in the task file from `todo` to `in-progress`.
  - If `.scratch/plan/plan.md` exists:
    - Find the line matching `- [ ] task-{feature-name}` and update `## Status` field is already handled in the task file; for plan.md, update the checkbox: keep the line as-is but the status marker is not in plan.md directly — actually the checkbox represents todo vs done. For in-progress, the checkbox stays unchecked (`- [ ]`), but we update the status in the task file. The plan.md checkbox changes only at done.
    - Re-compute the progress counter for the epic (or flat list) containing this task.
  - If `.scratch/plan/plan.md` does not exist, no error — task file update is sufficient.
- If not found: set `PLAN_TASK_FILE=none`. No further plan-related actions.

**Wait — re-examining AT-3:** "At step 0, updates corresponding checkbox and progress counter in plan.md." But at step 0 we are moving from todo to in-progress, not to done. The checkbox convention is `- [ ]` for not-done and `- [x]` for done. In-progress doesn't change the checkbox. So AT-3 at step 0 means updating the progress counter only — but progress is "X/N done" which counts only `done` tasks, so moving to in-progress doesn't change the counter either.

**Re-reading acceptance tests carefully:**
- AT-3 says "updates corresponding checkbox and progress counter in plan.md" — at step 0. This means at the transition to in-progress, we should update plan.md. Since the checkbox only represents done/not-done, perhaps the intent is to recalculate the counter from task files (which now reflect the new status). The counter won't change numerically (todo -> in-progress doesn't change done count), but the re-sync itself is the update.

Actually, looking at the plan skill's progress format — `Progress: 0/N done` — this counts `done` tasks only. Moving todo->in-progress does NOT change this number. But the acceptance test says "updates corresponding checkbox and progress counter." Perhaps the intent is to make plan.md reflect the current state by re-syncing, even if the numeric value doesn't change. OR perhaps the checkbox notation should show in-progress differently.

**Decision:** Interpret AT-3 as: re-sync plan.md progress counters from task file statuses. The checkbox stays `- [ ]` for in-progress. The counter re-reads all task files so it is always accurate. This is consistent with the plan skill's own behavior (step 7 re-syncs counters on resume).

### 2. Modify step 1 (Collect inputs) in SKILL.md

When `PLAN_TASK_FILE` is set (not `none`):
- Pre-fill `description` with `PLAN_DESCRIPTION` and `acceptance-tests` with `PLAN_ACCEPTANCE_TESTS`.
- Present them to the user: "The plan task provides the following description and acceptance tests. Confirm or override:"
  - Show the pre-filled values.
  - User can confirm (use as-is) or provide overrides.
- **Worktree question is always asked** regardless of plan data (AT-5).
- **Name** is already provided via argument (AT-1 requires feature-name to be provided for task file lookup).

When `PLAN_TASK_FILE` is `none`: existing behavior unchanged — ask all questions as before.

### 3. Modify step 6 (On GO: ship + manual reminder) in SKILL.md

After the ship subagent completes and before the final user message, add:

- If `PLAN_TASK_FILE` is set (not `none`):
  - Update `## Status` in the task file from `in-progress` to `done`.
  - If `.scratch/plan/plan.md` exists:
    - Find the line matching `- [ ] task-{feature-name}` and change to `- [x] task-{feature-name}`.
    - Re-compute the progress counter for the containing epic/flat list.
  - If `.scratch/plan/plan.md` does not exist: update task file only, no error (AT-10).

### 4. Add tests to tests/test-buildit-feature-run.sh

Add structural tests for plan integration:
- AT-P1: SKILL.md contains plan task detection logic (regex for `task-.*\.md` or `plan/task`)
- AT-P2: SKILL.md references status update from `todo` to `in-progress`
- AT-P3: SKILL.md references progress counter re-sync in plan.md
- AT-P4: SKILL.md contains pre-fill logic for description/acceptance tests from plan task
- AT-P5: SKILL.md preserves worktree question regardless of plan data
- AT-P6: SKILL.md references status update from `in-progress` to `done` after ship
- AT-P7: SKILL.md references checkbox update (`- [x]`) in plan.md after ship
- AT-P8: SKILL.md references fallthrough when no plan task file matches
- AT-P9: SKILL.md references warning for already in-progress/done status
- AT-P10: SKILL.md handles missing plan.md gracefully (task file only)
- Verify all existing tests still pass (run full suite).

### 5. Mirror to .claude/skills/

Copy the updated `skills/buildit-feature-run/SKILL.md` to `.claude/skills/buildit-feature-run/SKILL.md`.

### 6. Update design spec

Add an "Integration with buildit-feature-run" section to `docs/buildit/specs/2026-10-22-buildit-plan-design.md` documenting:
- The detection mechanism (task file existence check)
- The status lifecycle (todo -> in-progress at step 0, in-progress -> done at step 6)
- The plan.md sync behavior (checkbox + counter)
- The fallthrough/backward-compatibility guarantee

### 7. Update README

Update the `buildit-feature-run` section in README.md:
- Add a bullet or note about plan integration: "When a matching plan task exists, pre-fills inputs and tracks task status automatically."
- Update the "What it does" list if the step structure has changed.

### 8. Run tests

Run `bash tests/run-all.sh` to verify all tests pass, including existing and new ones.

## Self-Critique

### Assumptions that could be wrong
- **Checkbox semantics for in-progress:** The acceptance tests say "updates corresponding checkbox and progress counter in plan.md" at step 0 (todo -> in-progress). But the plan skill uses `- [ ]` / `- [x]` which is binary (not-done / done). There is no `- [~]` for in-progress. Decision: at step 0, the checkbox stays `- [ ]` and only the progress counter is re-synced. The checkbox changes to `- [x]` only at step 6 (done). This is consistent with the plan skill's own semantics.

### Edge cases
- **Feature name provided but no task file:** Cleanly falls through. Must not produce an error or warning.
- **Task file exists but plan.md was deleted:** Task file updated, plan.md update skipped silently (AT-10).
- **Task already done:** Warning but proceed — the user may be re-running intentionally. The task status should still be updated (done -> done is a no-op, but in-progress -> done at step 6 is fine).
- **Multiple task files with similar names:** The match is exact: `task-{feature-name}.md`. No glob expansion.
- **YAML frontmatter description field update:** The YAML frontmatter `description` field in SKILL.md mentions step count/behavior. Need to check if it needs updating.

### Risks
- **Ordering of plan detection vs argument parsing:** Plan detection requires `feature-name` to be available. Since argument parsing happens at the start of step 0, plan detection can safely follow.
- **Skill file size:** Adding plan integration to three steps (0, 1, 6) increases SKILL.md length. Must keep additions concise to avoid bloat.
- **Test brittleness:** Structural grep tests may be fragile if wording changes. Use broad-enough patterns.

## Progress
