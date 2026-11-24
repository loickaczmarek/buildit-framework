# task-ship-closing-commit

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 findings #5, #15, #34 (ship 3b part). Restructure `buildit-feature-ship` so the closing commit is built in execution order and carries only this feature's changes:
- In worktree mode ship copies the root `shared-context.md` (with other features' rows) into each feature commit, so parallel merges conflict and stale rows reach the base branch.
- Without worktree, ship never stages `.scratch/` (moved tracking file, shared-context cleanup).
- Commit (step 2) precedes cleanup (step 3); step 3b must run "after 4b" (amend dance); 3b re-reads `## Worktree path` from a tracking file already moved out of root.
- Left open by the previous task (in scope): ship step 0 uses `<worktree-path>` one paragraph before the paragraph that reads it; run step 6 takes `SHIP_REF` from the checked-out branch instead of the tracking file's `## Branch`.

Files: `skills/buildit-feature-ship/SKILL.md`, `skills/buildit-feature-run/SKILL.md` (step 6 `SHIP_REF` only), `README.md` (ship section + worktree working-directory sentence), `tests/test-buildit-feature-ship.sh`, `tests/test-buildit-feature-run.sh`.

## Acceptance Tests
- AT-1: feature commits no longer carry a full copy of `shared-context.md` (either excluded, or only this branch's removals are committed) — the chosen rule is stated explicitly.
- AT-2: ship steps are numbered in execution order: cleanup → retro/config migration → stage (`git [-C <worktree>] add` of `.scratch/` changes and migrations) → commit → worktree removal.
- AT-3: the non-worktree path explicitly stages the moved tracking file and the shared-context cleanup.
- AT-4: `WORKTREE_PATH` is read once at step 0 and reused by worktree removal.
- AT-5: README ship section matches the new step order; tests assert AT-1 to AT-4; `bash tests/run-all.sh` passes.
- (Scope extras) AT-6: ship step 0 reads `## Worktree path` before any paragraph that uses `<worktree-path>`. AT-7: run step 6 takes `SHIP_REF` from the tracking file's `## Branch` (fallback: checked-out branch for legacy files, then `HEAD`), and its three post-ship checks still match the restructured ship.

## Plan

### Decisions (taken autonomously — no human available)
- **Worktree: no** — imposed by the orchestrator; work on `fix/audit`.
- **AT-1 rule: "only this branch's removals are committed"** (not "excluded"). Reason: the project rule "Cleaning `shared-context.md` mandatory in the closing commit" stays true, and `shared-context.md` is git-tracked (`.scratch/shared-context.md` is in `git ls-files`), so excluding it would leave the branch's committed entries (if any) stale. Concretely: the staged version of `.scratch/shared-context.md` = the version already in the feature branch's index minus this feature's entries — never the live root file, which holds other features' uncommitted rows.
  - Worktree mode: apply the same removals to the worktree's own `.scratch/shared-context.md` (the branch copy, not the root one) and stage it with `git -C <worktree-path> add .scratch/shared-context.md`. Never copy the root file into the worktree. Usually a no-op (rows are added in root, uncommitted) — then nothing to stage for it.
  - Non-worktree: the root file is both the live file and the feature's working copy. Stage it with `git add .scratch/shared-context.md` only if `git diff -- .scratch/shared-context.md` (working tree vs index) shows nothing but removals of this feature's entries. Otherwise (other features' uncommitted entries present) stage only this feature's removals without touching the working copy: `git show :.scratch/shared-context.md` → remove this feature's entries → `git hash-object -w --stdin` → `git update-index --cacheinfo 100644,<blob>,.scratch/shared-context.md`. Non-interactive (no `git add -p`).
- **Tracking file staging**: tracking files are never staged before ship (build step 5 excludes `.scratch/`), so the moved file is new: `git [-C <worktree-path>] add .scratch/done/<file>`. For robustness, if the old path was tracked/staged, also `git rm --cached --quiet --ignore-unmatch -- .scratch/<file>` (no error when untracked). Never `git add -A .scratch/` — it would sweep untracked plan files and other features' tracking files.
- **No more amend**: config updates from the retro happen before the commit, so `commit --amend` and the "run 3b after 4b" constraint disappear.

### New step layout of `skills/buildit-feature-ship/SKILL.md`
- **0. Identify the feature** — reorder paragraphs: identify file → remove `## Last error` → **Worktree path** paragraph (read `## Worktree path` once, store `WORKTREE_PATH`; `none` = no worktree; "reused by step 6 — never re-read it from the tracking file, which step 4 moves") + working-directory rule → **Feature branch** paragraph (legacy fallback now uses an already-defined `<worktree-path>`). Define `<worktree-path>` = `WORKTREE_PATH`.
- 0a, 0b unchanged.
- **1. Readiness check** — unchanged except: "the commit happens in step 5".
- **2. Clean shared-context.md** (was 3) — root file cleanup + migrations; keeps `Merge readiness … remove … <feature-branch>` wording (AT-BR-4 test) and decision trees. Migrations to `<guidelines-dir>`/`<rules-file>`: inside the worktree in worktree mode, else project root.
- **3. Light retro** (was 4) + **3b. Update configurations if needed** (was 4b) — edit files (inside the worktree in worktree mode); no amend; "staged in step 4".
- **4. Stage the closing changes** — move tracking file to `.scratch/done/` (root); worktree mode: copy only the archived tracking file into the worktree at the same path; stage explicit paths with `git [-C <worktree-path>] add`: `.scratch/done/<file>`, shared-context per the AT-1 rule (state the rule explicitly with a bold "Shared-context rule" label), migrated/updated guideline and rules files. Explicit "Without worktree" bullet (AT-3) and "Worktree mode" bullet.
- **5. Commit** — `git [-C <worktree-path>] commit`, message format.
- **6. Worktree cleanup** — only if `WORKTREE_PATH` is not `none` (value from step 0): remove the root copy of `.scratch/done/<file>` (branch carries it; untracked copy would block merge), then `git worktree remove <WORKTREE_PATH>`; warn on failure without blocking. Root `shared-context.md` stays modified on purpose (live coordination file).
- "Running as a subagent": blocking only happens at steps 0–1, before any change — keep "Do not commit, do not move the tracking file". End of skill unchanged.
- Update frontmatter description order: "checks shared-context readiness, cleans shared-context, migrates durable constraints to guidelines, runs retro, commits" (check `test-quote-skill-descriptions.sh` / invariants don't pin the text).

### `skills/buildit-feature-run/SKILL.md` step 6
- `SHIP_REF` — read `## Branch` from the tracking file (bare name). Legacy file without it: checked-out branch (`git [-C <worktree-path>] branch --show-current`); empty → `HEAD`. Keep `git rev-parse <SHIP_REF>`, `git cat-file -e <SHIP_REF>:.scratch/done/<TRACKING_FILE>`, and check 3 — all still hold (ship commits on the feature branch, archived file in the commit, root copy removed in worktree mode / moved in non-worktree mode). Update the check-2 parenthesis "worktree mode removes the root copy" (still true).

### README
- Ship section: steps renumbered 1 Readiness → 2 cleanup → 3 retro + config update → 4 stage → 5 commit → 6 worktree removal; state the shared-context rule (only this branch's removals; root file never copied).
- Worktree working-directory sentence (~line 586): replace "Ship copies its `.scratch/` changes into the worktree" with the new rule (copies only the archived tracking file; applies this feature's shared-context removals to the worktree's copy).
- Overview flow line 52 "readiness check + commit + shared-context cleanup + retro" → reorder to "readiness check + shared-context cleanup + retro + commit".

### Tests (write failing first)
`tests/test-buildit-feature-ship.sh`:
- Keep existing assertions, adapt: section helper bounds `### 3. `→ cleanup is now `### 2. ` (AT-BR-4 SH3 → SH2 between `### 2. ` and `### 3. `); AT-WT-3 regex (copy … into the worktree) still true for the tracking file; AT-WT-4 still true; AT-WT-5 still true.
- AT-1: no `cp`/"copy `.scratch/shared-context.md`" into worktree (`require_absent` on `[Cc]opy .scratch/shared-context.md` pattern); presence of explicit rule text "only this feature's removals" + `git update-index --cacheinfo`; `require_absent` `add -A .scratch/`.
- AT-2: headings `### 2.`..`### 6.` exist in order and contain Clean shared-context / retro / Update configurations / Stage / Commit / Worktree cleanup in that order (awk line-number ordering); `commit --amend` absent; "after step 4b" absent.
- AT-3: step 4 section contains `git add .scratch/done/` and `git add .scratch/shared-context.md` and a "Without worktree" marker.
- AT-4: step 0 section contains `WORKTREE_PATH`; step 6 section contains `WORKTREE_PATH` and does not contain "Read the `## Worktree path`".
- AT-6: in step 0, the line number of first `<worktree-path>` use is after the line that reads `## Worktree path`.
- AT-5 README: README ship section has "Stage" before "Commit" bold step headers in order and mentions only this branch's removals.
`tests/test-buildit-feature-run.sh`: AT-7 — step 6 `SHIP_REF` line references `## Branch`.

## Self-critique (applied above)
- Assumption "tracking file never tracked before ship" — true per build step 5, but legacy/manual runs may have staged it → added `git rm --cached --ignore-unmatch` for the old path.
- Non-worktree shared-context with other features' uncommitted rows was not covered by the audit text; plain `git add` would reintroduce finding #5 in non-worktree mode → added the index-only update path.
- `git add .scratch/shared-context.md` when there is no diff is harmless; `git update-index` path only when needed.
- Run step 6 check 2 relies on `SHIP_REF` being the feature branch; in non-worktree mode `## Branch` = checked-out branch, so behaviour is unchanged there; in worktree mode the branch ref survives worktree removal.
- Step numbers referenced elsewhere: run/README/start reference "ship" generically, not step numbers (grep done) — only README ship section needs renumbering.
- Risk: existing tests grepping exact text (AT-BR-4 `### 3. `/`### 3b.` bounds, AT-WT-*) must be updated in the same change; run full suite.
- Never stage `.scratch/24-11-2026-audit-issues.md` or `.scratch/plan/`.

## Progress
- 24-11-2026: start — plan written (worktree: no, branch `fix/audit`).
- 24-11-2026: build — tests written first (18 new ship assertions + AT-SV-1h in run, all failing on assertion), then implementation. `bash tests/run-all.sh`: 669 passed, 0 failed. Staged: ship SKILL.md, run SKILL.md, README.md, the two test files.

### NO-GO cycle 1 — 24-11-2026
- Tests: PASS (669 passed, 0 failed)
- Review: NO-GO — README.md duplicated manual-flow skill sections, with a stale second ship section describing the old commit-first order; tests do not detect the duplicate
- Acceptance: FAIL — AT-5 (README ship section contradicts itself); AT-1, AT-2, AT-3, AT-4, AT-6, AT-7 PASS
- Validate step 5a: two rules added to `.buildit/guidelines/team-practices.md` (README sections replaced in place + uniqueness check; test-readme.sh heading-uniqueness and negative assertions on superseded wording). That file is now modified and unstaged: build must stage it with the fix.
- 24-11-2026: build (fix cycle 1) — removed the duplicated second copy of "Manual flow skills" + start/build/validate/ship sections from README.md (start/build/validate copies were byte-identical; the second ship copy held the old commit-first order). Restored the ship "Use cases" block (present at HEAD, dropped from the first copy). Added AT-R9 to tests/test-readme.sh (each `### <skill>` heading, each top-level `## ` heading outside fences, and the "Manual flow skills" block appear exactly once) and three whole-README `require_absent` checks to AT-CC-5 (`**2. Commit**`, `(in the same commit)`, "the update is included in the commit"). New assertions verified failing against the previously staged README, passing after the fix. `bash tests/run-all.sh`: 695 passed, 0 failed. Staged: README.md, tests/test-readme.sh, tests/test-buildit-feature-ship.sh, .buildit/guidelines/team-practices.md (validate's config update).
- 24-11-2026: validate (after fix cycle 1) — staging guard clean (only `.scratch/` unstaged); `bash tests/run-all.sh`: 695 passed, 0 failed; review GO on 6 dimensions (staged diff: ship/run SKILL.md, README.md, 3 test files, team-practices.md); acceptance AT-1..AT-7 PASS (README has exactly one `### buildit-feature-ship` section, superseded wording absent). Non-blocking notes: build/validate working-directory sentences still list `commit --amend` (out of scope, already recorded); step 4 worktree mode writes the worktree's own `.scratch/` copies — an explicit, documented exception to the step 0 "`.scratch/` in project root" rule. Status → to-ship.

## Build decisions
- Test ids use the `AT-CC-*` prefix (closing commit) in `test-buildit-feature-ship.sh` to avoid colliding with the existing `AT-1`..`AT-7` labels there; run test is `AT-SV-1h`.
- `line_of`/`rl` helpers end with `|| true`: under `set -euo pipefail` an empty grep would abort the script instead of reporting a FAIL.
- AT-CC-1 absent-pattern is `[Cc]opy `?\.scratch/shared-context\.md` (matches the old "copy `.scratch/shared-context.md` ... into the worktree" wording, not unrelated prose).
- Worktree mode shared-context: plain `git -C <worktree-path> add` after applying the removals to the worktree copy — no index-only path there, since nothing else edits the worktree's `.scratch/` (KISS).
- Step 6 root-copy removal phrased "In the project root, remove the root copy" to keep AT-WT-5's lowercase regex.
- Out of scope, left unchanged: build/validate working-directory sentences still list `commit --amend` (validate's config update may amend).
- Fix cycle 1: restored the ship "Use cases" bullets from HEAD rather than leaving them out — they were lost only because the new steps were written into a copy instead of the original block.
- No shared-context "Decisions & Conventions" entry: the shared-context rule lives in the ship skill itself; explicit-path staging already exists in build step 5.

## Retro
- Slowdown: one NO-GO cycle — the new ship steps were written into a duplicated copy of the README manual-flow sections, leaving a stale second ship section; tests did not check heading uniqueness.
- Config: yes — validate 5a already added the README in-place replacement / uniqueness rules to `.buildit/guidelines/team-practices.md`, and test-readme.sh AT-R9 now enforces it. No further config change needed.
- Plan precision: good — the step layout, the shared-context staging rule and the AT list were applied as planned; only the README edit method was underspecified.
