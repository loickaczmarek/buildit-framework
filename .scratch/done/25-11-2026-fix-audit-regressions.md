# fix-audit-regressions

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Fix the 11 findings introduced by branch fix/audit, as listed in the audit report `.scratch/audits/25-11-2026-audit-issues.md` — findings #1, #4, #9, #13, #17, #19, #20, #23, #24, #28, #31 (read each one's Location, Description and Proposed fix in that report). Stay on the current branch fix/audit. Pre-existing findings and incomplete fixes from the first audit are out of scope.

## Acceptance Tests
- AT-1: run's validate-stop message (skills/buildit-feature-run/SKILL.md step 5.5) offers only `/buildit-feature-validate [feature-name]` (no `/buildit-feature-run` re-run); buildit-feature-start stops with a clear message if `.scratch/*-<feature-name>.md` already exists (top level of .scratch/) instead of overwriting it. [#1]
- AT-2: build's unrelated-files stop (step 5.2) restores the entry status (to-build/to-fix) and writes a one-line `## Last error` (`buildit-feature-build: …`); run step 5.3 reports build's `## Last error` the same way step 5.5 does for validate. [#4]
- AT-3: every deliberate ship stop (prerequisite/0a, migration note/0b, base branch not found) writes `## Last error` and, when running as a subagent, ends with the `SHIP BLOCKED:` signal. [#4]
- AT-4: the `## Last error` writer contract test (AT-7 in tests/test-cross-skill-contracts.sh) scans all `skills/buildit-feature-*/SKILL.md` instead of a fixed validate/ship allow-list. [#4]
- AT-5: every `## Last error` writer says to replace any existing `## Last error` section (no stacking); run clears any `## Last error` before launching each phase subagent so a stale one is never reported as new. [#19]
- AT-6: README status lifecycle table and the Last error contract text (team-practices.md and bootstrap's team-practices template) list all writers and clearers (validate, ship, build) and their deliberate stops. [#20]
- AT-7: `.buildit/guidelines/team-practices.md:21` matches ship step 4: only the archived tracking file is copied into the worktree; this feature's shared-context removals are applied to the worktree copy; the root shared-context.md is never copied. Pinned by a test. [#9]
- AT-8: run's plan.md checkbox match is anchored (task name followed by a space), via the same named rule carried verbatim by run and discover and checked by check_named_block. [#13]
- AT-9: `absent_in_text` in tests/lib/assertions.sh fails on empty/whitespace-only input with an explicit message; a SELF test covers it. [#17]
- AT-10: tests/test-buildit-project-bootstrap.sh no longer uses a local awk extractor (uses shared helpers from tests/lib/assertions.sh). [#23]
- AT-11: .github/workflows/tests.yml limits `push` to `main` (or uses a concurrency group with cancel-in-progress) and sets `timeout-minutes`; existing README/CI tests stay green. [#24]
- AT-12: docs/buildit/reviews/2026-10-14-skills-audit.md historical note cites the audit date (or PR/commit) instead of the branch name fix/audit. [#28]
- AT-13: `before`/`before_in`/`same` test helpers live in tests/lib/assertions.sh; local duplicates in tests/test-buildit-feature-run.sh and tests/test-cross-skill-contracts.sh are removed, and the duplicate AT-AB-1 check overlapping AT-6 is removed. [#31]
- AT-14: `bash tests/run-all.sh` passes with 0 failures.

## Plan

Baseline first: run `bash tests/run-all.sh` and record the pass count (audit baseline: 1153 passed, 0 failed). Edit `skills/` only — `.claude/skills` is a tracked symlink to `../skills` (team-practices "dual deployment"). TDD: for each group below, write the failing assertions first, run the targeted test file to see them fail, then edit.

### Group A — test library first (AT-9, AT-13), so later tests use the shared helpers
1. `tests/lib/assertions.sh`:
   - Add `same LABEL ACTUAL EXPECTED` (moved verbatim from test-cross-skill-contracts.sh:22).
   - Add `before_in LABEL TEXT FIRST SECOND` (moved verbatim from test-cross-skill-contracts.sh:25; uses `line_of <(echo "$2")`).
   - Add `before LABEL FILE FIRST SECOND` — file variant (`line_of "$2" …`), replacing the run test's local `before()` which read the global `$SKILL`.
   - `absent_in_text`: if `$text` is empty or whitespace-only (`[[ -z "${text//[[:space:]]/}" ]]`), `fail "$label — section empty or marker missing"` and return; otherwise unchanged.
2. `tests/test-cross-skill-contracts.sh`: delete the local `same()` and `before_in()`; keep `sorted_words` (not in scope). Add SELF tests for `absent_in_text` on `""` and on `"  \n "` — run each call in a subshell that resets counters and captures output, e.g. `out=$(PASS=0 FAIL=0; absent_in_text "x" "" 'foo'; echo "FAIL=$FAIL")`, then assert `FAIL=1` and the message `section empty or marker missing` with `in_text`/`same`. Also a SELF test that non-empty text without the pattern still passes.
3. `tests/test-buildit-feature-run.sh`: delete the local `before()`; rewrite its 3 call sites as `before "<label>" "$SKILL" '<a>' '<b>'`. Delete the AT-AB-1 check (lines ~240-241: `AB_COUNT` + if) — covered by AT-6 "autonomy block body defined once across skills" in the contract test. Keep AT-AB-2/3.
4. Grep every other `tests/*.sh` for local `same()`/`before()`/`before_in()` definitions and remove them if any (none found at planning time besides the two files).
5. Run the full suite: the new `absent_in_text` guard may expose call sites that pass empty text (e.g. AT-R19 in test-readme.sh built with `grep … || true`). Each such failure is a real vacuous assertion: fix the extraction (correct marker) rather than weakening the guard. If a call site legitimately expects empty text, assert emptiness explicitly with `same … ''` instead.

### Group B — `## Last error` contract (AT-2, AT-3, AT-4, AT-5, AT-6)
Uniform writer phrasing (machine-checked by AT-7's grep `` `## Last error` section to the tracking file with the single line `…` ``): "write a `## Last error` section to the tracking file with the single line `<skill>: <reason>`, replacing any existing `## Last error` section". Keep the exact substring `` `## Last error` section to the tracking file with the single line ` `` so the existing extractor still works.

6. **validate** (`skills/buildit-feature-validate/SKILL.md`): status guard (:50) and base-branch stop (:93) — change "add a `## Last error` section…" to the uniform phrasing including "replacing any existing `## Last error` section".
7. **ship** (`skills/buildit-feature-ship/SKILL.md`):
   - "Running as a subagent" bullet: uniform phrasing with replace.
   - Add one general rule near "Running as a subagent" (e.g. a **Deliberate stops** paragraph): every deliberate stop after a tracking file is selected (0a prerequisite, 0b migration note, step 1 base branch not found) writes the `## Last error` line (uniform phrasing) and, as a subagent, ends with a final message starting with `SHIP BLOCKED: <reason>`. Keep the status `to-ship`, commit nothing.
   - At each of 0a, 0b, step 1 base-branch stop: add the explicit single line, e.g. `buildit-feature-ship: shared-context.md not found`, `buildit-feature-ship: guidelines found at <old-path>, migration required`, `buildit-feature-ship: base branch <base-branch> not found locally`, each with the uniform phrasing, plus "as a subagent, end with `SHIP BLOCKED: <same reason>`". Note: ship step 0 clears a stale Last error before 0a/0b run, so the order "clear then write" holds.
   - Note the existing discovery-stop exception (no tracking file → no Last error) stays as is; the AT-7 test pinning it must stay green.
8. **build** (`skills/buildit-feature-build/SKILL.md`):
   - Step 1: remember the entry status (`to-build` or `to-fix`, or whatever was confirmed) before setting `building`; when setting `building`, "If the tracking file has a `## Last error` section, remove it (it describes a previous run)." — same CLEAR sentence as validate/ship so the test can share the constant.
   - Step 5.2 unrelated-files stop: "restore the entry status recorded in step 1 (`to-build` or `to-fix`), write a `## Last error` section to the tracking file with the single line `buildit-feature-build: unrelated files block validation — <paths>`, replacing any existing `## Last error` section, and stop with: …". Keep the message ("re-run `/buildit-feature-build [feature-name]`") — restored status means the re-run passes the status check; in fix mode Problems to fix is still present, so fix mode is detected again.
9. **run** (`skills/buildit-feature-run/SKILL.md`):
   - Step 5.5 message: "buildit-feature-validate stopped: [Last error line]. Fix it, then run `/buildit-feature-validate [feature-name]`." — drop the `/buildit-feature-run` re-run (#1).
   - Step 5.3: if status unchanged from before the subagent ran: if the tracking file has a `## Last error` section, build stopped deliberately — stop and report: "buildit-feature-build stopped: [Last error line]. Fix it, then run `/buildit-feature-build [feature-name]`."; otherwise keep the existing "possible subagent failure" message. Mirror 5.5's wording ("If the tracking file has a `## Last error` section, build stopped deliberately — stop and report its content").
   - Clear before each phase: add one rule (e.g. in step 5 intro or a named sentence reused at 5.2, 5.4 and step 6): "Before launching the subagent, if the tracking file has a `## Last error` section, remove it — a stale line must never be reported as this phase's result." Apply before build (5.2), validate (5.4) and ship (step 6, before recording pre-ship state or right before launch). Start (step 3) has no tracking file yet — nothing to clear.
   - Step 6 verify message already quotes ship's Last error — unchanged.
10. **Docs** (AT-6):
    - `README.md` lifecycle table (:139-150): add rows — build deliberate stop (unrelated files) `building` → entry status (`to-build`/`to-fix`), reason in `## Last error`; validate status-guard stop (status unchanged, reason in `## Last error`); ship deliberate stops / block (status stays `to-ship`, reason in `## Last error`, `SHIP BLOCKED:` as subagent). Update the `## Last error` template comment (:135-136) to mention replace and clearers.
    - `.buildit/guidelines/team-practices.md:167` and bootstrap template line (`skills/buildit-project-bootstrap/SKILL.md:388`): one sentence listing writers (build: unrelated-files stop; validate: status guard, base branch not found; ship: prerequisite, migration note, base branch not found, subagent block), "each writer replaces any existing section", clearers (build step 1, validate step 1, ship step 0, and run before launching each phase), reporter (run). Keep the bootstrap template line on one line (template is a fenced block; check existing bootstrap tests that pin it).
    - Check `docs/buildit/specs/2026-11-24-buildit-feature-run-design.md:33` table: add `## Last error` handling to the build row for consistency (spec, cheap).
11. **Tests** (`tests/test-cross-skill-contracts.sh` AT-7 Last error block):
    - Replace `for f in "$VALIDATE" "$SHIP"` with a loop over `"$S"/buildit-feature-*/SKILL.md`; for each file collect writer lines; require writers for build, validate, ship (assert the set of skills with writers ⊇ {build, validate, ship}); every writer line starts with `<skill>: `; every occurrence of `section to the tracking file with the single line` in a file is followed (same line, normalised) by `replacing any existing \`## Last error\` section` — count writers vs replace mentions per file (equal).
    - Pin: build step 5 restores the entry status and writes `buildit-feature-build: unrelated files block validation — <paths>`; build step 1 clears; run 5.3 reports build's Last error; run 5.5 message has no `/buildit-feature-run`; run clears before build, validate and ship launches (count ≥3 or one rule referenced at each launch, assert order: clear before each `**Subagent: …**`/launch line); ship 0a, 0b, step 1 base-branch stops each carry a writer line and `SHIP BLOCKED`.
    - Template/guideline: team-practices Last error line and bootstrap template line mention build, validate, ship and run, and "replac".
    - README lifecycle table rows for build stop, validate status guard, ship block.
    - Update existing tests broken by the wording changes (test-buildit-feature-run.sh AT-SC-5; test-readme.sh; test-buildit-feature-build.sh, -ship, -validate) — adjust pins to the new sentences, never delete coverage.

### Group C — start existence guard (AT-1)
12. `skills/buildit-feature-start/SKILL.md`: at the end of step 2 (after the name is collected, before step 2b so no worktree/branch is created), add: "**Existing tracking file:** if the top level of `.scratch/` already holds a file named `DD-MM-YYYY-<feature-name>.md` (any date, exact slug — never `.scratch/done/`, never a substring match), stop with: 'A tracking file for `<feature-name>` already exists: `.scratch/<file>` (status `<status>`). Resume it with the phase its status calls for (`/buildit-feature-build`, `/buildit-feature-validate` or `/buildit-feature-ship`), or choose another feature name.' Nothing is created or modified." Use the exact-date pattern, not `*-<name>.md`, because `*-context.md` would match `shared-context.md`.
    Test in `tests/test-buildit-feature-start.sh`: guard text present in step 2 section, precedes `### 2b.`, mentions "already exists" and "never overwrite"/stop.
    Also check `skills/buildit-feature-run/SKILL.md:132-143` / end-of-skill text and `skills/buildit-worktree/SKILL.md:64` for any other "re-run `/buildit-feature-run`" recommendation after a mid-cycle stop; replace with the phase command if present (grep `re-run \`/buildit-feature-run`).

### Group D — plan line match rule (AT-8)
13. Add a named block **Plan line match rule** (bold heading + contiguous list, no blank line inside), carried verbatim by run and discover:
    ~~~
    **Plan line match rule**
    - The task's line in `.scratch/plan/plan.md` starts with `- [ ] task-{feature-name} ` or `- [x] task-{feature-name} ` — the task name followed by a space.
    - Never match on a prefix without the trailing space: `task-auth` must not match `task-auth-oauth`.
    - Preserve the rest of the line (priority and readiness tags).
    ~~~
    - run step 6 "Update plan task on completion": "Find the task line with the Plan line match rule and change `- [ ]` to `- [x]`", replacing the unanchored sentence; place the block right there (or in step 0 next to **Plan task lookup rule**).
    - discover: replace the parenthetical at :148 with a reference to the block, and include the block once.
    - `tests/test-cross-skill-contracts.sh`: `check_named_block '**Plan line match rule**' "$RUN" "$RUN" "$S/buildit-feature-discover/SKILL.md"`. Add an assertion in run's test that the unanchored `` `- [ ] task-{feature-name}` and change it `` sentence is gone.
    - Check existing tests pinning the old run sentence (`test-buildit-feature-run.sh`, `test-buildit-feature-discover.sh`) and update them.

### Group E — guideline line 21 (AT-7)
14. `.buildit/guidelines/team-practices.md:21`: rewrite the ship sentence: "At ship, only the archived tracking file is copied from the project root into the worktree; this feature's shared-context removals are applied to the worktree's own `shared-context.md`, and the root `shared-context.md` is never copied (it holds other features' uncommitted rows). Guideline migrations are made in the worktree, so all land in the feature commit; the root copy of the archived tracking file is then removed so it does not block the merge."
    Test (contract test, guideline-vs-skill section): the team-practices Worktree management section contains "only the archived tracking file is copied" and "never copied"; does not contain "copied or made"; and ship step 4 still contains "copy only `.scratch/done/" and "never replace it with the root file". Check README.md:574 and `docs/buildit/specs/2026-11-24-worktree-mode-design.md:32` say the same; fix if they also claim shared-context is copied.

### Group F — bootstrap test awk (AT-10)
15. `tests/test-buildit-project-bootstrap.sh:96`: replace the awk counting `- ` lines after `Mandatory evaluation dimensions:` with shared helpers: write `$TP_TPL` to a temp file (or use process substitution) and use `section_body <file> 'Mandatory evaluation dimensions:'` (non-heading START → ends at next heading, so also cut at the first non-list line: pipe through `sed '/^- /!q'`-style is a local extractor too — prefer `grep -c '^- '` on `section_body` with END = the line that follows the list in the template; read the template to pick a stable END marker). Grep the file for any other local `awk`/`sed` extractors and replace them the same way.

### Group G — CI (AT-11)
16. `.github/workflows/tests.yml`: `push: branches: [main]`, keep `pull_request:`, add `concurrency: { group: tests-${{ github.ref }}, cancel-in-progress: true }` and `timeout-minutes: 10` on the job. Tests in `tests/test-readme.sh` near AT-R22: assert `timeout-minutes:` present and `branches: [main]` (or concurrency) present; AT-R22 push/pull_request regexes still match.

### Group H — historical note (AT-12)
17. `docs/buildit/reviews/2026-10-14-skills-audit.md:3`: "this review predates the fixes from the 24-11-2026 audit (commits `141d0ba..fa5ec12`)" — no branch name. Test: `require_absent` of `fix/audit` in that file and `require_text '24-11-2026 audit'` (in test-readme.sh or the contract test, wherever doc tests live — check for an existing test referencing this file first).

### Wrap-up
18. `bash tests/run-all.sh` → 0 failures (AT-14). Re-verify `diff -q` sanity is moot (symlink).
19. Stage every modified file by explicit path (skills/*/SKILL.md, tests/*.sh, tests/lib/assertions.sh, README.md, .buildit/guidelines/team-practices.md, .github/workflows/tests.yml, docs/...), check `git status --porcelain` ignoring `.scratch/`, then set `to-validate`.

### Self-critique (corrections integrated above)
- **Assumption — AT-7 extractor phrasing:** the writer regex requires the exact substring "`## Last error` section to the tracking file with the single line `…`". Rewording writers to "replace" could break extraction; the plan keeps that substring and appends ", replacing any existing `## Last error` section".
- **Assumption — ship 0a/0b have a tracking file:** true, step 0 runs discovery first. But step 0 also clears a stale Last error before 0a/0b — so writing after clearing is correct. The discovery-stop exception (no file selected) must stay.
- **Edge case — build entry status:** build can be confirmed to continue from an unexpected status (e.g. `building` after a crash). "Restore the entry status" must mean the status read in step 1, whatever it was — plan says "entry status recorded in step 1", not hard-coded to-build/to-fix.
- **Edge case — run 5.3 status comparison:** with build restoring its entry status, run sees "status unchanged" — the Last error branch must sit inside the unchanged-status branch (like 5.5), before the generic failure message.
- **Edge case — run clearing before ship:** ship step 6 verification quotes ship's Last error; clearing must happen before the ship launch, never after it.
- **Edge case — start guard glob:** `.scratch/*-<name>.md` would match `shared-context.md` for name `context`; use the exact `DD-MM-YYYY-<feature-name>.md` pattern at top level only (consistent with the discovery rule's exact-slug semantics). Do not consider `.scratch/done/` (a shipped feature may be legitimately restarted? — no: same name could re-run after ship; top level only is what AT-1 asks).
- **Risk — absent_in_text guard surfaces vacuous call sites:** expected; fix each by correcting the extraction, never by relaxing the guard. Budget time for it.
- **Risk — many existing tests pin old sentences** (run 5.5 message, build 5.2 message, validate "add a `## Last error`", discover plan-line parenthetical, README table, team-practices :21/:167, bootstrap :388). Run the full suite after each group, update pins to new wording, keep coverage.
- **Vague step — bootstrap awk replacement:** the END marker must be read from the template before choosing; if `section_body` cannot bound a non-heading list cleanly, add a small generic fence-aware helper to `tests/lib/assertions.sh` (e.g. `list_after FILE MARKER`) rather than an inline awk — the guideline forbids local extractors, not new shared helpers.
- **Scope guard:** #31's "select sections by stable title fragments" (step-number coupling) is not in AT-13; do not refactor section selection. Pre-existing findings (#2, #3, #5…) out of scope.
- **Process:** `.claude/skills` is a symlink — never `cp` into it.

## Progress

### Build — 25-11-2026
- Baseline 1153 passed / 0 failed → 1229 passed / 0 failed after the build.
- Groups A–H implemented as planned. Deviations: run's stale-Last-error clear is defined once in "Subagent selection and workflow isolation" and referenced at 5.2, 5.4 and 6 (DRY) instead of repeated; ship 0a keeps the shared prerequisite sentence verbatim (AT-6 named check) and writes Last error in a following "Before stopping" sentence; team-practices "Section-scoped assertions" now lists `same`/`before`/`before_in` and the empty-section guard.
- `absent_in_text` guard exposed no vacuous call site.
- Known limit (out of scope): if start stops on an existing tracking file inside feature-run, run step 4 finds that existing file and continues with it.


### Ship — 25-11-2026
- Readiness: OK to ship — no other IN_PROGRESS branch, no pending API or constraint entries.
- Shared-context: only this feature's uncommitted Merge readiness row was present; removed, nothing to stage.
- Validate nit fixed: historical note range `141d0ba..fa5ec12` → `141d0ba^..fa5ec12` (the two-dot range excluded 141d0ba); AT-R24 pin updated. Suite: 1229 passed / 0 failed.

## Retro
- Slowdown: many existing tests pinned exact sentences, so each wording change rippled into several test files.
- Config gap: none new — section-scoped helpers (`same`/`before`/`before_in`, empty-section guard) are already recorded in team-practices by this build.
- Plan precision: precise enough; the only deviation (single stale-Last-error clear rule in run) was a DRY improvement.
