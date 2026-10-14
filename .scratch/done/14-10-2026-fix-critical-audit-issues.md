# fix-critical-audit-issues

## Status
to-ship

## Worktree path
/home/loic-kaczmarek/mission/build-it-framework/.worktrees/feature/2026-10-14-fix-critical-audit-issues

## Goal
Fix the 3 critical issues identified in the 2026-10-14 skills audit: (1) add test suite execution to buildit-feature-validate before the review phase, (2) make buildit-feature-ship compute file overlap at check time instead of relying on an empty column, (3) add a concurrent access warning/guard for shared-context.md writes.

## Acceptance Tests
1. buildit-feature-validate runs the project's test suite before the review phase; if any test fails, status is set to to-fix and review does not proceed
2. buildit-feature-ship computes file overlap at check time by diffing each IN_PROGRESS branch against main, without relying on the "Main files touched" column
3. Skills that write to shared-context.md include a guard or documented constraint about sequential access
4. Existing tests (bash tests/run-all.sh) still pass after the changes

## Plan

### Issue 1: Add test suite execution to buildit-feature-validate

**What:** Insert a new step 2b between existing step 2 (read constraints) and step 3 (review phase).

**Where:** `skills/buildit-feature-validate/SKILL.md`, between lines 41 and 43.

**New step content (step 2b — "Run test suite"):**
- Run the project's test suite. Detection order: `bash tests/run-all.sh` if `tests/run-all.sh` exists, then `npm test` if `package.json` exists, then warn "No test runner detected" and proceed to review.
- If any test fails: set status to `to-fix`, write a "Problems to fix" section with the test failure details, and stop — do not proceed to the review phase.
- If all tests pass: proceed to step 3 (review phase).

**Renumber:** Current steps 3 (review) and 4 (acceptance) stay as-is but step numbers shift to 3 and 4 since the new step fits as 2b. Actually, to avoid renumbering the entire file, insert it as "### 2b. Run test suite" to preserve the existing step numbers.

**Tests to add:** In `tests/test-buildit-feature-validate.sh`:
- AT-6: Validate mentions running the test suite before the review phase (grep for "test suite" or "run.*test")
- AT-7: Validate mentions setting status to to-fix on test failure (grep for "to-fix" in context of test failure)
- AT-8: Validate mentions not proceeding to review if tests fail

**Mirror:** After editing `skills/buildit-feature-validate/SKILL.md`, copy to `.claude/skills/buildit-feature-validate/SKILL.md`.

### Issue 2: Compute file overlap at check time in buildit-feature-ship

**What:** Replace the "Main files touched" column dependency with dynamic computation.

**Where:** `skills/buildit-feature-ship/SKILL.md`, step 1 (readiness check), around lines 43-48.

**Changes:**
1. In the "File overlap" sub-section, replace the reference to the "Main files touched" column with instructions to:
   - Get this feature's touched files: `git diff main...HEAD --name-only`
   - For each IN_PROGRESS branch in the merge readiness table, compute its touched files: `git diff main...<branch> --name-only`
   - If any files overlap, report them as a warning
2. Remove mentions of the "Main files touched" column from the readiness check.
3. The merge readiness table format in shared-context.md still has 4 columns — but the "Main files touched" column is no longer the source of truth for overlap. The column can remain for human reference but the ship skill computes overlap dynamically.

**Tests to add:** In `tests/test-buildit-feature-ship.sh`:
- AT-4: Ship computes file overlap via git diff (grep for "git diff" in context of overlap)
- AT-5: Ship does not rely solely on the "Main files touched" column (verify the dynamic computation instruction is present)

**Mirror:** After editing `skills/buildit-feature-ship/SKILL.md`, copy to `.claude/skills/buildit-feature-ship/SKILL.md`.

### Issue 3: Concurrent access guard for shared-context.md

**What:** Add a documented constraint about sequential access to shared-context.md in all skills that write to it.

**Where:** Four skill files write to shared-context.md:
- `skills/buildit-feature-start/SKILL.md` (step 5 — merge readiness entry)
- `skills/buildit-feature-build/SKILL.md` (step 4 — decisions & conventions)
- `skills/buildit-feature-run/SKILL.md` (step 2 — early merge readiness write)
- `skills/buildit-feature-ship/SKILL.md` (step 3 — cleanup)

**Approach:** Add a boxed warning/constraint before the shared-context.md write in each skill:

> **Sequential access:** `shared-context.md` has no locking mechanism. When running parallel features, ensure only one skill session writes to this file at a time. Stagger phases that modify `shared-context.md` (start, build capture, ship cleanup) to avoid overwrites.

Also add this as a team practice in `.buildit/guidelines/team-practices.md` under a new sub-section "Shared-context coordination".

**Tests to add:** In `tests/test-skills-invariants.sh`:
- New invariant: every skill that contains "shared-context.md" AND a write operation mentions sequential access or concurrent access warning.

Alternatively, add tests in each skill's own test file. Since the 4 skills each have their own test file, add one assertion per file. But the cross-skill invariant test is more appropriate. Add to `tests/test-skills-invariants.sh`.

**Mirror:** After editing each skill source, copy to `.claude/skills/`.

### Execution order

1. Write failing tests first (TDD red phase)
2. Edit `buildit-feature-validate/SKILL.md` — add step 2b
3. Edit `buildit-feature-ship/SKILL.md` — rewrite file overlap section
4. Edit all 4 skill files — add concurrent access guard
5. Add team practice to `.buildit/guidelines/team-practices.md`
6. Mirror all edited skills to `.claude/skills/`
7. Run `bash tests/run-all.sh` — verify all tests pass (TDD green phase)
8. Craft-principles self-review (DRY, KISS, YAGNI)

### Self-critic corrections

**Assumption risk — test runner detection in validate:** The plan assumes `tests/run-all.sh` as the primary test runner. This is correct for this project, but the step should be written generically so it works for any project. The detection order (run-all.sh > npm test > warn) handles this.

**Edge case — git diff for IN_PROGRESS branches in ship:** If an IN_PROGRESS branch listed in merge readiness doesn't exist locally (only on remote), `git diff main...<branch>` will fail. The skill should instruct the agent to attempt a fetch or skip branches that can't be diffed, with a warning. Added: "If a branch cannot be resolved locally, warn and skip it rather than failing."

**Edge case — concurrent access guard wording:** The guard is a documented constraint, not a technical lock. It relies on human/orchestrator discipline. This is acknowledged as a trade-off in the audit (option b — per-branch files — would change the architecture). The documented constraint is the right-sized fix.

**Risk — step 2b in validate could mask review issues:** If tests fail, the review phase is skipped entirely. This is intentional — there's no point reviewing code that doesn't pass tests. The fix cycle will run, then validate re-runs from scratch including both test execution and review.

**Vagueness — "boxed warning" format:** Clarified: use a Markdown blockquote starting with bold "Sequential access:" to make it visually distinct. Consistent format across all 4 skills.

## Progress
