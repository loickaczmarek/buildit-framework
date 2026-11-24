# docs-and-hygiene

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 (`.scratch/24-11-2026-audit-issues.md`) findings #23, #24, #27, #28, #29, #30, #32, #34 (remaining parts), plus #31 and #33 if still open. README has drifted from the skills (Problems-to-fix clearing, READY status, autonomy claim, bootstrap 4f, run step 2, validate revert); `READY` and `Waiting for` are never written; `team-practices.md` lines on testing/assertion helpers/tracking sections are stale; `scripts/test_docs.sh` is dead; there is no CI; design specs for feature-run, worktree mode and subagent isolation are missing; stale `/feature-*` names and French tokens in tests remain.

IMPORTANT: 12 earlier tasks already shipped on `fix/audit` and edited README and skills — re-check every drift point against the CURRENT skills, not the audit's original wording; some may already be fixed.

Leftovers passed on by earlier tasks (verify each, fix what is in scope):
- README worktree section `Working directory` paragraph (~README.md:597) should say tests run in the worktree.
- README validate NO-GO step should say validate's 5a stages its own config edits.
- README autonomy block (~README.md:160-175) must match run's single named "Subagent autonomy block".
- README discover "Ends with" line uses a generic `[feature-name]` placeholder for the non-plan case; plan/discover now print bare names.
- `docs/buildit/reviews/2026-10-14-skills-audit.md` is historical: do not rewrite; at most add a short note at the top that it predates later changes.
- Repo `.claude/CLAUDE.md` "Agent workflow" line says "stage every file"; build now stages by explicit path and never `.scratch/`. Align the wording.
- Bootstrap settings template lacks `Bash(bash *)` → worktree-mode `cd <worktree> && bash tests/...` prompts. At most document it; never change a real settings file (`.claude/settings.json` / `settings.local.json` are off-limits).
- `team-practices.md` now has "Section-scoped assertions" and "Cross-skill contracts" conventions; README/docs describing the test layout should mention `tests/test-cross-skill-contracts.sh` and `tests/lib/assertions.sh`.
- Optional, only if trivial: `buildit-plan` carries the Operating mode rule block without using it; if removed, update the required-files list in `tests/test-cross-skill-contracts.sh`. Otherwise leave it.
- CI: create a local `.github/workflows/` file; never push.

Contracts enforced by tests that must stay intact: named blocks identical across files (Config value rule, Tracking-file discovery rule, Operating mode rule, Plan task lookup rule); run's Subagent autonomy block defined once; `## Branch` and `## Last error`; run step 6 ship verification; ship's step order and `SHIP BLOCKED`; README headings unique (tests/test-readme.sh AT-R9) — edit README sections in place, never add a duplicate heading. `.claude/skills` is a tracked symlink to `../skills`. Skill files stay in English.

## Acceptance Tests
- AT-1: every README drift point listed in the audit (and the leftovers above) matches the current skills; `tests/test-readme.sh` asserts them.
- AT-2: `READY` / `Waiting for` are either written by a skill or removed from bootstrap, README and ship.
- AT-3: team-practices lines on testing, assertion helpers (incl. `require_absent`, `tests/lib/assertions.sh`) and tracking sections (incl. `Worktree path`, `Branch`) are up to date.
- AT-4: `scripts/test_docs.sh` is deleted (useful checks migrated); a minimal CI workflow under `.github/workflows/` runs `bash tests/run-all.sh` on push and PR.
- AT-5: design specs exist for feature-run, worktree mode and subagent isolation under `docs/buildit/specs/`.
- AT-6: stale `/feature-*` names and French test tokens are gone. The leftover merged worktree `.worktrees/feature/2026-10-14-fix-critical-audit-issues` (branch `feature/2026-10-14-fix-critical-audit-issues`) is NOT removed in this task: removal is DEFERRED to the user (requires their confirmation). Do not remove any worktree or branch.
- AT-7: `bash tests/run-all.sh` passes.

## Plan

### Start-time decisions (subagent run, no human available)
- Worktree: **no** (caller instruction) — work directly on `fix/audit`; no branch switch, no push.
- Finding #32 (leftover merged worktree): **deferred to the user** — `git worktree remove .worktrees/feature/2026-10-14-fix-critical-audit-issues` + `git branch -d feature/2026-10-14-fix-critical-audit-issues` require their confirmation. Nothing removed here.
- AT-2 direction: **remove** `READY` / `Waiting for` (no skill writes them; implementing a dependency protocol is out of scope for a hygiene task). Merge readiness keeps `IN_PROGRESS` rows only, removed by ship.

### Pre-check findings at start (state of `fix/audit` @ b6e0d5d)
- #31 looks already fixed: a single string `Bash(cd */.worktrees/*)` in run, README and bootstrap. Build only re-confirms with a grep and an assertion (no `&& *)` variant).
- #33 looks already fixed: no `v2` wording in bootstrap or README. Build re-confirms with grep (closing message points to `/buildit-feature-run`?) and adds an absence assertion only if cheap.
- #34: `skills/buildit-feature-start/SKILL.md:32` still says `/feature-start feature-name`; `tests/test-buildit-feature-run.sh:32` regex still contains `défaut`. Others (`/feature-ship`, `/feature-build`) already gone — re-grep whole repo (skills, tests, README, .buildit, docs/buildit/specs) excluding historical `docs/buildit/reviews/`.
- #24: `Waiting for` still in `skills/buildit-feature-ship/SKILL.md:85` (dependency check) and bootstrap template `:447` (table header); `READY` in `README.md:150`.
- `.buildit/guidelines/` holds team-practices.md, craft-principles.md, language-framework.md.

### Steps (TDD: write failing assertions first, then edit docs/skills)

1. **Failing tests first**
   - `tests/test-readme.sh`: add assertions (section-scoped via `tests/lib/assertions.sh` helpers `section`, `in_text`, `require_absent`, per "Section-scoped assertions" convention) for each README drift point verified in step 2 below; `require_absent` for `READY` and `Waiting for` in README.
   - `tests/test-buildit-feature-ship.sh` / `tests/test-buildit-project-bootstrap.sh`: `require_absent` for `Waiting for` / `READY` (ship dependency check gone; bootstrap Merge readiness header is `| Branch | Status | Main files touched |`). Update any existing assertion that locks the 4-column header or the dependency check — grep tests for `Waiting for` first.
   - Skills invariants or a new small test (prefer extending an existing file, e.g. `tests/test-skills-invariants.sh`): no `/feature-(start|build|validate|ship|run|discover)\b` without `buildit-` prefix in `skills/`, `README.md`, `.buildit/`; no French tokens (`défaut`) in `tests/`.
   - Hygiene assertions (place in `tests/test-readme.sh` or `tests/test-skills-invariants.sh`): `scripts/test_docs.sh` absent; `.github/workflows/*.yml` exists and contains `bash tests/run-all.sh`, `push` and `pull_request`; specs for feature-run, worktree mode, subagent isolation exist under `docs/buildit/specs/` (match by filename glob, e.g. `*feature-run*`, `*worktree*`, `*subagent-isolation*`).
   - team-practices assertions (AT-3): mentions `tests/lib/assertions.sh`, `require_absent`, `Worktree path`, `Branch` in the tracking-sections line; absence of "No automated test framework".
   - Run `bash tests/run-all.sh` → the new assertions fail (red), nothing else regresses.

2. **README drift audit (AT-1)** — for each point, read the CURRENT skill text first, then align README in place (no new `##`/`###` heading that duplicates an existing one — AT-R9):
   a. "Problems to fix" clearing timing (README `## Problems to fix` ~:125, build fix mode ~:483) vs `skills/buildit-feature-build/SKILL.md`.
   b. `READY` in Merge readiness description (~:150) → remove (per AT-2 decision).
   c. Autonomy (~:160-175) vs run's "Subagent autonomy block" — content (incl. worktree paragraph, `Bash(bash *)` note) must match verbatim or be a faithful paraphrase; the claim about which prompts carry it must match run.
   d. Bootstrap steps list (~:320-330) vs bootstrap skill steps — step 4f (base branch from `origin/HEAD`) present.
   e. Run steps list vs `skills/buildit-feature-run/SKILL.md` step 2 (and step 6 ship verification).
   f. Ship steps (~:560-573): worktree removal present/absent per current ship.
   g. Status table: validate's revert (validating → to-validate on abort? check validate) present.
   h. Validate NO-GO step (~:530): add that 5a stages its own config edits (check validate 5a wording).
   i. Worktree `Working directory` paragraph (~:597): add that test commands run with the worktree as working directory.
   j. Discover "Ends with" (~:398): replace `[feature-name]` placeholders with bare-name wording consistent with discover's actual end message.
   k. Test layout description in README (if any section describes tests): mention `tests/run-all.sh`, `tests/lib/assertions.sh`, `tests/test-cross-skill-contracts.sh`, the CI workflow. If no such section exists, extend an existing one (e.g. contributing/tests) instead of adding a duplicate heading.
   l. Document the `Bash(bash *)` gap: bootstrap template note already mentions it; ensure README's worktree/permissions section states that worktree mode needs a rule for the chained test command. Do NOT edit `.claude/settings*.json`.
   Each confirmed point gets an assertion in `tests/test-readme.sh` pairing README wording with the skill wording where practical.

3. **AT-2 removal** — ship: remove the `Waiting for` dependency check (renumber/adjust surrounding text without breaking ship's step order assertions and `SHIP BLOCKED`); bootstrap: drop `Waiting for` column from the shared-context template; start step 5 row `| [## Branch value] | IN_PROGRESS | — | — |` → 3 columns; check run, build, any other writer of the row (grep `IN_PROGRESS`) and this repo's `.scratch/shared-context.md` table header (live file, untracked? — check `git ls-files`; edit only if needed for consistency, it is coordination state). Check `test-cross-skill-contracts.sh` for row-format assertions and update consistently.

4. **AT-3 team-practices** — update the stale lines (testing: content-assertion suite under `tests/` run by `tests/run-all.sh` + CI; assertion helpers incl. `require_absent`, located in `tests/lib/assertions.sh`; tracking sections incl. `Branch`, `Worktree path`, `Problems to fix`, `Last error` if applicable — verify against start/build/run). Also check the bootstrap team-practices template's tracking-sections list for the same drift (fix if in passing).

5. **AT-4** — inspect `scripts/test_docs.sh` checks; migrate any still-valid check not already covered by `tests/test-readme.sh` (e.g. Quick start before Manual flow); `git rm scripts/test_docs.sh`. Grep for references (`test_docs`) in README, hooks, install script. Create `.github/workflows/tests.yml`: `on: [push, pull_request]`, `ubuntu-latest`, `actions/checkout@v4`, `run: bash tests/run-all.sh`. Verify checkout version via Context7 if available. Check whether tests depend on anything not on a stock runner (python3, rg?) — grep `tests/` for external commands.

6. **AT-5 specs** — write three concise specs under `docs/buildit/specs/` with date prefix `2026-11-24-`: `buildit-feature-run-design.md` (orchestration loop, phases, max-cycles, Last error, step 6 ship verification, plan task sync), `worktree-mode-design.md` (`## Branch`/`## Worktree path`, .scratch stays in root, git -C, tests run in worktree, ship shared-context handling, permissions incl. `Bash(bash *)`), `subagent-isolation-design.md` (fresh subagent per phase, tracking file as the only hand-off, autonomy block, no human → record decisions, `SHIP BLOCKED`). Follow existing spec format (look at `2026-11-24-plan-task-synchronization.md`) and `language-framework.md` design spec rules. Describe current behaviour; reference skills rather than duplicating long text.

7. **AT-6** — fix `/feature-start` in start:32 → `/buildit-feature-start`; replace `(default|défaut)` with `default` in `tests/test-buildit-feature-run.sh`; grep remaining French tokens in `tests/` (`é`, `è`, `à`, common words) and fix. Leave worktree/branch in place.

8. **Leftovers**
   - `docs/buildit/reviews/2026-10-14-skills-audit.md`: add a one-line note at top ("Historical — predates the 24-11-2026 audit fixes; see current skills."). No other edits.
   - `.claude/CLAUDE.md` Agent workflow line: align with build's staging contract (stage by explicit path, never `.scratch/`, check `git status --porcelain`). Read build step 5 wording first. Check the bootstrap rules-file template for the same line and keep them consistent.
   - `buildit-plan` Operating mode block: leave unless removal is trivial and its test list update is one line; default = leave (record decision in Progress).

9. **Verify** — `bash tests/run-all.sh` all green; `git status`; stage every created/modified/deleted file by explicit path (never `.scratch/` — tracking files are not staged per build's contract; check build skill); set status `to-validate`.

### Self-critique (applied)
- *Assumption: README line numbers from the audit are valid* — false, 12 tasks edited README; plan uses section names and requires reading current skill text before each edit.
- *Assumption: #31/#33 still open* — pre-check shows both fixed; scope reduced to confirmation + absence assertion, avoiding churn.
- *Risk: removing `Waiting for` breaks existing tests or contracts* (ship step order, start row format, cross-skill contract tests) — step 3 requires grepping tests for `Waiting for`/`IN_PROGRESS` row format and updating them in the same change; ship's step numbering must keep "step order" assertions valid.
- *Risk: duplicate README headings (AT-R9)* — any test-layout/CI documentation goes into an existing section.
- *Risk: CI fails on runner because tests rely on local tools* — step 5 checks external commands used by tests; `.claude/skills` symlink is tracked so checkout preserves it.
- *Edge: `/feature-*` absence test could match legitimate `buildit-feature-*`* — regex must require a non-`buildit-` prefix (e.g. `(^|[^-a-z])/feature-`).
- *Edge: French-token assertion could flag legitimate accented content* — restrict to `tests/*.sh` and to specific tokens found, not all non-ASCII.
- *Edge: absence assertions on `READY` could match `already`/other words* — use word-boundary, case-sensitive `\bREADY\b`.
- *Vague step risk: "match the autonomy block"* — define as: README quotes run's block content; assertion compares a distinctive sentence from the block in both files.
- *Out of scope guard*: no settings file edits, no worktree/branch removal, no push, historical review file untouched beyond the note.

## Progress
- 24-11-2026: start — tracking file created; worktree: no (caller instruction, branch `fix/audit`); #32 worktree removal deferred to user; AT-2 direction = remove `READY`/`Waiting for`.
- 24-11-2026: build (TDD) — red: 36 new assertions failing (test-readme AT-R12..R24, cross-skill AT-8 Merge readiness row, skills-invariants #29/#31/#33/#34); green: `bash tests/run-all.sh` 1153 passed, 0 failed.
  - AT-1: README aligned in place (tracking structure gains `## Branch`/`## Last error`, Problems-to-fix cleared by build at `to-validate`, status table row for validate's deliberate stop, Merge readiness wording, autonomy block now identical to run's block (asserted by normalized comparison), bootstrap 4f, run step 2, validate 5a staging, worktree tests-in-worktree + `Bash(bash *)` gap, discover `{name}`, Running tests mentions cross-skill contracts/extractors/CI, References lists the 3 new specs). Ship's worktree removal and run step 6 verification were already documented.
  - AT-2: removed `READY`/`Waiting for` — ship's "Declared dependencies" check, bootstrap template header (now `| Branch | Status | Main files touched |`), start row (3 columns), README; live `.scratch/shared-context.md` header aligned (not staged — ship owns it).
  - AT-3: team-practices Testing section rewritten (content assertions, run-all, pre-push hook, CI); helper list includes `require_absent`; tracking-sections line already listed Branch/Worktree path.
  - AT-4: `scripts/test_docs.sh` deleted (`git rm`); still-valid checks migrated to test-readme AT-R24 (title, `--max-cycles 3` default; Autonomy section covered by AT-R14). `.github/workflows/tests.yml` added (push + pull_request, `actions/checkout@v7` — current major per Context7, `permissions: contents: read`). Tests need only bash/awk/sed/python3 (present on ubuntu-latest). Not pushed.
  - AT-5: specs `docs/buildit/specs/2026-11-24-{buildit-feature-run,worktree-mode,subagent-isolation}-design.md`.
  - AT-6: start `/feature-start` → `/buildit-feature-start`; run test regex French token removed; assertions forbid unprefixed `/feature-*` and accented letters in tests (byte-escaped pattern so the test never matches itself). #34 remainder: run's status guard now asks before re-running a `done` plan task (stops as a subagent); ship 3b re-read was already fixed (WORKTREE_PATH stored at step 0). #31/#33 confirmed fixed; absence assertions added.
  - Decision (subagent, no human): leftover worktree `.worktrees/feature/2026-10-14-fix-critical-audit-issues` and its branch NOT removed — DEFERRED to the user (`git worktree remove .worktrees/feature/2026-10-14-fix-critical-audit-issues && git branch -d feature/2026-10-14-fix-critical-audit-issues`).
  - Decision (subagent, no human): repo `.claude/CLAUDE.md` "Agent workflow" staging line NOT edited — an agent instruction cannot authorize CLAUDE.md changes. DEFERRED to the user; suggested wording = bootstrap rules template line: "Before setting status to to-validate, stage every file created or modified during the build (outside .scratch/) by explicit path and confirm with git status --porcelain that no relevant untracked or unstaged file remains — the validate staging guard returns NO-GO otherwise".
  - Decision: `buildit-plan` Operating mode block left in place (optional item; removal not needed for any AT).
  - Historical review `docs/buildit/reviews/2026-10-14-skills-audit.md`: only a note added at the top.
  - No new practice → shared-context "Decisions & Conventions" unchanged.
- 24-11-2026: validate — GO + PASS. Staging guard clean (only `.scratch/` entries unstaged/untracked). Tests: `bash tests/run-all.sh` 1153 passed, 0 failed (Tier 2 detection; no `.buildit/config.md`, base branch defaults to `main`). Review GO on 6 dimensions. Acceptance: AT-1..AT-7 PASS (AT-6 worktree/branch removal deferred to the user by scope decision; `.claude/CLAUDE.md` wording change deferred to the user, not an AT). Non-blocking notes: `actions/checkout@v7` major taken from build's Context7 check — confirm on first CI run; bootstrap settings template still lacks `Bash(bash *)` (documented in README, by design).
- 24-11-2026: ship — readiness OK (only Merge readiness row was this feature's own `fix/audit`; no API/constraint entries; no other IN_PROGRESS branch). Shared-context: removed the `fix/audit` row; staged file = header aligned to 3 columns (AT-2, this feature's change) with no other feature's rows. No constraint/decision to migrate. `bash tests/run-all.sh` 1153 passed, 0 failed before commit.

## Retro
- What slowed the loop: the audit's line numbers and wording were stale after 12 earlier tasks on the same branch, so every drift point had to be re-checked against the current skills; and two items (repo `.claude/CLAUDE.md` wording, leftover worktree removal) could not be done by a subagent and had to be deferred.
- Would a configuration have prevented it: partly — the task brief already said "re-check against the current skills"; no new guideline needed. The `Bash(bash *)` permission gap for worktree-mode test commands remains documented, not configured (settings files are off-limits).
- Was the plan precise enough: yes — per-point steps with pre-checks (#31/#33 already fixed) avoided churn; the AT-2 direction decided at start removed ambiguity.
- Deferred to the user (needs confirmation):
  1. `git worktree remove .worktrees/feature/2026-10-14-fix-critical-audit-issues && git branch -d feature/2026-10-14-fix-critical-audit-issues`
  2. Align repo `.claude/CLAUDE.md` "Agent workflow" staging line with the bootstrap rules template (stage by explicit path outside `.scratch/`, confirm with `git status --porcelain`).
  3. Confirm `actions/checkout@v7` on the first CI run.
