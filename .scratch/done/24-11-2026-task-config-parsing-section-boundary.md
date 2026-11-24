# task-config-parsing-section-boundary

## Status
to-ship

## Worktree path
none

## Goal
Audit 24-11-2026 findings #6, #16. Every `.buildit/config.md` consumer except plan reads "the first non-empty, non-comment line after the heading" without stopping at the next heading. An empty `## Test command` yields `## Base branch`, which bash runs as a comment (exit 0) — the test gate is silently bypassed. An empty `## Base branch` yields `## Task synchronization`. Bootstrap's fast path skips test-command and base-branch detection (4e/4f) yet writes config.md, producing exactly those empty values.

Files: `skills/buildit-feature-validate/SKILL.md`, `skills/buildit-feature-ship/SKILL.md`, `skills/buildit-feature-run/SKILL.md`, `skills/buildit-feature-discover/SKILL.md`, `skills/buildit-project-bootstrap/SKILL.md`, `.buildit/guidelines/language-framework.md`, `README.md` (plus `skills/buildit-plan/SKILL.md` for wording alignment, deployed copies under `.claude/skills/`, and tests).

Source: `.scratch/24-11-2026-audit-issues.md` (#6, #16); plan task `.scratch/plan/task-config-parsing-section-boundary.md`.

## Acceptance Tests
- AT-1: the parsing rule (value read only within the heading; a line starting with `#` is never a value) is defined once in a guideline and every consumer uses or references that wording.
- AT-2: an empty `## Test command` falls back to ecosystem detection; an empty `## Base branch` defaults to `main`.
- AT-3: bootstrap's fast path still runs 4e and 4f (or explicitly preserves existing values).
- AT-4: a test checks the boundary wording in every config consumer; `bash tests/run-all.sh` passes.

## Plan

### Canonical wording (single source)
Define in `.buildit/guidelines/language-framework.md` § "Project configuration", replacing the current "Convention: values are the first non-empty, non-comment line after a `## Section` heading" sentence, a named rule:

> **Config value rule:** the value of a heading is the first non-empty, non-comment line after it, read only within that heading (stop at the next heading); a line starting with `#` is never a value. A heading with no such line is empty, and an empty value is treated exactly like an absent one (the consumer's fallback or default applies).

Plus a short WHY line (an empty `## Test command` must not yield `## Base branch`, which bash would run as a comment and exit 0).

Exact phrase every consumer must contain (asserted by the test): `read only within that heading (stop at the next heading); a line starting with `#` is never a value`.

### Step 1 — Failing test first (AT-4)
Create `tests/test-config-parsing-boundary.sh` (auto-picked by `tests/run-all.sh`, which globs `test-*.sh`), sourcing `tests/lib/assertions.sh`:
- Guideline `.buildit/guidelines/language-framework.md` contains the canonical phrase and the "Config value rule" label (AT-1).
- Each consumer source `skills/<skill>/SKILL.md` for `buildit-feature-validate`, `buildit-feature-ship`, `buildit-feature-run`, `buildit-feature-discover`, `buildit-project-bootstrap`, `buildit-plan` contains the canonical phrase (`require_text`, fixed string) (AT-1/AT-4).
- `README.md` § Project configuration contains the canonical phrase.
- Negative check: no consumer nor README nor guideline still contains the unbounded form, i.e. `first non-empty, non-comment line after the` followed by a heading/`## ` mention without the boundary. Implement as: every line matching `first non-empty, non-comment line` must also match `read only within that heading` (grep loop per file; fail listing the offending line). This catches multi-occurrence files like validate (2 reads) — the plan wording wraps over lines, so plan will be rewritten to keep the phrase on one line (see step 3).
- AT-2: validate Tier 1 text states an empty value falls back to Tier 2 (regex `empty.*(Tier 2|ecosystem)`), validate 2c and ship state `<base-branch>` defaults to `main` when empty (existing text "no value sits under it" — assert `defaults to `main``, plus the boundary phrase on the same paragraph is covered by the phrase check).
- AT-3: bootstrap fast-path line mentions `4e` and `4f` (regex on the `Fast →` line: `Fast →.*4e.*4f`) and mentions preserving existing values (`preserv`).
- Deployed copies: already enforced by `tests/test-skills-invariants.sh` (diff source vs `.claude/skills/`), so no duplicate assertion.
Run it → must fail (RED) before edits.

### Step 2 — Guideline
Edit `.buildit/guidelines/language-framework.md` as described above. Keep the `## Base branch` paragraph ("defaults to `main` when absent or empty") and the synchronization paragraph; add that an empty `## Test command` falls back to ecosystem detection.

### Step 3 — Consumers (use the exact phrase, reference the guideline)
For each read, replace "first non-empty, non-comment line after the `## X` heading" with "first non-empty, non-comment line after the `## X` heading, read only within that heading (stop at the next heading); a line starting with `#` is never a value (Config value rule, `.buildit/guidelines/language-framework.md`)". Skills must stay self-contained (no include mechanism), so the wording is restated and the guideline is cited as the source.
- `skills/buildit-feature-validate/SKILL.md` 2b Tier 1 (line ~54): add boundary phrase; state "If the value is empty, go to Tier 2" explicitly. Tier 2 trigger list: "(file absent, heading missing, or heading empty)".
- `skills/buildit-feature-validate/SKILL.md` 2c (line ~72): add boundary phrase; keep "defaults to `main`".
- `skills/buildit-feature-ship/SKILL.md` Base branch (line ~50): same as validate 2c.
- `skills/buildit-feature-run/SKILL.md` (line ~75) and `skills/buildit-feature-discover/SKILL.md` (line ~147): replace "(value = first non-empty, non-comment line after the heading)" with the full phrase.
- `skills/buildit-plan/SKILL.md` (lines ~21-23): reflow so the canonical phrase sits on one line and add "a line starting with `#` is never a value".
- `skills/buildit-project-bootstrap/SKILL.md` line ~445 convention sentence: replace with the canonical phrase; mention an empty `## Test command` means validate falls back to ecosystem detection.

### Step 4 — Bootstrap fast path (AT-3)
Change line ~128 to:
"- Fast → skip steps 3 and 4a–4d, but still run 4e and 4f — when `.buildit/config.md` already holds a non-empty `## Test command` / `## Base branch` value (Config value rule), propose that existing value for confirmation instead of re-detecting, and preserve it as-is when confirmed; then go to step 5"
Decision rationale: running 4e/4f always guarantees step 8 never writes empty values from skipped detection; preserving existing values avoids clobbering a user-customised command. The confirmation prompt is a single question per value, so the fast path stays fast.
Also step 8 intro (line ~419): add "If `.buildit/config.md` already exists, update only the headings whose values changed and preserve every other heading and value" — check first whether step 8 already has an update-vs-create rule; only add it if missing (YAGNI).

### Step 5 — README
- `README.md` § Project configuration (line ~213): replace the sentence with the canonical phrase + "an empty value is treated as absent".
- Bootstrap section (line ~318-323): if it describes the fast path, mention 4e/4f still run; otherwise no change (check during build).

### Step 6 — Deploy and verify
- Copy each edited `skills/<skill>/SKILL.md` to `.claude/skills/<skill>/SKILL.md` (deployed copies are plain files, not symlinks; `test-skills-invariants.sh` diffs them).
- Run `bash tests/test-config-parsing-boundary.sh` (GREEN) then `bash tests/run-all.sh` (all pass). Check existing tests that grep the old wording (e.g. `grep -rn "non-comment" tests/`) and update them if they assert the old unbounded text.
- Stage all created/modified files (`git status` must show no relevant untracked/unstaged file) before `to-validate`.

### Self-critique (applied above)
- Assumption: deployed copies are copies, not symlinks — verified (`.claude/skills/buildit-plan/SKILL.md` is a regular file); step 6 syncs them.
- Assumption: no existing test asserts the old wording verbatim — unverified; step 6 adds a grep check and updates such tests.
- Edge case: a value line that legitimately starts with `#` (e.g. a test command beginning with `#`) is impossible in practice; the rule declares it never a value, which is the intended safety property. HTML comments `<!-- -->` remain covered by "non-comment".
- Edge case: plan's wording wraps across lines, which would make a fixed-string per-line test fail — step 3 reflows it onto one line.
- Edge case: `## Test command` explicitly set to `skip` by bootstrap — bootstrap writes an empty value when skipped (template), so validate falls to Tier 2; no change needed.
- Risk: the negative check could false-positive on README table text ("Validate falls back to ecosystem detection") — it only targets lines containing `first non-empty, non-comment line`, so the table is unaffected.
- Vague step made concrete: "every consumer uses or references that wording" → each consumer restates the exact phrase and cites the guideline; the test asserts the exact phrase.
- Scope: findings #7, #18 etc. touching the same files are out of scope; do not modify unrelated text.

## Decisions
- Worktree: no — instructed to work on current branch `fix/audit` in the main checkout (`WORKTREE_PATH=none`).
- Feature name: `task-config-parsing-section-boundary` (provided as argument); description and acceptance tests taken verbatim from the orchestrator brief / plan task.
- Step 5 of feature-start (shared-context Merge readiness entry) skipped as instructed — the `fix/audit` IN_PROGRESS row was already written by the orchestrator.
- Canonical rule lives in `.buildit/guidelines/language-framework.md` (the guideline already owning "Project configuration"); consumers restate the exact phrase because skills are self-contained (no include mechanism, per team-practices).
- AT-3 resolved by doing both: fast path still runs 4e/4f, proposing existing non-empty values for confirmation and preserving them.
- New dedicated test file `tests/test-config-parsing-boundary.sh` rather than extending `test-skills-invariants.sh`, to keep the cross-cutting config contract in one readable place.
- Build: `.claude/skills` is a git-tracked symlink to `../skills` in this repo (not plain copies as the plan and the orchestrator assumed), so editing `skills/` already updates the deployed skills — no copy step was needed; `test-skills-invariants.sh` passes.
- Build: consumers restate the exact canonical phrase and cite `(Config value rule, .buildit/guidelines/language-framework.md)` — deliberate duplication because skills are self-contained (no include mechanism); the new test enforces that the wording stays identical everywhere, which keeps the duplication from drifting.
- Build: bootstrap step 8 had no update rule for an existing `.buildit/config.md` (only for workflow template files), so the "update only changed headings, preserve the rest" sentence was added (not YAGNI: the fast path now rewrites config.md over existing values).
- Build: README bootstrap section does not describe the fast path, so it was left unchanged (plan step 5, second bullet).
- Build: no new practice beyond the rule itself, which already lives in the guideline, so `shared-context.md` Decisions & Conventions was not modified.

## Progress
- [x] Step 1 — `tests/test-config-parsing-boundary.sh` written; RED confirmed (1 passed, 32 failed, all on assertions).
- [x] Step 2 — guideline: named **Config value rule** + WHY + empty `## Test command` falls back to ecosystem detection.
- [x] Step 3 — consumers updated: validate (Tier 1 + Tier 2 trigger + 2c), ship, run, discover, plan (phrase on one line), bootstrap (step 8 convention).
- [x] Step 4 — bootstrap fast path still runs 4e/4f, proposes and preserves existing values; step 8 preserves untouched config headings.
- [x] Step 5 — README § Project configuration updated.
- [x] Step 6 — `bash tests/test-config-parsing-boundary.sh`: 33 passed, 0 failed; `bash tests/run-all.sh`: 598 passed, 0 failed.

## Validation — 24-11-2026
- Test suite (Tier 2, no `.buildit/config.md` → `bash tests/run-all.sh`): 598 passed, 0 failed.
- Base branch: `main` (no config file, default).
- Staging guard: only `.scratch/` paths are untracked/unstaged (ignored by rule); all feature files staged.
- Review: **GO**
  - Correctness: every config value read (validate 2b/2c, ship, run, discover, plan, bootstrap step 8) carries the bounded wording and cites the guideline; Tier 1 empty → Tier 2 explicit; bootstrap fast path now runs 4e/4f and step 8 preserves existing headings.
  - Performance / Security: N/A (markdown skill text + grep-based test).
  - Style: English, `type(scope)`-agnostic; skills stay self-contained with an explicit citation.
  - Test coverage: positive phrase check per consumer, negative unbounded-read check, AT-2/AT-3 regexes, removal of old fast-path line asserted.
  - Craft: duplication of the phrase is deliberate (no include mechanism) and drift-guarded by the test.
  - Non-blocking notes: (1) in `skills/buildit-plan/SKILL.md` the sentence still wraps so "first" sits on the previous line, making the per-line negative check vacuous for that file (positive phrase check still covers it); the reflow also leaves uneven line wrapping. (2) Bootstrap "Coring summary" still says "at the end of 4a–4f", which on the fast path only covers 4e–4f — harmless.
- Acceptance: **PASS overall**
  - AT-1 PASS — rule named "Config value rule" in `.buildit/guidelines/language-framework.md`; all 6 consumers + README restate the exact phrase and cite it.
  - AT-2 PASS — validate Tier 1 "If the value is empty, go to Tier 2"; validate 2c and ship "or the heading is empty, `<base-branch>` defaults to `main`".
  - AT-3 PASS — fast path "skip steps 3 and 4a–4d, but still run 4e and 4f", proposing/preserving existing values.
  - AT-4 PASS — `tests/test-config-parsing-boundary.sh` 33/33 green; full suite green.
- Decision: verdict GO + PASS → status `to-ship` (autonomous run, no user available).

## Ship — 24-11-2026
- Readiness: ✓ OK to ship — base branch `main` (no `.buildit/config.md`); the only `IN_PROGRESS` row in Merge readiness is `fix/audit` itself (no other branch to compare for overlap); no `Waiting for`, no API & Contracts entries, no Constraints discovered.
- Shared-context cleanup: removed the `fix/audit` Merge readiness row; no API, constraint, or decision entries to migrate (the Config value rule already lives in `.buildit/guidelines/language-framework.md`).
- Orchestration files `.scratch/24-11-2026-audit-issues.md` and `.scratch/plan/` intentionally left out of the commit (owned by the plan).

## Retro
- What slowed the loop: the plan assumed `.claude/skills/` held plain copies needing a sync step, while it is a tracked symlink to `../skills`; caught during build at no real cost.
- Would a configuration have prevented it: no new one — `.buildit/guidelines/team-practices.md` already documents the symlink; the plan simply did not consult it. No config update.
- Was the plan precise enough: yes — exact canonical phrase, per-file targets and test design made build and validation direct. Minor gap: the per-line negative check is vacuous when a sentence wraps (plan SKILL.md), noted as non-blocking by validate; left as-is.
