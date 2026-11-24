# task-tracking-file-discovery

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 finding #9. Without a feature name, build/validate/ship pick "the most recent `.md` outside `done/`", which can be `shared-context.md` or the audit report (same `DD-MM-YYYY-*.md` pattern). Validate has no status guard. The named lookup `*name*` is a substring glob (`context` matches `shared-context.md`). Files: `skills/buildit-feature-build/SKILL.md`, `skills/buildit-feature-validate/SKILL.md`, `skills/buildit-feature-ship/SKILL.md`, `skills/buildit-feature-run/SKILL.md`, `skills/buildit-project-audit/SKILL.md`. Note: in worktree mode, ship step 4 writes into the worktree's own `.scratch/` (a stated exception to the rule that `.scratch/` lives in the project root) — the discovery rule must stay consistent with that.

## Acceptance Tests
- AT-1: one discovery rule is stated (candidates must contain a `## Status` heading with a feature status; named lookup matches the exact `DD-MM-YYYY-<name>.md` suffix; multiple matches → ask).
- AT-2: `shared-context.md`, audit reports and `plan/` can never be selected.
- AT-3: the audit writes its report under `.scratch/audits/`.
- AT-4: validate stops (or asks) when the selected file's status is not `to-validate`.
- AT-5: tests assert AT-1 to AT-4; `bash tests/run-all.sh` passes.

## Plan

### Discovery rule (single canonical text)
One block, headed `**Tracking file discovery rule**`, copied verbatim into build, validate, ship and run (skills are deployed independently, so each must carry it; the test enforces the copies are byte-identical — that is the "one rule"). Content:

1. Search only the top level of the project root `.scratch/` — never subdirectories (`done/`, `plan/`, `audits/`) and never a worktree's `.scratch/` (in worktree mode ship step 4 copies the archived file into the worktree's `.scratch/done/`; that copy is under `done/` and outside the project root, so it is never a candidate).
2. Candidate = file whose name matches `DD-MM-YYYY-<slug>.md` (two digits, two digits, four digits, dash, non-empty slug) AND whose content has a `## Status` heading followed by one of the feature statuses: `to-build`, `building`, `to-validate`, `validating`, `to-fix`, `to-ship`. `shared-context.md` fails the name pattern; audit reports live in `.scratch/audits/` and have no `## Status` either way; `plan/` is a subdirectory.
3. Named lookup (`feature-name` given): the candidate whose file name is exactly `DD-MM-YYYY-<feature-name>.md` (the whole slug equals the name — no substring match: `context` never matches `shared-context.md` nor `24-11-2026-my-context-x.md`).
4. Without a name: the candidates are all candidate files (optionally narrowed by the phase's expected status — keep it simple: list all candidates).
5. Exactly one match → use it. Zero → stop with "No tracking file found…". Several (same slug on different dates, or several features in progress without a name) → list them (file + status) and ask which one; as a subagent (ship/run context), do not guess: return the blocked signal / stop.

Drop "most recent" entirely: picking by mtime is the root cause.

### Per-skill changes
- **build** step 1: replace the 2 lookup bullets with the rule block. Existing status guard stays.
- **validate** step 1: replace bullets with the rule block; add a status guard BEFORE setting `validating`: if status ≠ `to-validate`, stop with "Current status is `[status]` — buildit-feature-validate expects `to-validate`. Run `/buildit-feature-build [feature-name]` first." (stop rather than ask: validating a to-build feature is never meaningful, and a stale `validating` from an interrupted run → also accept? Decision: accept `validating` too? No — keep strict `to-validate`, but the message tells the user to reset status to `to-validate` to rerun an interrupted validation. Keeps the guard simple and unambiguous.)
  - Check: run's loop calls validate after build sets `to-validate`; build's handover sets `to-validate` → guard compatible. Verify run never calls validate on other status.
- **ship** step 0: replace bullets with rule block; keep the to-ship check but reword "most recent file" → "the selected file".
- **run** step 4: replace `*[feature-name]*.md` scan with a reference to the rule (named lookup) — include the block verbatim for consistency. Also check other places in run that read the tracking file (e.g. post-ship `TRACKING_FILE` check) and the task file lookup `.scratch/plan/task-{name}.md` (plan stays separate; fine).
- **audit**: change output path `.scratch/DD-MM-YYYY-audit-issues.md` → `.scratch/audits/DD-MM-YYYY-audit-issues.md` everywhere (description line 8, placeholder step, merge step, end message); create the directory (`mkdir -p` implied by "create `.scratch/audits/` if missing"). Update README line 339 and the existing audit test AT-6 regex (still matches; tighten to `audits/`).
- Do NOT move the existing `.scratch/24-11-2026-audit-issues.md` (user said not to commit it; leave it untouched).

### Tests (written first, must fail before edits)
New file `tests/test-tracking-file-discovery.sh` (picked up by run-all.sh — verify how run-all discovers tests):
- AT-1: each of build/validate/ship/run contains the rule heading, `## Status`, the exact-suffix wording `DD-MM-YYYY-<feature-name>.md`, and "ask" on multiple matches; the extracted rule block is identical across the 4 files.
- AT-2: none of the 4 files contains `most recent` nor a `*feature-name*` / `*[feature-name]*` substring glob; the rule names `shared-context.md`, `audits/`, `plan/` as excluded (top-level-only wording).
- AT-3: audit skill references `.scratch/audits/DD-MM-YYYY-audit-issues.md` and no longer `.scratch/DD-MM-YYYY-audit-issues.md` (regex for path without `audits/`).
- AT-4: validate contains the `expects \`to-validate\`` guard and it appears before "Set the status to `validating`" (line-order check).
- Behavioural check (cheap, valuable): a small bash reference implementation is NOT shipped (skills are prose); skip — structural tests only, consistent with the rest of the suite.

### Self-critique
- Assumption: run-all.sh auto-discovers `tests/test-*.sh` — verify; otherwise register the file.
- Risk: other tests may assert the old wording (`most recent`, `*feature-name*`, audit path) — grep tests and update them.
- Risk: README / docs describe the old lookup — grep README for "most recent" and update the user-facing description.
- Edge: same slug restarted on another date (old file still outside done/) → multiple matches → ask. Covered.
- Edge: tracking file of a feature with status line missing/corrupt → not a candidate → "not found" message must hint at checking `## Status`. Include in the stop message.
- Edge: run as orchestrator should never be ambiguous since it always has a name; if multiple matches it must stop, not ask mid-loop silently — the rule's subagent clause covers phases; run itself is interactive so asking is fine.
- Block-identity test: extract between the heading line and the next blank-line-terminated end marker; use an explicit end marker (the block is a fixed paragraph list) — simplest: extract lines from `**Tracking file discovery rule**` to the first line starting with `### ` or an empty line after the list. Use awk: from heading until a line that is exactly empty following list items. Keep the block as heading + contiguous list with no blank lines inside.

### Self-critique outcomes (verified)
- `tests/run-all.sh` globs `tests/test-*.sh` → the new test file is picked up automatically; no registration needed.
- Only `tests/test-buildit-project-audit.sh` AT-6 (`\.scratch/.*audit-issues\.md`) and README line 339 reference the old audit path; no test asserts `most recent` or `*feature-name*`. Update AT-6 to require `\.scratch/audits/` and fix README.
- Run calls validate only after confirming `to-validate` (run step 3 check), so validate's new guard never trips inside a normal run loop.
- Validate's guard must follow validate's existing deliberate-stop convention: write a `## Last error` section with the message before stopping, without changing the status — run step 5 then reports it instead of "possible subagent failure". Same for the "no/multiple tracking files" stops when running as a subagent.
- README: also update the build/validate/ship descriptions if they mention the lookup (grep `scratch/` sections during build).

## Decisions
- Worktree: no (instructed); working directly on `fix/audit`.
- The "one rule" is a verbatim block duplicated in the 4 phase skills (each skill is deployed standalone) with a test asserting byte-identity, rather than a shared guideline file that target projects may not have.
- Validate's guard stops (does not ask) when status ≠ `to-validate`; the message explains how to resume an interrupted `validating` run.
- Multiple matches → ask interactively; as a subagent → stop/blocked signal instead of guessing.
- Existing `.scratch/24-11-2026-audit-issues.md` left in place (not ours to move or commit).

## Progress
- Tests written first (`tests/test-tracking-file-discovery.sh`); 22 assertions failed on the assertion itself before the skill edits.
- Rule block inserted verbatim into build step 1, validate step 1, ship step 0, run step 4; old `*feature-name*` globs and "most recent" picks removed.
- Validate: status guard added before `Set the status to validating` — writes `## Last error` and stops without changing the status.
- Ship: rule stops as a subagent end with `SHIP BLOCKED: <reason>` (no `## Last error`, no file selected); to-ship warning reworded to "selected file".
- Run step 4: its own "not found after start" message kept; it takes precedence over the rule's generic no-match message.
- Audit: report moved to `.scratch/audits/DD-MM-YYYY-audit-issues.md` (creates the directory); README and audit test AT-6 updated.
- Left as-is: `docs/buildit/reviews/2026-10-14-skills-audit.md` (historical review) still mentions the old glob.
- Shared-context: added a Decisions & Conventions entry (verbatim shared-rule blocks + byte-identity test).
- `bash tests/run-all.sh`: 750 passed, 0 failed. Work staged by explicit paths; `.scratch/` not staged.
- Validate 24-11-2026: staging guard OK (only `.scratch/` entries unstaged/untracked, ignored); `bash tests/run-all.sh` 750 passed, 0 failed; base branch `main` (no `.buildit/config.md`, default). Review GO (diff reviewed: `git diff --cached`, this feature's staged changes; branch commits belong to earlier features). Acceptance AT-1..AT-5 PASS. Contracts checked intact (validate 2a/2b/2c/5a, ship order and step 4 worktree `.scratch/done/` write, `SHIP BLOCKED:`, `## Last error`, `## Branch`). Non-blocking notes: run step 4 now carries two stop messages for "not found" (rule's generic one and run's "not found after start") without stating which wins; tests do not assert ship's `SHIP BLOCKED` clause for rule stops nor validate's guard `## Last error` line. Autonomous decision: validated without a human; no questions needed.

## Retro
- Slowdowns: the canonical rule block had to be inserted into four skills while keeping each skill's own stop conventions (validate's `## Last error`, ship's `SHIP BLOCKED:`, run's "not found after start"), which needed careful wording per skill. Validate left two minor non-blocking notes: run step 4 carries two "not found" messages (the progress note says run's own message wins, but the skill text does not state the precedence explicitly), and the tests do not assert ship's `SHIP BLOCKED` line for discovery stops nor validate's exact `## Last error` guard line.
- Configuration: the missing piece was a convention for rules shared across standalone skills; it is now migrated to `.buildit/guidelines/team-practices.md` (verbatim block + byte-identity test). No other config change needed.
- Plan precision: precise enough — the self-critique caught the run-all discovery, the audit test AT-6 and README updates up front.
- Ship decisions (autonomous, subagent): readiness OK (only this branch's row in Merge readiness, no other IN_PROGRESS branch, no pending API/constraint entries); the Decisions & Conventions entry migrated to team-practices.md; shared-context needed no staging: this feature's entries were never committed, and the root file now matches the index again.
