# early-permission-trigger

## Status
to-ship

## Worktree path
none

## Goal
Move the first write operation to the beginning of buildit-feature-run (before launching the start subagent), so that the Write permission prompt appears immediately rather than midway through the start phase. Users who have pre-configured write permissions will not have to wait and intervene.

## Acceptance Tests
1. When /buildit-feature-run is invoked, the first file-write operation happens before any subagent is launched
2. The write occurs early enough that a user with pre-allowed Write permissions sees no permission prompt during the start phase
3. The early write does not create side effects (no orphan files if the user cancels before start)
4. The existing tracking file creation in buildit-feature-start still works correctly (no duplication or conflict)

## Plan

### Analysis

The problem: In buildit-feature-run, the first file write happens inside the start subagent (step 2), when buildit-feature-start creates the tracking file (step 3 of that skill) and updates shared-context.md (step 5 of that skill). If the user has not pre-allowed Write permissions, the permission prompt appears midway through the start phase, which is jarring and forces the user to watch and wait.

The solution: Add a new step between current steps 1 (Collect inputs) and 2 (Subagent: start) in buildit-feature-run that performs a real, meaningful Write to an existing file. The best candidate is `.scratch/shared-context.md` -- it already exists, the write is a real workflow operation (adding the merge readiness entry), and writing to an existing file does not create orphan files if the user cancels.

### Implementation steps

1. **Modify `skills/buildit-feature-run/SKILL.md`:**
   - Insert a new step "1.5" (renumbered appropriately) between "Collect inputs" and "Subagent: buildit-feature-start" titled "Trigger early write permission".
   - This step reads `.scratch/shared-context.md`, then writes back to it with the merge readiness entry for the current branch appended (`| [branch-name] | IN_PROGRESS | -- | -- |`).
   - Include an inline comment explaining WHY this early write exists (permission prompt UX).
   - The step also retrieves the current branch via `git branch --show-current`.

2. **Update the start subagent prompt (step 2 -> step 3) in buildit-feature-run:**
   - Add an instruction: "Skip step 5 (shared-context update) -- already done by the orchestrator."
   - This prevents the start subagent from writing a duplicate merge readiness entry.

3. **Mirror changes to `.claude/skills/buildit-feature-run/SKILL.md`** (dual-deployment parity).

4. **Add structural tests in `tests/test-buildit-feature-run.sh`:**
   - AT for "early write" or "permission trigger" appearing before the subagent step.
   - AT for shared-context.md being written before the start subagent.
   - AT for the skip-step-5 instruction in the start subagent prompt.

5. **No changes to `skills/buildit-feature-start/SKILL.md`:** The standalone flow remains unchanged. The skip-step-5 instruction is only passed via the prompt when called from buildit-feature-run.

### Self-critic corrections

**Assumption check:** The plan assumes that writing to an existing file (shared-context.md) triggers the Write permission prompt. This is correct -- the Claude Code harness prompts for the Write tool regardless of whether the file is new or existing.

**Edge case -- duplicate merge readiness entry:** If the user runs buildit-feature-start standalone (not via run), step 5 of start still writes the entry normally. If they later use buildit-feature-run for a different feature, the orchestrator writes a new entry for the new branch. No conflict because each entry is for a different branch. However, if someone runs buildit-feature-run and then manually runs buildit-feature-start for the same feature on the same branch, there could be a duplicate. This is an unlikely edge case (the whole point of run is to avoid manual phase invocation), and the impact is a harmless duplicate row in a coordination file. Acceptable.

**Edge case -- cancellation after early write:** If the user cancels after the early write but before the start subagent runs, shared-context.md contains an IN_PROGRESS entry for a feature that was never started. This is a single table row in a coordination file, trivially cleaned. It is not an orphan file. Acceptance test 3 specifically says "no orphan files", which this satisfies.

**Risk -- step renumbering:** Adding a step between 1 and 2 requires renumbering steps 2-5 to 3-6. All internal references (including test assertions that check step numbers) must be updated. The existing tests reference step content via text patterns, not step numbers, so they should not break.

**YAGNI check:** The change is minimal -- one new step in the orchestrator, one extra instruction in the subagent prompt. No new abstractions, no new files, no new mechanisms.

## Progress
