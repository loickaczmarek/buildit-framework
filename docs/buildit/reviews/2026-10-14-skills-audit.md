# Skills Audit — 2026-10-14

> Historical record: this review predates the fixes from the 24-11-2026 audit on `fix/audit`. Line numbers and findings describe the skills as of 2026-10-14; check the current skills before acting on them.

Full review of the 8 buildit skills, 3 guidelines, and 164 tests. Review produced by Claude, then independently critiqued by a second agent that re-read all files. This document consolidates both passes.

---

## Critical — core functionality gaps

### 1. Validate doesn't execute tests

**Skills:** `buildit-feature-validate`
**Location:** between step 2 (read constraints) and step 3 (review phase)

`buildit-feature-validate` reviews the diff via `git diff main...HEAD` and evaluates acceptance criteria by reading code, but never runs the test suite (`npm test`, `bash tests/run-all.sh`, or equivalent). The build phase runs tests, but between build and validate — especially with a context clear — nothing guarantees they still pass.

**Risk:** A passing review with failing tests produces a false GO.

**Proposed fix:** Add a step before the review phase: "Run the project's test suite and verify all tests pass. If any test fails, stop and set status to `to-fix` with the failure details — do not proceed to the review phase."

---

### 2. File overlap check is decorative

**Skills:** `buildit-feature-ship` (step 1)
**Location:** readiness check references "Main files touched" column in `shared-context.md`

The ship readiness check compares touched files against IN_PROGRESS branches using the "Main files touched" column in the merge readiness table. But this column is initialized with `—` and no skill in the cycle ever populates it. The safety feature references data that doesn't exist.

**Risk:** Parallel features modifying the same files ship without warning. The readiness check gives false confidence.

**Proposed fix:** Either (a) have `buildit-feature-build` populate the column at the end of each build cycle via `git diff main...HEAD --name-only`, or (b) have `buildit-feature-ship` compute it at check time by querying each IN_PROGRESS branch's diff directly. Option (b) is more reliable — it doesn't depend on a prior skill remembering to fill a column.

---

### 3. No concurrent access protection for `shared-context.md`

**Skills:** all skills that write to `shared-context.md` (`feature-start`, `feature-build`, `feature-run`, `feature-ship`)

The framework explicitly supports parallel features via worktrees, and `shared-context.md` is the shared coordination file. But there's no locking or merge strategy. If two features try to write to `shared-context.md` simultaneously (e.g. two parallel `buildit-feature-ship` runs), they can overwrite each other's entries.

**Risk:** Lost coordination data between parallel branches — constraint entries, merge readiness status, or API contract changes silently dropped.

**Proposed fix:** Document the constraint clearly: "Only one skill session should write to `shared-context.md` at a time. When running parallel features, stagger ship phases." Alternatively, switch to per-branch coordination files (`.scratch/shared-context-[branch].md`) merged at ship time — but this changes the architecture.

---

## High — state machine / lifecycle gaps

### 4. No status guard in `buildit-feature-build`

**Skills:** `buildit-feature-build` (step 1)
**Location:** mode detection reads "Problems to fix" section but doesn't validate current status

Build detects its mode (TDD vs fix) by checking for a "Problems to fix" section, then sets status to `building`. It never validates that the current status is actually `to-build` or `to-fix`. If someone invokes `/buildit-feature-build` on a tracking file with status `to-validate` or `to-ship`, the skill overwrites the status to `building` and proceeds, corrupting the state machine.

The `buildit-feature-run` orchestrator has guards for this; standalone manual invocation doesn't.

**Risk:** State machine corruption in the manual flow. A user accidentally running build after a successful validate would lose the GO status.

**Proposed fix:** Add a guard after reading the tracking file: "If status is not `to-build` or `to-fix`, warn: 'Current status is `[status]` — buildit-feature-build expects `to-build` or `to-fix`. Continue anyway?' and wait for confirmation."

---

### 5. No prerequisite check for `shared-context.md`

**Skills:** `buildit-feature-start` (step 1), `buildit-feature-build` (step 2), `buildit-feature-validate` (step 2), `buildit-feature-ship` (step 1)

All four skills read `.scratch/shared-context.md` without checking whether the file exists. If someone runs any of these skills on a project that hasn't been bootstrapped, the skill fails silently or produces a confusing error.

**Risk:** Confusing failure on un-bootstrapped projects. Users don't know why the skill fails or what to do about it.

**Proposed fix:** Add a guard in each skill's early steps: "If `.scratch/shared-context.md` does not exist, warn: 'Shared context file not found — run `/buildit-project-bootstrap` to initialize the project.' Then stop."

---

### 6. No worktree cleanup

**Skills:** `buildit-worktree` (creates), `buildit-feature-ship` (should clean up but doesn't)

`buildit-worktree` creates worktrees under `.worktrees/` but no skill ever removes them. After `buildit-feature-ship` completes and the branch is merged, stale worktrees accumulate on disk indefinitely.

**Risk:** Disk space waste and confusion — stale worktrees remain on disk with outdated code. Over many features, `.worktrees/` grows without bound.

**Proposed fix:** Add a cleanup step in `buildit-feature-ship` after the commit: "If the tracking file has a `## Worktree path` value other than `none`, run `git worktree remove <path>` and confirm removal."

---

## Medium — robustness refinements

### 7. `<guidelines-dir>` placeholder not resolved in `buildit-feature-build`

**Skills:** `buildit-feature-build` (lines 52, 72)

`buildit-feature-build` references `<guidelines-dir>/craft-principles.md` but unlike `buildit-feature-validate` and `buildit-feature-ship`, it has no step 0 that resolves `<guidelines-dir>` to a concrete path. The agent will likely infer the right path, but it breaks the pattern established by the other skills.

**Proposed fix:** Use the concrete path `.buildit/guidelines/craft-principles.md` — build doesn't need `<rules-file>` for anything else, so a full step 0 would be overkill.

---

### 8. Config enrichment subagent may over-learn

**Skills:** `buildit-feature-validate` (step 5a)

The subagent in step 5a receives a list of issues and adds rules to guidelines. There's no filter for specificity — a one-off bug could produce a hyper-specific rule that clutters the guidelines over time.

**Proposed fix:** Add an instruction to the subagent prompt: "Before adding a rule, ask: would this rule prevent similar bugs in other files or features? If the rule only applies to this exact function or this specific instance, skip it — only add rules that prevent a class of issues."

---

### 9. `buildit-feature-start` asks about worktree before collecting feature info

**Skills:** `buildit-feature-start` (step 0 vs step 2)

Step 0 asks "Do you want to work in an isolated worktree?" before step 2 collects the feature name, description, and acceptance tests. The isolation decision logically depends on feature complexity, which isn't known yet. `buildit-feature-run` gets the order right — it collects all inputs first.

**Proposed fix:** Move the worktree question after step 2 (collect feature information), so the user can make an informed isolation decision.

---

### 10. Acceptance phase is subjective for behavioral criteria

**Skills:** `buildit-feature-validate` (step 4)

The acceptance phase evaluates each criterion with PASS/FAIL by reading the diff. This works for structural criteria (verifiable by reading code) but not for behavioral criteria (e.g. "users can reset their password via email"). Behavioral criteria can only prove intent from a diff, not actual execution.

Partially addressed if issue #1 (execute tests) is fixed — test execution would cover behavioral criteria that have corresponding test cases.

**Proposed fix:** Add a note in the acceptance phase: "For behavioral criteria that cannot be verified by reading the diff alone, check whether a corresponding test exists and passes. If no test covers the criterion, flag it as UNVERIFIABLE rather than PASS."

---

### 11. Discover short-circuits too eagerly

**Skills:** `buildit-feature-discover` (step 0)

Step 0 exits the skill entirely if name + description + acceptance tests are all provided. But the value of discover is Phase 1 (context analysis: overlaps with existing skills, constraints from shared-context, conventions from guidelines). Skipping it means missing the cross-checking that justifies the skill's existence.

**Proposed fix:** Instead of exiting entirely, short-circuit to Phase 3 (technical translation) — run Phase 1 as a quick conflict check, then skip the functional exploration (Phase 2) if the brief is already complete.

---

## Low — documented trade-offs / negligible risk

### 12. `git commit --amend` in ship

**Skills:** `buildit-feature-ship` (step 4b)

Step 4b amends the feature commit to include retro-driven config updates. The review flagged this as a destructive git operation.

**Assessment:** The commit is guaranteed local-only — `buildit-feature-ship` explicitly states "Push and PR remain manual." Amending a local unpushed commit is standard practice. Risk is near zero in this context.

**If desired:** Replace with a separate commit `chore(config): update guidelines from retro` to avoid any amend pattern.

---

### 13. Early write / step-skip coupling in `buildit-feature-run`

**Skills:** `buildit-feature-run` (step 2 + step 3)

Step 2 writes the merge readiness entry early (for UX — surfaces Write permission prompt), then step 3 tells the start subagent to skip its own merge readiness write. This splits one responsibility across two skills.

**Assessment:** Already documented as an intentional convention in `team-practices.md` under "Orchestrator-level permission trigger." Acknowledged technical debt with explicit rationale — not an oversight.

---

### 14. Tracking file scan name collisions

**Skills:** `buildit-feature-build`, `buildit-feature-validate`, `buildit-feature-ship`

Tracking files are found via `*feature-name*.md` glob. If two features share a substring, the glob could match both.

**Assessment:** The `DD-MM-YYYY-` date prefix significantly narrows the glob. When using worktrees (the recommended flow), each worktree has its own `.scratch/`. Practical collision risk is near zero.

---

### 15. Discover is skill-centric

**Skills:** `buildit-feature-discover` (Phase 2)

The functional questions say "what problem does this *skill* solve?" — but discover is about features, not necessarily skills.

**Assessment:** The framework's `language-framework.md` explicitly declares "Framework: Claude Code Skills." Every feature in this project *is* a skill. The wording is domain-accurate. Would need adjustment only if the framework were adapted for a non-skill project.

---

## Opportunities — not defects

### A. Resume mechanism for `buildit-feature-run`

If the orchestrator fails mid-cycle (subagent crash, user interrupt), the tracking file is in an intermediate state (`building`, `validating`) with no defined recovery path. A resume command that reads the current state and picks up from the correct phase would prevent orphaned features.

### B. Metrics from `.scratch/done/`

10 completed features exist in `.scratch/done/` — a natural dataset. Tracking cycle count, NO-GO reasons, and elapsed time per feature would give quantitative insight into where the framework helps most and where it creates friction.

### C. Test coverage for `shared-context.md` contract

The 164 tests verify that skills mention `shared-context.md`, but no test verifies the 4-section structure is maintained — that skills don't write to a section that doesn't exist, or that the merge readiness table format is consistent across skills.

---

## Summary

| Priority | Count | Key themes |
|----------|-------|-----------|
| Critical | 3 | Test execution gap, broken safety check, concurrent access |
| High | 3 | State machine guard, prerequisite check, resource cleanup |
| Medium | 5 | Consistency, over-learning, question ordering, behavioral validation |
| Low | 4 | Documented trade-offs, negligible practical risk |
| Opportunities | 3 | Resume, metrics, contract testing |
