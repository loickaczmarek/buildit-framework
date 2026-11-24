# task-run-verifies-ship

## Status
to-ship

## Worktree path
none

## Goal
Audit 24-11-2026 finding #3 (full audit: `.scratch/24-11-2026-audit-issues.md`).

After the ship subagent returns, `buildit-feature-run` marks the plan task `done`, ticks plan.md, pushes `done` to the external ticket (irreversible) and reports success without checking that ship committed. Ship's blocking case "waits for human confirmation", which a subagent cannot do, so it returns without committing.

Files: `skills/buildit-feature-run/SKILL.md`, `skills/buildit-feature-ship/SKILL.md` (+ README drift, tests).

## Acceptance Tests
- AT-1: before updating the plan task, run verifies that the tracking file is under `.scratch/done/` and that a new commit exists; otherwise it stops with an explicit "unexpected state after ship" message and leaves the plan and external ticket unchanged.
- AT-2: ship's blocking case, when running as a subagent, returns an explicit blocked signal instead of waiting for input.
- AT-3: tests assert AT-1 and AT-2; `bash tests/run-all.sh` passes.

## Plan

Context / constraints:
- Work directly on branch `fix/audit` (no worktree). `.claude/skills` is a git-tracked symlink to `../skills` — edit `skills/` only.
- Skill text in English. No new `.buildit/config.md` reads are needed; if one is added, use the exact Config value rule wording (enforced by `tests/test-config-parsing-boundary.sh`).
- Reuse the existing `## Last error` convention (`.buildit/guidelines/team-practices.md` § `.scratch/`): a phase skill that stops deliberately without changing the status records one line in `## Last error`; run reports it. The guideline wording is already generic ("a phase skill"), so no guideline change is required.
- Do not stage/commit `.scratch/24-11-2026-audit-issues.md` or `.scratch/plan/`.
- Baseline: `bash tests/run-all.sh` → 616 passed, 0 failed (24-11-2026).

### Decisions (taken autonomously — nobody available to answer)
- D1 — "New commit" detection: run records the feature branch ref and its SHA **before** launching ship: `SHIP_REF` = `git branch --show-current` (non-worktree) or `git -C <worktree-path> branch --show-current` (worktree mode); `PRE_SHIP_HEAD` = `git rev-parse <SHIP_REF>`. After ship: `git rev-parse <SHIP_REF>` must differ from `PRE_SHIP_HEAD`. Using the branch name (not `HEAD` of the worktree) works after ship step 3b removed the worktree, since branch refs are shared. A 4b `--amend` still yields a SHA different from `PRE_SHIP_HEAD` — fine. Fallback if `SHIP_REF` is empty (detached HEAD, non-worktree): use `HEAD`.
- D2 — "Tracking file under `.scratch/done/`": check `git cat-file -e <SHIP_REF>:.scratch/done/<tracking-file-name>` (the file is committed in the feature commit in both modes) AND that the tracking file no longer exists in `.scratch/` outside `done/`. Rationale: in worktree mode ship deletes the root copy of `.scratch/done/<file>` after committing, so a filesystem check on the root `.scratch/done/` would give a false failure; the committed path is the reliable invariant in both modes.
- D3 — How ship knows it runs as a subagent: run's ship prompt states it explicitly ("You are running as a subagent: no human can answer. If ship blocks, follow its "Running as a subagent" rule."). Ship also documents a general rule: when launched as a subagent (by `buildit-feature-run` or any orchestrator), every step that would wait for human confirmation returns the blocked signal instead. This covers both the readiness-check blocking case (AT-2) and step 0's "wait for confirmation" on a status mismatch.
- D4 — Blocked signal format: ship does not commit, does not move the tracking file, leaves the status `to-ship`, writes a `## Last error` section with the single line `buildit-feature-ship: blocked — <precise reason>`, and ends with a final message starting with `SHIP BLOCKED: <precise reason>`. Two channels on purpose: the tracking file is what run reads deterministically; the final message is the subagent's return value.
- D5 — Run's stop message on failed verification: `"Unexpected state after ship: <failed check(s)>[ — ship reported: <Last error line>]. The plan task and external ticket were left unchanged. Inspect .scratch/ and git log, then re-run /buildit-feature-ship [feature-name] manually."` One message covers both the blocked case and silent failure (AT-1 wording "unexpected state after ship"). No `Pending:` entry is written (no done transition happened, so there is nothing pending). The plan task stays `in-progress`.
- D6 — Ship removes a stale `## Last error` section when it starts (mirror of validate step 1), so a re-run after a block does not carry the previous reason into the shipped file.

### Step 1 — Failing tests first
New section `# --- Ship verification (AT-SV-*) ---` in:

`tests/test-buildit-feature-run.sh` (AT-1):
- AT-SV-1a: text `PRE_SHIP_HEAD` and `git rev-parse` present; regex for recording before launching ship: line of `PRE_SHIP_HEAD` assignment < line of the ship subagent prompt `Run /buildit-feature-ship` (grep -n).
- AT-SV-1b: text `.scratch/done/` within step 6 and `git cat-file -e` present.
- AT-SV-1c: text `Unexpected state after ship` present.
- AT-SV-1d: text `left unchanged` (plan task and external ticket).
- AT-SV-1e: ordering — line of `Unexpected state after ship` < line of `**Update plan task on completion**` (verification happens before the plan update and the `done` push). Also < line of `shipped successfully`.
- AT-SV-1f: ship subagent prompt says it runs as a subagent: regex `running as a subagent` inside the step 6 prompt range.
- AT-SV-1g: no `Pending:` written on this path — assert text `no `Pending:` entry` (exact phrase decided: "write no `Pending:` entry").

`tests/test-buildit-feature-ship.sh` (AT-2):
- AT-SV-2a: heading/section `Running as a subagent` exists.
- AT-SV-2b: text `SHIP BLOCKED:` present.
- AT-SV-2c: text `buildit-feature-ship: blocked —` and `## Last error` present.
- AT-SV-2d: the blocking verdict line in step 1 references the subagent rule: regex `If blocking.*subagent` (same paragraph/line).
- AT-SV-2e: blocked path says do not commit: regex `[Dd]o not commit`.
- AT-SV-2f: stale `## Last error` removal at start: regex `remove.*## Last error|## Last error.*remove`.

`tests/test-readme.sh` or the run test (README drift): README ship section no longer says only "waits for human confirmation" — assert `SHIP BLOCKED` or `blocked signal` appears in README ship section; README run step 4 mentions verification (`verifies` + `commit`). Place in `tests/test-buildit-feature-run.sh` / `tests/test-buildit-feature-ship.sh` (they already check README in places) to keep things local.

Run `bash tests/run-all.sh` → only new assertions fail.

### Step 2 — `skills/buildit-feature-ship/SKILL.md`
1. Add a short section `## Running as a subagent` after "When to use": when launched as a subagent (e.g. by `buildit-feature-run`), no human can answer. Any step that says "wait for confirmation" instead: do not commit, do not move the tracking file, leave the status `to-ship`, add a `## Last error` section with the single line `buildit-feature-ship: blocked — <precise reason>`, and end with a final message starting with `SHIP BLOCKED: <precise reason>`.
2. Step 0: after identifying the file, "If the tracking file has a `## Last error` section, remove it (it describes a previous run)." Step 0 status-mismatch wait: append "(as a subagent: blocked signal — see "Running as a subagent")".
3. Step 1 verdict: `If blocking: explain the issue and wait for human confirmation before continuing. As a subagent, return the blocked signal instead (see "Running as a subagent") — do not commit.` Keep on a single line so AT-SV-2d regex matches.
4. Keep the rest unchanged. Check that "End of skill" still makes sense (add: "If blocked: nothing committed, `SHIP BLOCKED:` reported.").

### Step 3 — `skills/buildit-feature-run/SKILL.md` step 6
1. Before launching the ship subagent: "**Record the pre-ship state**" — `SHIP_REF` and `PRE_SHIP_HEAD` per D1; note the tracking file name (`TRACKING_FILE` basename) from step 4.
2. Ship prompt: add the line `You are running as a subagent: no human can answer. If ship blocks, follow its "Running as a subagent" rule (blocked signal) instead of waiting.`
3. New block "**Verify ship before closing the task**" after "Wait for completion" and before "**Update plan task on completion**": checks (a) `git rev-parse <SHIP_REF>` ≠ `PRE_SHIP_HEAD`; (b) `git cat-file -e <SHIP_REF>:.scratch/done/<TRACKING_FILE>` succeeds; (c) the tracking file is no longer in `.scratch/` outside `done/`. If any fails → stop with the D5 message (include the `## Last error` line of the tracking file if present, and/or the subagent's `SHIP BLOCKED:` line); do not update the plan task, plan.md, or the external ticket; write no `Pending:` entry. Only if all pass, continue.
4. Make the success message explicitly conditional on the verification passing (it already follows the plan update; the stop prevents reaching it).

### Step 4 — README
- Line ~406 (run step 4): "On GO + PASS: delegates `buildit-feature-ship`, verifies that ship committed (new commit + tracking file in `.scratch/done/`) — otherwise stops with "Unexpected state after ship" and leaves the plan task and external ticket unchanged — then updates plan task status to done if applicable, then reminds…".
- Line ~548 (ship verdict): "If blocking, waits for human confirmation — or, when running as a subagent, commits nothing and returns `SHIP BLOCKED: <reason>` (also recorded in `## Last error`)."
- Run `bash tests/test-readme.sh` (structure check).

### Step 5 — Verification
- `bash tests/run-all.sh` → all pass (incl. `test-config-parsing-boundary.sh`, `test-skills-invariants.sh`, `test-readme.sh`).
- Stage modified skill, README and test files plus this tracking file explicitly (`git add <paths>`), never the audit file or `.scratch/plan/`; `git status --porcelain` clean outside `.scratch/` before `to-validate`.

### Self-critique (applied above)
- Assumption "tracking file under `.scratch/done/` on disk" is false in worktree mode (ship deletes the root copy after commit) → D2 checks the committed path instead.
- Assumption "compare HEAD" fails in worktree mode once 3b removes the worktree → D1 uses the branch ref, shared across worktrees.
- Edge: ship committed but 4b amend failed — still a new commit with the done file → verification passes; acceptable (retro updates are best-effort).
- Edge: ship blocked at step 0 (status mismatch) with feature-name given by run — unlikely (direct lookup), but covered by the general subagent rule (D3).
- Edge: a stale `## Last error` from a blocked run would be committed into `.scratch/done/` on a later successful ship → D6 clears it at ship start.
- Edge: the ship subagent might report success in prose while not committing — run ignores prose and relies on git + filesystem checks; the `SHIP BLOCKED:` line is only used to enrich the message.
- Risk: existing tests matching ship/run wording (`tests/test-buildit-feature-ship.sh`, `test-buildit-feature-run.sh` AT-7 `(GO|go).*(ship|PASS)`, push/PR manual) — new text does not remove those phrases; re-run full suite.
- Risk: `git cat-file -e` with a path containing the date-prefixed file name — use `<SHIP_REF>:.scratch/done/<file>` (no leading `./`); fine.
- Out of scope: audit #5 (shared-context snapshot), #34 (ship 3b re-reading Worktree path from a moved file), #35 (overlap loop). Do not touch.

## Progress
- 24-11-2026 build (TDD): wrote 20 failing assertions (AT-SV-*) in `tests/test-buildit-feature-run.sh` and `tests/test-buildit-feature-ship.sh` (incl. README drift checks), all failed on content; then implemented.
  - `skills/buildit-feature-ship/SKILL.md`: new `## Running as a subagent` section (blocked signal: no commit, status kept `to-ship`, `## Last error` line `buildit-feature-ship: blocked — <precise reason>`, final message `SHIP BLOCKED: <precise reason>`); step 0 confirmation and step 1 blocking verdict route to it; step 0 removes a stale `## Last error`; End of skill mentions the blocked outcome.
  - `skills/buildit-feature-run/SKILL.md` step 6: "Record the pre-ship state" (`SHIP_REF`, `PRE_SHIP_HEAD`, `TRACKING_FILE`), ship prompt states it runs as a subagent, new "Verify ship before closing the task" block (new commit, `git cat-file -e <SHIP_REF>:.scratch/done/<TRACKING_FILE>`, root tracking file gone) placed before the plan update; on failure the "Unexpected state after ship" message is shown, and nothing is written to the plan, ticket or `Pending:`. The success message now depends on verification passing.
  - `README.md`: run step 4 and ship verdict updated.
  - Build decision B1: the plan's Step 5 said to stage this tracking file; this was not done because the orchestrator rule and the build skill both say never to stage `.scratch/` (ship commits it).
  - Build decision B2: no `shared-context.md` entry. The change reuses the existing `## Last error` convention, and the team-practices wording ("a phase skill") already covers ship.
  - Tests: `bash tests/run-all.sh` → 636 passed, 0 failed (baseline 616).
- 24-11-2026 validate: GO + PASS overall → `to-ship`.
  - Staging guard: clean outside `.scratch/` (only `.scratch/` entries unstaged/untracked, by design).
  - Tests: no `.buildit/config.md` → Tier 2 `bash tests/run-all.sh` → 636 passed, 0 failed. Base branch defaulted to `main` (resolves).
  - Review (staged diff vs merge-base `main`): Correctness GO (pre-ship state recorded before launch; three checks — new commit on branch ref, `git cat-file -e` on committed done path, root tracking file gone — gate plan/ticket/Pending updates; ship's two wait points, step 0 and step 1, both route to the blocked signal; stale `## Last error` cleared at ship start). Performance/Security GO (read-only git checks). Style GO (English, existing `## Last error` convention reused). Craft GO (single blocked-signal rule referenced, no duplication).
  - Non-blocking notes: check 3 (root tracking file no longer outside `done/`) and the "If any check fails" stop are not asserted by a dedicated test; ordering tests use first occurrence of each phrase, which is sufficient today.
  - Acceptance: AT-1 PASS (run step 6 "Verify ship before closing the task" precedes plan update and success message; message "Unexpected state after ship… plan task and external ticket were left unchanged"; no `Pending:`). AT-2 PASS (ship `## Running as a subagent`: no commit, status kept, `## Last error` line, final `SHIP BLOCKED: <reason>`; run prompt tells ship it is a subagent). AT-3 PASS (AT-SV-* assertions in both test files incl. README drift; full suite green).
- 24-11-2026 ship: readiness OK (only `fix/audit` in Merge readiness, no other branch to compare, no APIs/constraints/decisions to migrate); `fix/audit` row removed from `shared-context.md`; full suite 636 passed, 0 failed.
  - Retro: (1) Slowdown — none significant; one build/plan conflict (plan Step 5 said to stage the tracking file, build rules say never stage `.scratch/`), resolved as B1. (2) Configuration — the existing rule already covers it; no config change. (3) Plan — precise (decisions D1–D6 and test regexes defined upfront); the plan template could avoid listing `.scratch/` files in staging steps.
