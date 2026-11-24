# cross-skill-contract-tests

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 finding #22. Lock the cross-skill contracts settled by the 11 tasks already shipped on fix/audit (commits 141d0ba, 4118918, 308026f, 8d4dc58, 3137082, edf6145, 1de9ffe, 2fef64c, 768e538, cfead53, ae3dd01; archived tracking files in `.scratch/done/24-11-2026-task-*.md`, each Retro/Progress lists gaps it left). Several assertions are vacuous (`[Ss]top`, `shared-context\.md`) or pin whole sentences; the validate test comment says 5 dimensions and nothing asserts 6; section extractors are duplicated across test files and are not fence-aware; the skill list in the invariants test is hardcoded; no test covers the tracking-file, shared-context and config.md contracts behind the High audit findings. Prefer tests of cross-skill behaviour/contracts over tests of exact wording.

Files: `tests/lib/assertions.sh`, `tests/test-*.sh` (a new contract test file is fine; small skill fixes are acceptable only where a test reveals a real inconsistency, e.g. run step 4's two "not found" messages).

Known contracts and gaps to cover:
- Named blocks copied word for word across files: "Config value rule" (guideline `.buildit/guidelines/language-framework.md` + skills; existing `tests/test-config-parsing-boundary.sh`; gap: in `skills/buildit-plan/SKILL.md` the sentence wraps across lines so the absence-of-old-wording check cannot catch problems there — normalise whitespace/join lines before matching), "Tracking-file discovery rule" (build, validate, ship, run), "Operating mode rule" (`team-practices.md` + 7 skills; buildit-plan carries it without using it), "Plan task lookup rule" (run and discover), run's "Subagent autonomy block" (defined once).
- Run step 6 ship verification: no test covers check 3 (no copy left outside `done/`) or the "If any check fails" stop wording; step-order tests only match the first occurrence of each phrase.
- Run step 4 has two "not found" messages (the rule's general one and run's own "not found after start") and the skill does not say which applies.
- Ship's `SHIP BLOCKED` line for a discovery stop; the exact `## Last error` line validate's status check writes.
- `## Branch` contract: start step 3 writes it, ship step 0 and run step 6 read it. `## Last error` contract: a phase writes it when it stops, run reports it, ship step 0 and validate step 1 clear old ones.
- Phase order start → build → validate → ship and the status values each phase sets and expects.

Notes: `tests/test-readme.sh` AT-R9 checks README headings are unique. `.claude/skills` is a git-tracked symlink to `../skills`. `.scratch/24-11-2026-audit-issues.md` and `.scratch/plan/` are untracked plan files — never commit them. Skill files must stay in English. Do not edit `.claude/settings*.json`.

## Acceptance Tests
- AT-1: `tests/lib/assertions.sh` provides a fence-aware section helper, and test files use it instead of local extractors.
- AT-2: the vacuous regexes listed in the audit are replaced by section-scoped assertions; the validate test asserts 6 dimensions.
- AT-3: the invariants test builds the skill list from `skills/*/`.
- AT-4: a contract test checks that status names, tracking-file headings and config.md headings are consistent across skills.
- AT-5: `bash tests/run-all.sh` passes and can be run from any working directory.
- AT-6: a contract test checks that each named shared block (Config value rule, Tracking-file discovery rule, Operating mode rule, Plan task lookup rule) is identical (whitespace-normalised) in every file that carries it, and that run's Subagent autonomy block is defined exactly once; the old-wording absence check works on line-wrapped text (buildit-plan included).
- AT-7: contract tests cover the phase handoff: start → build → validate → ship order and the status each phase sets/expects; the `## Branch` writer/readers (start step 3, ship step 0, run step 6); the `## Last error` writer/reporter/clearers (run reports it, ship step 0 and validate step 1 clear it, validate's status-check line); ship's `SHIP BLOCKED` line for a discovery stop; all three run step 6 ship-verification checks and the "If any check fails" stop; run step 4 states unambiguously which "not found" message applies after start.

## Plan

### Decisions (taken autonomously — subagent, no human available)
- D1. Worktree: **no** (imposed by the caller). Work directly on `fix/audit`; never switch branches; no push.
- D2. Repo-root anchoring lives in `tests/lib/assertions.sh` (it `cd`s to `$(dirname "${BASH_SOURCE[0]}")/../..` when sourced), so every test file works from any cwd, standalone or via `run-all.sh`. `run-all.sh` already resolves `SCRIPT_DIR`; it also `cd`s to the repo root for symmetry. Test files keep sourcing via `"$(dirname "$0")/lib/assertions.sh"` (resolved before the cd). Remove the now-redundant per-file `cd "$(dirname "$0")/.."` lines only where harmless (optional).
- D3. One new contract file `tests/test-cross-skill-contracts.sh` holds AT-4, AT-6 and AT-7 checks. The existing `test-mode-detection.sh`, `test-tracking-file-discovery.sh`, `test-config-parsing-boundary.sh` keep their content-specific checks but switch to the shared helpers; their identity checks are subsumed by the generic named-block check (keep them only if they test something more — e.g. heading-count-once — otherwise delete the duplicate loop to avoid DRY drift).
- D4. Run step 4 fix (small skill edit, English): state explicitly that after start, run's own "Tracking file not found after buildit-feature-start …" message **replaces** the rule's general "No tracking file found …" message (the rule's several-matches branch still applies as written). E.g. add, right after the rule block: "After start, a no-match result is reported with run's own message below instead of the rule's general one:". Keep the rule block byte-identical to the other copies.
- D5. Section-scoped helpers rather than whole-file regexes; prefer contract checks (heading/value sets, writer/reader presence in the right step) over full-sentence pins. Full-sentence pins are kept only for lines that are a machine contract (e.g. the exact `## Last error` line, `SHIP BLOCKED:` prefix).

### Step 1 — Shared helpers in `tests/lib/assertions.sh` (AT-1, AT-5)
Add, all fence-aware (lines inside ``` or ~~~ fences are never treated as headings/terminators; a fence opener toggles only when the line *starts* with ``` or ~~~):
- Repo-root `cd` (D2).
- `section FILE START [END]` — prints from the first line whose start equals START (prefix match via `index($0,START)==1`, heading included) to the line before the next heading of the same-or-higher level outside fences; if END is given, stop at the first line starting with END instead. Level is inferred from the number of leading `#` in START when START is a heading; for non-heading starts (e.g. `**Rule**`, `Plan handoff:`) END is required or the section runs to the next `## `/`### ` heading outside fences.
- `section_body FILE HEADING` — same, heading line excluded (replaces run's/audit's `section_body`).
- `named_block FILE HEADING` — prints from the line exactly equal to HEADING to the first blank line (the named-rule convention), outside fences.
- `normalize` — joins lines and squeezes whitespace (`tr -s '[:space:]' ' '`, trim), used for wrapped-text matching and block identity.
- `in_text LABEL TEXT FIXED` / `in_text_re LABEL TEXT REGEX` / `absent_in_text LABEL TEXT REGEX` — assertions on a captured section (replace the local `in_sec`, `check_rule`, `p5_manual` helpers).
- `count_outside_fences FILE EXACT_LINE` (generalise test-readme.sh's local counter) and `line_of FILE FIXED [NTH]` for order checks.
Self-check: a small fixture-based assertion inside the new contract test (heredoc into `mktemp`) proving that a `## X` line inside a ~~~ fence does not end a section — guards the helper itself.

### Step 2 — Migrate local extractors (AT-1)
Replace local awk/sed extractors with the helpers in: build (STEP5), discover (README_SECTION, GUIDELINE_SECTION, P5, p5_manual), run (section_body, sync_section, extract_lookup_rule, ROUTING_INTRO/NEXT_AFTER_MSG where a section helper fits — getline-based "next line" probes may stay if no helper fits; record), start (S5), ship (sec, README awk), validate (SECTION_5A, WD_*, TESTS_SEC, C5_SEC), plan (section), bootstrap (TPL, RULES_TPL, section), audit (ISO_SECTION), mode-detection & tracking-file-discovery (extract_rule → named_block), readme (local section/count). Frontmatter/description parsing in test-quote-skill-descriptions.sh is not a section extractor — leave it. Acceptance probe: `grep -nE "awk .*(f=1|on=1)|sed -n '/\^" tests/test-*.sh` returns nothing except documented exceptions.
Risk: start/plan templates contain `## Status` etc. inside ~~~ fences; previously non-fence-aware extractors may have relied on that. Run each test file after migrating it, one at a time.

### Step 3 — Remove vacuous assertions (AT-2)
- `[Ss]top` in validate AT-8 → assert inside the "Run test suite" section that a failure skips the review/acceptance and routes to to-fix (section-scoped).
- `shared-context\.md.*(not exist…)` in start/build/ship/validate → assert inside the prerequisite-check section (start step 0, build's, ship 0a, validate's) the exact shared stop message "Shared context file not found — run `/buildit-project-bootstrap`" — and in the contract test, that every phase skill carries the same prerequisite message (one contract check, not per-file sentence pins).
- Validate AT-1: fix comment to 6 dimensions; count the dimension list items in the review section (= 6) and check Craft principles is one of them, mirroring bootstrap AT-TB-2.
- Scan the other generic whole-file regexes found during migration (run AT-3/AT-4 `(not found|missing)…`) and scope them to their step section; replace run AT-4 with the step-4 contract (AT-7).

### Step 4 — Invariants skill list (AT-3)
`SKILLS=()` built from `for d in skills/*/; [[ -f $d/SKILL.md ]]`; assert the list is non-empty and that each dir has SKILL.md (a dir without one is a failure, not silently skipped). WRITERS list stays explicit but is cross-checked: every skill whose text writes to shared-context (`Merge readiness` row edits) must be in WRITERS — or keep explicit and note.

### Step 5 — Contract test `tests/test-cross-skill-contracts.sh`
AT-6 named blocks (whitespace-normalised identity, carriers discovered by grepping the exact heading line across `skills/*/SKILL.md` + `.buildit/guidelines/*.md`, with an expected minimum carrier set so a block silently dropped from a file fails):
- `**Operating mode rule**` — reference: team-practices.md; carriers ⊇ 7 skills.
- `**Tracking file discovery rule**` — build, validate, ship, run.
- `**Plan task lookup rule**` — run, discover.
- Config value rule — not a bold-heading block: reference phrase from the guideline (`read only within that heading (stop at the next heading); a line starting with \`#\` is never a value`); every consumer's *normalised* text contains it; the old-wording absence check runs on normalised text split into sentences (so buildit-plan's wrapped sentence is covered): any occurrence of "first non-empty, non-comment line" must be followed within the same normalised sentence by "read only within that heading". Update test-config-parsing-boundary.sh AT-4 to use the normalised form (or move it here and delete there — choose move, D3).
- Subagent autonomy block: heading `## Subagent autonomy block` appears exactly once outside fences in run; each reference `[Autonomy block — see "Subagent autonomy block"]` appears at each launch step (3, 5.2, 5.4, 6), and the block body text (its first distinctive sentence) appears exactly once in the file.
Each block heading appears exactly once per carrier file.

AT-4 vocabulary consistency:
- Status set S = statuses listed in the Tracking file discovery rule. Every backticked status token set/expected in phase skills (`Set the status to \`X\``, `expects \`X\``, `status \`X\``) ∈ S; bootstrap's "Status flow" line and `.claude/CLAUDE.md`'s status line mention exactly S (as words).
- Tracking-file headings H = start template headings (parsed from the fenced template in start step 3) ∪ {Problems to fix, Last error}. Bootstrap's "Tracking file sections:" list equals H (order-insensitive). Every `` `## X` `` / "X" section reference in start/build/validate/ship/run that is a tracking-file heading belongs to H (filter: exclude config headings and plan-task headings — Description, Acceptance tests, Readiness, Synchronization, which belong to plan task files; assert those are only read by discover/run/plan).
- Config headings C = headings of bootstrap's config.md template (`# Project Configuration` fenced block). Every `` `## X` `` referenced next to `.buildit/config.md` in skills ∈ C; and each C heading has at least one consumer.

AT-7 phase handoff:
- Order: start's End of skill names `/buildit-feature-build`; build's names `/buildit-feature-validate`; validate GO names `/buildit-feature-ship`; validate NO-GO names `/buildit-feature-build`. Run's step headings for subagents appear in order start < build < validate < ship (using `line_of` on the `### N.` / numbered sub-step lines, not first-occurrence of a free phrase).
- Status transitions: start template writes `to-build`; build expects to-build|to-fix and sets `building` then `to-validate`; validate guard expects `to-validate`, sets `validating`, then `to-ship` / `to-fix`; ship expects `to-ship`; run's post-build check expects `to-validate`, post-validate routes `to-ship`/`to-fix`. Each asserted inside the relevant step section.
- `## Branch`: start step 3 template has `## Branch` and the contract paragraph; ship step 0 section reads `## Branch`; run step 6 "Record the pre-ship state" reads `## Branch`; no phase other than start writes it (absence of "write/update `## Branch`" in others).
- `## Last error`: writers — validate status guard line exactly `buildit-feature-validate: status is <status>, expected to-validate`, validate base-branch line, ship blocked line `buildit-feature-ship: blocked — <precise reason>`; reporter — run step 5.5 and step 6 failure message mention `## Last error`; clearers — ship step 0 and validate step 1 remove it (section-scoped). Every writer line starts with the phase skill name + `: ` (format contract).
- Ship discovery stop: ship step 0 contains `SHIP BLOCKED: <precise reason>` *after* the rule block and states no `## Last error` is written; run step 6 failure message quotes `SHIP BLOCKED:`.
- Run step 6 verification: the numbered list in "Verify ship before closing the task" has exactly 3 items: (1) `git rev-parse <SHIP_REF>` vs `PRE_SHIP_HEAD`, (2) `git cat-file -e <SHIP_REF>:.scratch/done/<TRACKING_FILE>`, (3) `.scratch/<TRACKING_FILE>` no longer exists; followed by "If any check fails, stop" and the stop message starting `Unexpected state after ship:`; and the plan-task update subsection comes after it (order within the step-6 section, not file-wide first match).
- Run step 4: after the fix (D4), step-4 section states the after-start no-match message replaces the rule's; assert the step-4 section contains the explicit replacement sentence and run's own message, and that the rule's general message appears only inside the rule block.

### Step 6 — Skill fix (D4) + verification
- Edit `skills/buildit-feature-run/SKILL.md` step 4 only (deployed via symlink — no copy needed). Re-run named-block identity to confirm the rule block untouched.
- Run every test file individually, then `bash tests/run-all.sh` from repo root, from `tests/`, and from `/tmp`-like other dir inside project (e.g. `.scratch/` or `skills/`) — AT-5. Never cd outside project root.
- Write failing tests first (contract file + new helpers usage) and capture the red run for run step 4 before the skill fix.

### Self-critique corrections (step 4 of start)
- Assumption: a test helper `cd`-ing on source could break tests that use paths relative to the caller cwd — all current tests use repo-relative paths, so it is safe; verify by running each file from `tests/`.
- Assumption: start's template is inside a `~~~markdown` fence; a fence-aware `section` would *stop* skipping it… the helper must print fence contents while ignoring headings inside fences for termination only. Parsing the template's headings needs a dedicated fenced-block reader (`fenced_block FILE START_MARKER`), add it to the lib.
- Edge: `~~~` vs ``` fences nested (bootstrap has ~~~ wrapping ``` lines?). Track the opener char and only close on the same marker; test with bootstrap's templates.
- Edge: status token scanning may hit plan task statuses (`in-progress`, `done`, `pending`) in run/discover/plan — restrict the scan to tracking-file status phrases ("Set the status to", "status is", "expects") inside phase skills, and exclude the plan-task update subsection of run step 6.
- Edge: tracking heading scan may pick up `## Problems to fix` inside validate's fenced example (fine, it is in H) and `## Synchronization` (plan task) — handled by the explicit plan-task heading allowlist scoped to discover/run/plan.
- Vague step made concrete: "full-sentence pins" — keep only machine-contract lines (D5); everything else asserted via key tokens within a section.
- Risk: README AT-R9 unique headings — don't touch README unless a test needs it (none planned).
- Risk: removing per-file identity loops from older tests could lose coverage of "heading appears once" — the contract test asserts it for every carrier.
- Do not commit `.scratch/24-11-2026-audit-issues.md` nor `.scratch/plan/`. Do not edit `.claude/settings*.json`.

## Progress
- 24-11-2026: start — plan written; worktree: no (caller-imposed), branch `fix/audit`. Decisions D1–D5 recorded above.
- 24-11-2026: build (TDD mode, no worktree, branch `fix/audit`).
  - Step 1: fence-aware helpers added to `tests/lib/assertions.sh` (`section`, `section_body`, `named_block`, `fenced_block`, `count_outside_fences`, `lines_outside_fences`, `line_of`, `normalize`, `in_text`, `in_text_re`, `absent_in_text`). Sourcing the lib `cd`s to the repo root (D2). Fences: ``` or ~~~, optional indentation, closed only by the same marker.
  - Step 2: local extractors replaced in build, start, ship, validate, run, discover, plan, bootstrap, audit, readme, mode-detection, tracking-file-discovery, config-parsing-boundary. Documented exceptions kept: run AT-I6 "next line" getline probes, test-quote-skill-descriptions.sh frontmatter parsing, bootstrap AT-TB-2 dimension counter (counts list items in an already-extracted section).
  - Step 3: vacuous checks replaced by section-scoped ones — prerequisite checks (start/build/validate/ship), validate AT-1 (6 dimensions: announced count + exactly 6 table rows + each name), AT-4/5 (craft row), AT-6/7/8 (step 2b → "If NO-GO or FAIL" → to-fix), build AT-2, run AT-1/2/3/7; run AT-4 moved to the contract file.
  - Step 4: invariants skill list built from `skills/*/` (non-empty assert). WRITERS list kept explicit with a note (writing shared-context is behaviour, not detectable from a heading).
  - Step 5: `tests/test-cross-skill-contracts.sh` (AT-4, AT-6, AT-7 + helper self-checks with fixtures, incl. a line-wrapped sentence for the Config value rule). Identity loops removed from test-mode-detection.sh, test-tracking-file-discovery.sh and run AT-PL-2, and the per-consumer phrase/unbounded-read loops moved out of test-config-parsing-boundary.sh (D3); content checks kept there.
  - Step 6 (D4): red first — the contract test failed on run step 4 only; then `skills/buildit-feature-run/SKILL.md` step 4 now says the after-start no-match uses run's own message instead of the rule's general "No tracking file found" message (several-matches branch unchanged). Rule block untouched (identity check green).
  - Decision B1: `tests/run-all.sh` left unchanged (it already resolves its own dir; the lib anchoring makes a `cd` there redundant — KISS).
  - Decision B2: config.md heading contract checked as: template headings disjoint from tracking headings, each documented in language-framework.md, each with ≥1 consumer skill (a line-level "next to config.md" scan is ambiguous: run reads `## Synchronization` of the plan task on the same line).
  - Decision B3: the `## Branch` "no other writer" check matches a write verb directly before `## Branch` (a looser regex flagged run step 2's "writes the Merge readiness row keyed by … `## Branch`").
  - Tests: `bash tests/run-all.sh` → 1049 passed, 0 failed, from repo root, `tests/` and `skills/` (AT-5). Contract file alone: 226 passed.
  - New convention recorded in shared-context "Decisions & Conventions" (test helpers / contract file).
- 24-11-2026: validate (no worktree, branch `fix/audit`, base `main`; no `.buildit/config.md` → Tier 2 `bash tests/run-all.sh`).
  - Staging guard: only `.scratch/` paths unstaged/untracked (ignored by rule) → pass.
  - Tests: 1049 passed, 0 failed from the repo root and from `tests/`; contract file alone 226/226 from root and `skills/`.
  - Review: GO — fence-aware helpers correct (same-marker close, headings inside fences ignored, self-checks with fixtures); contract tests check writer/reader per step rather than wording; the only skill change (run step 4) is a minimal clarification in English. Remaining awk probes in run AT-I6 and bootstrap AT-TB-2 are the documented exceptions.
  - Acceptance: AT-1..AT-7 PASS → status `to-ship`.
- 24-11-2026: ship (no worktree, branch `fix/audit`, base `main`). Readiness: ✓ OK to ship (no other IN_PROGRESS branch, no waiting dependency, no pending API/constraint entries). Shared-context cleaned (own Decision + own Merge readiness row removed; the index copy carried none of them → nothing to stage for it). Decision migrated to `.buildit/guidelines/team-practices.md` (Test harness conventions: repo-root anchoring, "Section-scoped assertions", "Cross-skill contracts"); stale references to `tests/test-mode-detection.sh` / byte-identical copies updated to the contract test. Full suite after migration: 1049 passed, 0 failed.

## Retro
- What slowed the loop: the scope was wide (13 test files migrated to shared helpers) and each migration had to be re-run one file at a time because older extractors were not fence-aware and the start/plan templates sit inside `~~~` fences; deciding how to express config.md and `## Branch` contracts without line-level false positives (B2, B3) took several iterations.
- Would a configuration have prevented it: yes — a guideline forbidding local extractors and whole-file generic regexes; now added to team-practices.md (Section-scoped assertions, Cross-skill contracts).
- Was the plan precise enough: yes; D1–D5 and the self-critique edges (fence nesting, plan-task statuses, plan-task headings) held. Deviations were minor (B1: run-all.sh untouched; B2: config.md contract checked by disjointness + documentation + consumer instead of a "next to config.md" scan).
- Gaps left for later: run AT-I6 "next line" getline probes and bootstrap AT-TB-2 dimension counter remain local awk (documented exceptions); the WRITERS list in the invariants test stays hand-maintained (writing shared-context is behaviour, not detectable from a heading); the config.md contract does not verify that each skill reads a heading only next to `.buildit/config.md`; the contract tests are still structural (text-level), not behavioural runs of the agents.
