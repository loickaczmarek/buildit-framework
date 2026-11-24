# task-merge-readiness-branch-key

## Status
to-ship

## Worktree path
none

## Goal
Audit 24-11-2026 findings #1, #14, #35. In worktree mode, start (step 5) and run (step 2) read `git branch --show-current` in the project root, so the Merge readiness row is keyed `main` instead of `feature/YYYY-MM-DD-name`; ship's overlap check then diffs `main` against `main` and cannot remove the row. Run also writes the row before start, leaving an orphan row when start fails or is cancelled, and ship's overlap loop does not skip the feature's own row.

Files: `skills/buildit-feature-start/SKILL.md`, `skills/buildit-feature-run/SKILL.md`, `skills/buildit-feature-ship/SKILL.md`, `skills/buildit-worktree/SKILL.md`.

The new `## Branch` tracking-file section is a contract that later tasks (`task-ship-closing-commit`, `task-start-step-ordering`) build on, so it must be clearly documented (format, who writes it, who reads it).

## Acceptance Tests
- AT-1: start persists a `## Branch` section in the tracking file, taken from `buildit-worktree`'s returned branch in worktree mode, or from `git branch --show-current` otherwise.
- AT-2: the Merge readiness row is written with the value of `## Branch`, after the worktree exists.
- AT-3: run no longer writes the Merge readiness row before start succeeds (or rolls it back on start failure/cancel).
- AT-4: ship reads the branch from `## Branch` for row removal and overlap checks, and the overlap loop skips the current branch.
- AT-5: tests assert AT-1 to AT-4; `bash tests/run-all.sh` passes.

## Decisions (no human available — taken autonomously)
- D1 — **Single writer for the Merge readiness row: `buildit-feature-start`.** Run's step 2 ("Trigger early write permission") is removed instead of rolled back: the row's key (`## Branch`) only exists once start has created the worktree, so the orchestrator cannot write a correctly keyed row before start, and a rollback path would add a second writer plus cancel handling for no benefit. Run's start prompt no longer tells start to skip the "Update shared-context.md" step. Trade-off accepted: the first write permission prompt now happens inside the start subagent (tracking file creation). The `### Orchestrator-level permission trigger` guideline in `.buildit/guidelines/team-practices.md` gets a caveat: never pre-write state whose key depends on a subagent's result.
- D2 — **`## Branch` contract.** Format: a section `## Branch` whose value is the first non-empty line below it, a bare branch name without backticks (e.g. `feature/2026-11-24-my-widget` or `fix/audit`). Placed right after `## Status`, before `## Worktree path`. Writer: `buildit-feature-start` only, once, at tracking-file creation; never rewritten by other phases. Readers: `buildit-feature-start` step 5 (row key), `buildit-feature-ship` (row removal, overlap self-skip), and later tasks (`task-ship-closing-commit`, `task-start-step-ordering`).
- D3 — **Source of the value.** Worktree mode: the `Branch: <BRANCH>` line returned by `buildit-worktree` (new machine-readable output line added next to `Worktree created at: <path>`). No-worktree mode: `git branch --show-current` in the project root, captured in step 0.
- D4 — **Detached HEAD.** If `git branch --show-current` is empty in no-worktree mode, start stops with a message asking to check out a branch: a Merge readiness row and ship's overlap checks need a real branch name. (Worktree mode always has a branch.)
- D5 — **Legacy tracking files (no `## Branch`).** Ship falls back to `git -C <worktree-path> branch --show-current` (worktree mode) or `git branch --show-current` (otherwise) and warns once. Keeps in-flight features shippable.
- D6 — **Run step 6 `SHIP_REF`** is left unchanged (out of scope; already worktree-aware). No new guard in run on `## Branch`: start owns the contract, and run keeps its existing "tracking file not found" guard.
- D8 — **Run step numbering kept (build phase).** Run's step 2 is replaced by a short "Merge readiness row: left to start" note instead of renumbering: step 6 (ship verification) and the "step 0 / step 6" references in tests (`S6`), `.buildit/guidelines/team-practices.md` and the isolation preamble stay valid with no churn.
- D9 — **Invariant test update (build phase).** `buildit-feature-run` removed from the `WRITERS` list in `tests/test-skills-invariants.sh` (skills that write `shared-context.md` must carry the sequential-access note): run no longer writes that file, so a sequential-access note there would be misleading.
- D10 — **No `shared-context.md` Decisions entry (build phase).** The `## Branch` contract went straight into `.buildit/guidelines/team-practices.md` (D7), so a Decisions & Conventions entry would only duplicate it before ship migrates it.
- D7 — Contract documented in `.buildit/guidelines/team-practices.md` (`## .scratch/` → tracking file sections line + a `Branch:` paragraph) and the README start/ship sections updated for consistency (small wording edits only).

## Plan
1. **Failing tests first** (extend existing test files, keep `require_*` helpers from `tests/lib/assertions.sh`):
   - `tests/test-buildit-feature-start.sh` (AT-BR-*):
     - template contains a `## Branch` section placed between `## Status` and `## Worktree path` (line-order check with `grep -n`).
     - worktree mode takes the branch from `buildit-worktree`'s returned `Branch:` line (regex `buildit-worktree.*Branch:|Branch:.*buildit-worktree`, or a dedicated phrase).
     - no-worktree mode takes it from `git branch --show-current`.
     - step 5 (Merge readiness) uses the `## Branch` value — assert text like `` `## Branch` `` appears in the step 5 block (extract step 5 with `awk '/^### 5\./,/^## End of skill/'`), and that step 5 no longer runs `git branch --show-current` (require_absent within the extracted block).
     - detached-HEAD stop message present.
   - `tests/test-buildit-worktree.sh`: output contains a `Branch: <BRANCH>` line.
   - `tests/test-buildit-feature-run.sh`: replace AT-13/13b/13c/14/15 (early write) with: no `### ...early write / permission trigger` heading; start subagent prompt no longer contains `Skip the "Update shared-context.md" step`; no `IN_PROGRESS` row write appears before the `### 3. Subagent: buildit-feature-start` heading (line-order check: first `| IN_PROGRESS |` / `Merge readiness` occurrence absent or after start heading). Keep AT-P*, ship-verify and "Running as a subagent" assertions intact.
   - `tests/test-buildit-feature-ship.sh` (AT-BR-*): ship reads `## Branch` in step 0 (store as `<feature-branch>`); step 1 overlap loop skips `<feature-branch>` (regex `skip.*<feature-branch>|<feature-branch>.*skip`); step 3 removes the Merge readiness line for `<feature-branch>`; legacy fallback mentioned.
   - Run `bash tests/run-all.sh` and confirm the new assertions fail for the right reason.
2. **`skills/buildit-worktree/SKILL.md`**: step 4 outputs two lines exactly — `Worktree created at: <WORKTREE_PATH>` and `Branch: <BRANCH>`; say the caller records the branch in `## Branch`. Update End of skill if needed (already mentions branch).
3. **`skills/buildit-feature-start/SKILL.md`**:
   - Step 0 Yes: capture also the `Branch:` line as `BRANCH`. Step 0 No: `BRANCH=$(git branch --show-current)`; if empty → stop (D4). Keep the existing "`.scratch/` files ... stay in the project root" sentence (AT-WT-1).
   - Step 3 template: add `## Branch` / `[BRANCH — bare branch name]` after `## Status`.
   - Add a short "**`## Branch` contract**" paragraph after the template (format, written once by start, read by start step 5 and ship; never rewritten).
   - Step 5: replace `git branch --show-current` with "Read the `## Branch` value from the tracking file" and write the row with it; state it runs after the worktree exists (step 0) and after the tracking file exists (step 3).
4. **`skills/buildit-feature-run/SKILL.md`**:
   - Remove step 2 (the early write + its WHY comment and the sequential-access note that only applied to it) and renumber following steps 3→2, 4→3, 5→4, 6→5; update every in-text reference (isolation preamble sentence "steps 3, 5.2, 5.4 and 6", "found at step 4", "same way as at step 0" stays). Check tests that reference step numbers (`grep -n "step [0-9]" tests/test-buildit-feature-run.sh`) before renumbering — if renumbering breaks unrelated assertions, keep numbering and replace step 2 with nothing (renumber anyway is preferred only if tests allow; otherwise simpler: renumber and update tests).
   - Remove the "Skip the "Update shared-context.md" step ..." line from the start subagent prompt; add one sentence: start writes the Merge readiness row itself, keyed by `## Branch`, only once the worktree and tracking file exist — so a failed or cancelled start leaves no orphan row.
5. **`skills/buildit-feature-ship/SKILL.md`**:
   - Step 0: read `## Branch` → `<feature-branch>`; legacy fallback (D5). Do not touch `## Running as a subagent`.
   - Step 1: "For each `IN_PROGRESS` branch listed in Merge readiness **other than `<feature-branch>`** (skip this feature's own row)". Keep the exact strings asserted today (`git diff --name-only --merge-base <base-branch> <branch>`, `git diff --cached --merge-base <base-branch> --name-only`, Config value rule wording for `## Base branch`).
   - Step 3: "remove the line for `<feature-branch>`".
   - Do not restructure commit/cleanup ordering (that is `task-ship-closing-commit`).
6. **Docs**: `.buildit/guidelines/team-practices.md` — add `Branch` to the tracking-file sections line and a `Branch:` paragraph describing the contract (D2); add caveat to "Orchestrator-level permission trigger" (D1). `README.md` — start "What it does" item 4/7 mention `## Branch` and the row keyed by it; run item list unaffected (no early write was documented); ship cleanup line "removes the line for this branch (`## Branch`)". Check `tests/test-readme.sh` still passes.
7. `bash tests/run-all.sh` — all green; `git status`, stage every modified file (never `.scratch/24-11-2026-audit-issues.md` nor `.scratch/plan/`).

## Self-critique
- Assumption "removing run step 2 is acceptable" conflicts with the existing guideline on orchestrator-level permission trigger and with run tests AT-13..15 → handled explicitly by D1 (guideline caveat + test replacement). AT-3 allows either removal or rollback; removal is the simpler one.
- Renumbering run steps may break other tests or cross-references (README "steps", isolation preamble). Mitigation added in plan step 4: grep tests and text for step numbers before renumbering.
- `task-start-step-ordering` will later move the worktree creation after the name/prereq steps; the `## Branch` capture is tied to the worktree return value, not to a step number, so it survives the reorder. Step 5 wording must reference "the `## Branch` value", not "step 0", to stay valid.
- Edge case: no-worktree run on the same branch as another feature (e.g. two features on `fix/audit` sequentially) → two rows with the same key. Out of scope; ship removes the line for `<feature-branch>` — note it removes only one line (the feature's own). Acceptable; mention "remove this feature's line" not "all lines".
- Edge case: detached HEAD (D4) and legacy tracking files (D5) covered.
- Edge case: start run with "skip step 5" by an orchestrator (as in this very run) — still valid; skip instruction is no longer emitted by run.
- Risk: test regexes too loose (e.g. `## Branch` already matches `## Base branch`? No — case-sensitive `## Branch` vs `## Base branch` differ; but use `grep -F '## Branch'` carefully: `## Base branch` does not contain `## Branch`). OK.
- Risk: Config value rule test (tests/test-config-parsing-boundary.sh) scans skill text reading config.md values; `## Branch` is a tracking-file section, not config.md — avoid phrasing like "read `.buildit/config.md`" near it, and do not reuse the phrase "first non-empty, non-comment line" for `## Branch` (that test flags it unless followed by the full Config value rule wording) — describe the value as "the line below the heading".

## Progress
### Build — 24-11-2026
- Tests first: AT-BR-* added to `tests/test-buildit-feature-{start,run,ship}.sh` and `tests/test-buildit-worktree.sh`; run AT-13..15 (early write) and AT-SC-5 "Skip the ... step" assertion replaced. All new assertions failed on the assertion before implementation.
- Implemented: worktree outputs `Branch: <BRANCH>`; start captures `BRANCH` (detached HEAD stops), template has `## Branch` with a documented contract, step 5 keys the row with `## Branch`; run's early write and skip instruction removed; ship reads `<feature-branch>` from `## Branch` (legacy fallback), the overlap loop skips it, step 3 removes its row. Guideline and README updated.
- `bash tests/run-all.sh`: 650 passed, 0 failed. Work staged (`.scratch/` plan files left untouched).
### Validate — 24-11-2026
- Staging guard: OK (only `.scratch/` entries unstaged/untracked, ignored by design; plan files left untracked).
- Tests: `bash tests/run-all.sh` — 650 passed, 0 failed (no `.buildit/config.md`: Tier 2 fallback; base branch defaults to `main`).
- Review (scope: `git diff --cached`, earlier audit tasks already committed on fix/audit): GO.
  - Correctness: `## Branch` written once by start (worktree `Branch:` line / `git branch --show-current`, detached HEAD stops), row keyed by it in step 5, run's early write and skip instruction removed, ship reads `<feature-branch>` with legacy fallback, skips own row, removes own row. No remaining skill keys the row with the root's current branch.
  - Performance / Security: n/a (docs-only skill changes, no new shell injection surface).
  - Style: English, `type`-free doc edits, `.claude/skills` is a symlink so dual deployment is in sync.
  - Test coverage: AT-BR-1..4 assertions in start/run/ship/worktree tests; invariant WRITERS list updated.
  - Craft: contract text appears in both the start skill and the repo guideline — accepted (decision V1).
  - Non-blocking notes: ship step 0 "Feature branch" paragraph references `<worktree-path>` one paragraph before the "Working directory" paragraph that reads it — readable, left as is (V2). Run step 6 `SHIP_REF` still uses `git branch --show-current` (out of scope per D6).
- Acceptance: AT-1 PASS, AT-2 PASS, AT-3 PASS (removal variant), AT-4 PASS, AT-5 PASS → PASS overall.
- Decisions (no human available):
  - V1 — Contract duplication between `skills/buildit-feature-start/SKILL.md` and `.buildit/guidelines/team-practices.md` is not a DRY violation to block on: skills are deployed to other projects where this repo's guideline does not exist, so the skill must carry its own contract; ship points to start step 3 rather than copying it.
  - V2 — Paragraph order in ship step 0 not flagged as blocking (the meaning is unambiguous).
### Ship — 24-11-2026
- Feature branch: no `## Branch` in the tracking file (it predates the contract) — fell back to the checked-out branch `fix/audit` (legacy fallback D5).
- Readiness: ✓ OK to ship. Only Merge readiness row is this feature's own (`fix/audit`, skipped by the overlap loop); no `Waiting for`, no API entries, no constraints.
- Shared-context cleanup: `fix/audit` row removed; Constraints / Decisions empty (the `## Branch` contract was already written to `.buildit/guidelines/team-practices.md` during build, D10), so nothing to migrate.
- Tests: `bash tests/run-all.sh` — 650 passed, 0 failed.
- Retro (no human available, answered autonomously):
  - Slowdown: the plan was unsure about renumbering run's steps (D8) and how the invariant WRITERS list should change (D9), so build had to decide both mid-loop.
  - Config gap: none worth adding. The step-number references already sit in the tests and guidelines; the D1 caveat ("never pre-write state whose key depends on a subagent's result") went into the guideline during build.
  - Plan precision: enough — every AT mapped to concrete test assertions and validate passed on the first cycle. No configuration update (step 4b skipped).
