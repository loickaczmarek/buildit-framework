# task-staging-contract

## Status
to-ship

## Worktree path
none

## Goal
Audit 24-11-2026 findings #2, #18, #21 (full audit: `.scratch/24-11-2026-audit-issues.md`).

Build never stages files, while validate's staging guard returns NO-GO on any untracked/unstaged file; the staging rule only lives in this repo's `.claude/CLAUDE.md`, not in the bootstrap rules template — bootstrapped projects lose a cycle per feature. Validate also runs the full suite before the cheap staging guard, its test-failure path skips the NO-GO bookkeeping (5a/5c), cycle counting includes non-NO-GO Progress entries, run refers to start's "step 5" by number, and validate's deliberate revert to `to-validate` is misreported by run as a subagent failure.

Files: `skills/buildit-feature-build/SKILL.md`, `skills/buildit-feature-validate/SKILL.md`, `skills/buildit-feature-run/SKILL.md`, `skills/buildit-project-bootstrap/SKILL.md` (rules-file template), plus tests.

## Acceptance Tests
- AT-1: build step 5 stages every created/modified feature file (`git [-C <worktree-path>] add`) and checks `git status --porcelain` before setting `to-validate`.
- AT-2: the bootstrap rules-file template contains the staging rule.
- AT-3: validate runs the staging guard before the test suite.
- AT-4: a test failure in validate goes through the same NO-GO path (Problems to fix, config update, Progress entry); the cycle count counts only NO-GO cycle entries.
- AT-5: run references start's shared-context step by name, not number; validate records a `## Last error` line that run reports instead of "possible subagent failure".
- AT-6: tests assert AT-1 to AT-5; `bash tests/run-all.sh` passes.

## Plan

Context / constraints:
- Work directly on branch `fix/audit` (no worktree). `.claude/skills` is a git-tracked symlink to `../skills` — edit `skills/` only, nothing to copy.
- Skill text stays in English. Any new text reading a `.buildit/config.md` value must use the exact Config value rule wording (`.buildit/guidelines/language-framework.md`, enforced by `tests/test-config-parsing-boundary.sh`). This feature should not add new config reads; existing ones are moved verbatim.
- Do not stage/commit `.scratch/24-11-2026-audit-issues.md` or `.scratch/plan/`.
- Existing test `tests/test-buildit-feature-run.sh` AT-15 regex matches `[Ss]kip.*shared-context` — still satisfied by name-based wording. `tests/test-buildit-feature-validate.sh` AT-STAGE-3 compares the first `git status --porcelain` line to the review diff line — still satisfied when the guard moves earlier.

### Step 1 — Failing tests first
Add assertions (new IDs, section `# --- Staging contract (AT-SC-*) ---`) to the existing per-skill test files:

`tests/test-buildit-feature-build.sh` (AT-1):
- step 5 section (extract between `### 5. Update the tracking file` and `## End of skill`) contains `git [-C <worktree-path>] add` (exact text) and `git status --porcelain`.
- within that section, the `add` line and the `git status --porcelain` line both appear before the line that sets the status to `to-validate`.
- the section states `.scratch/` is excluded from the check (consistent with validate's guard).

`tests/test-buildit-project-bootstrap.sh` (AT-2):
- the rules-file template block (between `` `<rules-file>`: `` and the next `` `<guidelines-dir>/team-practices.md`: ``) contains a staging rule: regex on `git status` + `staged` + `to-validate`.

`tests/test-buildit-feature-validate.sh` (AT-3, AT-4, AT-5 validate part):
- AT-3: line of the staging-guard heading/`git status --porcelain` < line of `### ` test-suite heading (`Run test suite`).
- AT-4: test-failure text routes to "If NO-GO or FAIL" (regex `[Tt]est failure.*If NO-GO or FAIL|If NO-GO or FAIL.*test failure`, scoped to the test-suite step); the old "write a "Problems to fix" section ... and stop" shortcut is absent; 5a issue list mentions test failures; 5c counts only `### NO-GO cycle` headings (text `` `### NO-GO cycle` `` in 5c section) and the old "Count the number of existing entries in the "Progress" section" is absent; Progress entry template has a `Tests:` line.
- AT-5: base-branch failure path writes `## Last error` to the tracking file; step 1 removes a stale `## Last error` section when setting `validating`.

`tests/test-buildit-feature-run.sh` (AT-5 run part):
- start subagent prompt references the step by name: text `"Update shared-context.md" step`; `require_absent` on `Skip step 5` and `step 5 of buildit-feature-start`.
- validate status-unchanged branch reads `## Last error` and reports it; "possible subagent failure" for validate only when `## Last error` is absent.
- Update AT-15 regex if needed so it no longer accepts the numeric form only (keep it compatible).

Run `bash tests/run-all.sh` → new assertions fail, old ones pass.

### Step 2 — build `skills/buildit-feature-build/SKILL.md` step 5
Rewrite step 5 as ordered sub-steps:
1. Stage the feature work: `git [-C <worktree-path>] add <paths>` for every file created or modified during this build — list paths explicitly, never `git add -A`/`git add .` (would sweep unrelated files). Files under `.scratch/` are not staged here (workflow state, committed by ship; validate's guard ignores them).
2. Check: `git [-C <worktree-path>] status --porcelain`; ignoring `.scratch/`, no line may be untracked (`??`) or have unstaged changes (second column non-blank). If a remaining entry belongs to the feature, stage it. If it is unrelated to the feature, do not stage it: stop, leave the status at `building`, and warn the user that validate's staging guard would return NO-GO on it (they must stage, ignore, or remove it).
3. Only then set the status to `to-validate`; clear "Problems to fix".
Keep text short; reference validate's guard as the matching rule (same flag criteria).

### Step 3 — bootstrap rules-file template
In `skills/buildit-project-bootstrap/SKILL.md` `<rules-file>` template, `## Agent workflow`, add the rule mirroring this repo's `.claude/CLAUDE.md:13`:
`- Before setting status to to-validate, stage every file created or modified during the build (outside .scratch/) and confirm with git status --porcelain that no relevant untracked or unstaged file remains — validate's staging guard returns NO-GO otherwise.`
(Template uses no backticks inside; follow its style.) Also check whether `.buildit/guidelines/team-practices.md` lists tracking/workflow rules that need the same line — only if a template there duplicates the rules list (avoid drift, do not over-extend).

### Step 4 — validate `skills/buildit-feature-validate/SKILL.md`
- Step 1: after "Set the status to `validating`", add: "If the tracking file has a `## Last error` section, remove it (it describes a previous run)."
- New step `### 2a. Staging guard` placed after step 2 (read constraints) and before `### 2b. Run test suite`: move the guard paragraph verbatim from step 3 (git status --porcelain, ignore `.scratch/`, flag `??`/unstaged). On flag: verdict NO-GO, skip tests, review and acceptance, go directly to "If NO-GO or FAIL". Remove it from step 3 (step 3 keeps a one-line reminder? No — remove, to avoid duplication; AT-STAGE-3 still passes because the first porcelain occurrence precedes the diff).
- Step 2b failure: replace "set status to `to-fix`, write Problems to fix, and stop" with "the verdict is **FAIL (tests)**: skip the review and acceptance phases and go directly to "If NO-GO or FAIL" with the failing tests (names + error excerpt) as the issue list."
- Step 2c (base branch unresolved): in addition to restoring `to-validate`, write in the tracking file a `## Last error` section with one line: `validate: base branch <base-branch> not found locally — set ## Base branch in .buildit/config.md or fetch it`. Order: 2a guard → 2b tests → 2c base branch. Self-critic: the base branch is only needed for the review diff, so 2c could move after tests; keep its position (resolve before review) — it is only reached when guard and tests pass.
- 5a: issue list includes failing tests and staging-guard files (state that it comes "from the staging guard, the test suite, the review and the acceptance phases" — whichever ran).
- 5c: "Count the `### NO-GO cycle` headings in the "Progress" section (ignore any other entry) to determine N." Progress template adds `- Tests: [PASS / FAIL — failing tests / not run]` and Review/Acceptance can be `not run`.
- End of skill (NO-GO/FAIL) unchanged.

### Step 5 — run `skills/buildit-feature-run/SKILL.md`
- Start subagent prompt (line ~140): `Skip the "Update shared-context.md" step (Merge readiness entry) — the merge readiness entry has already been written by the orchestrator.`
- WHY comment (line ~112): replace "(step 5 of buildit-feature-start)" with `(the "Update shared-context.md" step of buildit-feature-start)`.
- Step 5.5 (status unchanged after validate): if the tracking file has a `## Last error` section, stop and report its content verbatim: "buildit-feature-validate stopped: [Last error line]. Fix it and re-run `/buildit-feature-run [feature-name]` or `/buildit-feature-validate [feature-name]`."; otherwise keep the existing "possible subagent failure" message.
- Optionally note that run's own `cycle` counter stays the loop bound (audit #18 mentions run keeps a separate counter — acceptable; out of scope to merge them).

### Step 6 — verification
- `bash tests/run-all.sh` → all pass, including `test-config-parsing-boundary.sh` and `test-skills-invariants.sh`.
- grep check: no remaining `step 5` reference to start in run; validate has a single staging-guard description.
- `git status`: stage modified skill + test files and the tracking file per project rule (not the audit file or `.scratch/plan/`).

### Self-critique (applied above)
- Assumption: "every created/modified file" is known to the build agent — it is not tracked anywhere. Mitigation: the porcelain check catches anything missed; unrelated files cause a stop rather than a silent NO-GO cycle.
- Edge: in non-worktree mode, the root may contain unrelated untracked files (e.g. this very audit file is under `.scratch/`, so ignored — fine). Unrelated files outside `.scratch/` block both build and validate; the build stop message makes this explicit instead of burning a cycle.
- Edge: `## Last error` stale across runs → validate step 1 clears it; run only reads it when status is unchanged after validate.
- Edge: test-failure path now calls the 5a config subagent — costs a subagent per failing test cycle; accepted (acceptance criterion AT-4 requires it). The subagent should not invent rules for plain implementation bugs — its existing "only add rules that are absent / which configuration would have prevented it" wording covers that.
- Risk: README describes validate's order (test-readme AT-R8 checks "staging guard" mention only). Check README validate section for wording claiming tests run first; fix drift if present.
- Risk: existing tests asserting "Do not proceed / stop" on test failure (validate AT-8 regex `[Dd]o not proceed|[Ss]kip.*review|[Ss]top`) — new wording "skip the review" keeps it passing.
- Step 6 uses `git add` on explicit paths only.
- Not in scope: audit #7 (5a edits not staged → self-inflicted NO-GO) and #4 (tests in worktree). Do not touch, but don't make them worse.

## Progress

## Ship — 24-11-2026
- Readiness: ✓ OK to ship — base branch `main` (no `.buildit/config.md`); the only `IN_PROGRESS` row in Merge readiness is `fix/audit` itself (no other branch to compare for overlap); no `Waiting for`, no API & Contracts entries, no Constraints discovered.
- Post-validation change: one-word typo fix in `skills/buildit-feature-validate/SKILL.md` ("neither is evaluated" -> "none of them is evaluated"); `bash tests/run-all.sh` re-run before commit: 616 passed, 0 failed.
- Shared-context cleanup: removed the `fix/audit` Decisions & Conventions entry and Merge readiness row. The decision (the `## Last error` convention and the NO-GO-only cycle count) was migrated to `.buildit/guidelines/team-practices.md` § `.scratch/` (tracking-file conventions, next to the existing "Progress: one entry per NO-GO cycle" line).
- Orchestration files `.scratch/24-11-2026-audit-issues.md` and `.scratch/plan/` intentionally left out of the commit (owned by the plan).

## Retro
- What slowed the loop: nothing material on this feature (GO + PASS on the first validation). The tracking file reached ship with an empty Progress section and no Validation record, so the ship phase could not trace the validation evidence from the file itself — it relied on the orchestrator's notes and a fresh suite run.
- Would a configuration have prevented it: no new configuration added — validate only mandates a Progress entry on NO-GO; a GO record is a convention seen on previous features but not a rule. Left as-is to avoid widening scope; worth considering in a later audit task.
- Was the plan precise enough: yes — per-file edits, exact test assertions and an explicit self-critique (existing regexes that must stay green) made build and validation direct.
