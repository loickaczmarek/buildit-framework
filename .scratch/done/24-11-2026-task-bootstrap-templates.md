# task-bootstrap-templates

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 findings #10, #17, #20, #25 (bootstrap part), #26, #31, #33 (see `.scratch/24-11-2026-audit-issues.md`).

Bootstrap never generates `craft-principles.md` although build/validate/audit reference it; its team-practices template lists 5 review dimensions (validate has 6) and its tracking-sections list omits `Worktree path` and `Problems to fix` (and now also `Branch`, `Last error`). Its permission template's `cd <root>*` pattern matches siblings and `<root>/../..` while the note claims no escape; run quotes a different worktree permission string. Bootstrap stages whole directories (`git add .claude/ .buildit/ .scratch/`), still says "workflow v2", points to feature-start instead of feature-run, and describes itself as "auditing". Build uses `<guidelines-dir>` without defining it, and run's autonomy block is copied 4 times with drift. Additionally, bootstrap's generated kit must reflect the contracts the skills now use: the template Progress line must convey the `### NO-GO cycle` heading cycle count and the `## Last error` convention (see `.buildit/guidelines/team-practices.md`); and bootstrap's "Coring summary" says "4a–4f" though the fast path only runs 4e and 4f.

Files: `skills/buildit-project-bootstrap/SKILL.md`, `skills/buildit-feature-build/SKILL.md`, `skills/buildit-feature-run/SKILL.md`, `README.md`, `.claude/CLAUDE.md`, tests under `tests/`.

Context: `.claude/skills` is a git-tracked symlink to `../skills` (nothing to copy). README headings must stay unique (tests/test-readme.sh AT-R9): edit sections in place. The Config value rule wording is enforced by tests/test-config-parsing-boundary.sh and tracking-file discovery wording by tests/test-tracking-file-discovery.sh — do not alter those blocks. Untracked `.scratch/24-11-2026-audit-issues.md` and `.scratch/plan/` must never be committed.

## Acceptance Tests
- AT-1: bootstrap detects and generates `craft-principles.md`; the rules-file template indexes it.
- AT-2: the team-practices template lists 6 review dimensions and the full tracking-file section list (including Branch, Worktree path, Problems to fix, Last error).
- AT-3: the `cd` permission patterns are anchored (`<root>` and `<root>/*`), the security note no longer claims sandboxing, and one worktree permission string is used in bootstrap, README and run.
- AT-4: bootstrap stages explicit paths only and ensures `.claude/settings.local.json` is gitignored.
- AT-5: "workflow v2" is gone, the closing message recommends `/buildit-feature-run`, and the description no longer uses "audit".
- AT-6: build defines `<guidelines-dir>` in a step 0; run defines its autonomy block once and references it.
- AT-7: tests assert AT-1 to AT-6 and AT-8/AT-9; `bash tests/run-all.sh` passes.
- AT-8: bootstrap's tracking-file template Progress line states the NO-GO-only cycle count (`### NO-GO cycle` headings) and the `## Last error` convention.
- AT-9: bootstrap's Coring summary matches the steps actually run (fast path: 4e and 4f only; full path: 4a–4f).

## Plan

### Decisions (taken autonomously — no human available)
- D1 Worktree: **no** — instructed by the caller; work directly on `fix/audit`.
- D2 (amended at build, per caller note) Claude Code splits compound commands on `&&` and checks each subcommand separately: `Bash(cd */.worktrees/*)` covers only the `cd` part and the chained command needs its own rule (e.g. `Bash(bash *)`). Wording in run/README/bootstrap says so explicitly; the original rationale below ("prefix matching covers the chain") is superseded.
- D2 Canonical worktree permission string: **`Bash(cd */.worktrees/*)`** (the one bootstrap and README already use). Rationale: Claude Code `Bash(...)` rules use prefix-style wildcard matching, so `cd */.worktrees/*` already covers `cd <wt> && bash tests/…`; the `&& *` variant in run is a strict subset and the source of drift. Run is aligned to bootstrap/README, which keeps existing tests `tests/test-buildit-worktree.sh` AT-7/AT-8 valid. (Validate should Context7/claude-code-guide check only if uncertain; not a library API change.)
- D3 Anchored project-root patterns: replace `Bash(cd <project-root>*)` with the two rules `Bash(cd <project-root>)` and `Bash(cd <project-root>/*)` in bootstrap's template (step 2b), bootstrap's audit list of essential rules, and README's settings example + note.
- D4 Security note rewording: describe the `cd` patterns as navigation hygiene / reducing prompts, explicitly **not** a sandbox — state that `<root>/*` still matches `<root>/../x` textually and that `git *`, `python3 *`, `docker *` already allow arbitrary execution, so the permission list is not a security boundary. Same wording idea in README (edit the existing paragraph in place; no new headings).
- D5 Autonomy block in run: define it once in a named preamble section (e.g. "## Subagent autonomy block", next to "Subagent selection and workflow isolation", or inside step 0 after `PROJECT_ROOT`/`MODE`) with two variants clearly delimited: the base line (start subagent: "Execute bash, python3, and cd commands freely … including `.worktrees/` …") and the worktree addendum ("[If use-worktree=yes]: Run test and script commands with the worktree as working directory … `git -C <worktree-path>` … required permission `Bash(cd */.worktrees/*)`"). Decide: a single block containing the base text + the worktree addendum, used by every subagent (start included; start in no-worktree mode just ignores the addendum since use-worktree=no). Steps 3, 5 (build + validate) and 6 (ship) replace the quoted copies with "Append the **Autonomy block** (see §…) with `[PROJECT_ROOT]`, `[MODE]`, `[worktree-path]` substituted." Check that `tests/test-buildit-feature-run.sh` assertions on autonomy wording still match (grep before editing; adapt tests that count copies, add a test asserting exactly one "Autonomy: you are operating" occurrence).
- D6 `craft-principles.md` template content: reuse the definitions from this repo's `.buildit/guidelines/craft-principles.md` in condensed form (DRY, KISS, YAGNI + "how to apply"). Constraint: `tests/test-dry-kiss-yagni-principles.sh` AT-3 forbids *definitions* in skill files — read that test first; it may scan `skills/*/SKILL.md` including bootstrap. If it does, the bootstrap template must not contain the definition phrases the test greps for; option: bootstrap copies the template content with short, differently-worded one-liners, or the test's exclusion list is extended to bootstrap's template block with justification. Prefer: keep bootstrap template short (headings + one-line intent per principle) and confirm the AT-3 grep patterns do not match; only adjust the test if unavoidable, and document why in Progress.
- D7 Gitignore of `settings.local.json`: bootstrap step 9 (Claude mode) appends `.claude/settings.local.json` to `.gitignore` if absent before staging, and stages `.gitignore` explicitly. Also add `.claude/settings.local.json` to this repo's `.gitignore` (finding #26 proposed fix) — small, in scope.

### Steps
1. **Read first** (no edits): `tests/test-buildit-project-bootstrap.sh`, `tests/test-buildit-feature-build.sh`, `tests/test-buildit-feature-run.sh`, `tests/test-buildit-worktree.sh`, `tests/test-dry-kiss-yagni-principles.sh`, `tests/test-readme.sh`, `tests/test-skills-invariants.sh`, `tests/lib/assertions.sh` (available helpers: `require_text`, `require_regex`, `require_absent`, `sync_section`, …). Record any existing assertion that pins wording we are about to change (e.g. "Autonomy settings missing", description quoting tests in `test-quote-skill-descriptions.sh`, AT-1 of validate test "5 dimensions" comment — comment only).
2. **Failing tests first** — add to `tests/test-buildit-project-bootstrap.sh` (prefix new ids `AT-T1…AT-T9` or continue numbering; avoid id collisions):
   - AT-1: `require_text` `craft-principles.md` in step 0/1 detection list (the "expected files" list near line 54) and a template heading `` `<guidelines-dir>/craft-principles.md`: `` in step 8; rules-file template contains `.buildit/guidelines/craft-principles.md`.
   - AT-2: section-scoped check (use `sync_section` or awk between `` `<guidelines-dir>/team-practices.md`: `` and `` `<guidelines-dir>/language-framework.md` ``) for `Craft principles` dimension, and the line `Tracking file sections: Status · Branch · Worktree path · Goal · Acceptance Tests · Plan · Progress · Problems to fix · Last error` (match exact sequence; keep identical to team-practices guideline order + `Last error`).
   - AT-3: `require_text 'Bash(cd <project-root>)'` and `'Bash(cd <project-root>/*)'`; `require_absent 'Bash(cd <project-root>*)'` in bootstrap and README; `require_absent` "None allows" / "parent-directory escape" in bootstrap and README; positive `require_regex 'not a (security )?(boundary|sandbox)'` in both; in run `require_absent 'Bash(cd */.worktrees/* && *)'` and `require_text 'Bash(cd */.worktrees/*)'`.
   - AT-4: `require_absent 'git add .claude/ .buildit/ .scratch/'` and `require_absent 'git add .agents/guidelines/project-rules.md .buildit/ .scratch/'`; `require_text '.claude/settings.local.json'` within step 9 section; regex for explicit file list (`git add .claude/settings.json` and `.buildit/guidelines/craft-principles.md`).
   - AT-5: `require_absent 'workflow v2'` in bootstrap and README; `require_text '/buildit-feature-run'` in the End-of-skill section; description line (line 3) does not match `audit`.
   - AT-8: section-scoped regex in team-practices template for `### NO-GO cycle` and `## Last error`.
   - AT-9: Coring summary paragraph mentions fast path `4e and 4f` (regex `fast path.*4e.*4f` near "Coring summary").
   - AT-6: in `tests/test-buildit-feature-build.sh`: `require_regex '### 0\. .*' ` and `<guidelines-dir>.*=.*\.buildit/guidelines` defined before step 1 (awk: line of definition < line of `### 1.`). In `tests/test-buildit-feature-run.sh`: count of `Autonomy: you are operating within the project directory` == 1 and count of "Autonomy block" references ≥ 4 (steps 3, 5 build, 5 validate, 6).
   - Check `.gitignore` contains `.claude/settings.local.json` (in bootstrap test or test-skills-invariants).
   Run `bash tests/run-all.sh` → confirm the new assertions fail for the right reason.
3. **Bootstrap edits** (`skills/buildit-project-bootstrap/SKILL.md`):
   - Line 3 description: "Use when starting a new project or resynchronising an existing project's configuration — scans …". Keep it quoted (test-quote-skill-descriptions).
   - Line 8: drop "v2" ("multi-agent workflow configuration kit").
   - Step 1 expected files list (~line 54): add `<guidelines-dir>/craft-principles.md`; fast-path condition (~line 126): decide whether craft-principles absence breaks the fast path → fast path still allowed but step 8 creates `craft-principles.md` if missing (record in plan; keep minimal).
   - Step 2b template (~80) + audit list (~102-105) + note (~100): D3/D4.
   - Coring summary (~211): "at the end of the coring steps actually run (full path: 4a–4f; fast path: 4e and 4f only — summarise only test signals and base branch) …".
   - Diagnostic list (~282) + step 8 actions: add craft-principles creation (create if absent, never overwrite an existing one).
   - Rules-file template (~322): add `- .buildit/guidelines/craft-principles.md — DRY, KISS, YAGNI craft principles`.
   - Team-practices template: 6th dimension `Craft principles: DRY, KISS, YAGNI respected? (see craft-principles.md)`; tracking sections line; replace Progress line with the three-line convention from `.buildit/guidelines/team-practices.md` lines 159-161 (Progress / Cycle count / Last error), adding `Last error` to the sections list.
   - New `craft-principles.md` template block (D6).
   - Step 9: explicit paths. Claude: ensure `.claude/settings.local.json` in `.gitignore` (append if absent), then `git add .gitignore <rules-file> .claude/settings.json .buildit/guidelines/team-practices.md .buildit/guidelines/language-framework.md .buildit/guidelines/craft-principles.md .buildit/config.md .scratch/shared-context.md` (only files that exist / were written — say "stage only the files this run created or modified, from this list"). Generic: same minus `.claude/settings.json`, with `.agents/guidelines/project-rules.md`. Commit message: `chore(config): bootstrap buildit project configuration`.
   - End of skill: recommend `/buildit-feature-run` (mention `/buildit-feature-start` as the manual alternative).
   - Do NOT touch the Config value rule paragraph (~line 446) or any tracking-file discovery wording.
4. **Build edits**: add `### 0. Resolve paths` (or merge into the existing `### 0. Prerequisite check`, which already exists at line 17 → append the definition there: "`<guidelines-dir>` = `.buildit/guidelines/` (relative to the project root, or to the worktree in worktree mode)"). Self-critic note: build already has a step 0 — extend it rather than renumbering, so run's/other references to build's step numbers stay valid.
5. **Run edits**: D2 + D5. Grep afterwards: `grep -c 'Autonomy: you are operating' skills/buildit-feature-run/SKILL.md` must be 1.
6. **README edits**: settings example (~187-189) D3; note paragraph (~207) D4; line 324 commit message aligned to the new bootstrap message; mention `craft-principles.md` in the bootstrap section's generated-files list if one exists. No new headings.
7. **`.claude/CLAUDE.md`**: add `- .buildit/guidelines/craft-principles.md — DRY, KISS, YAGNI craft principles` to the Guidelines index (mirrors the rules-file template).
8. **`.gitignore`**: add `.claude/settings.local.json`.
9. Run `bash tests/run-all.sh` → all green. Grep checks: `grep -rn 'workflow v2\|cd \*/.worktrees/\* && \*\|project-root>\*' skills README.md` → empty.
10. Stage only the files changed (explicit paths; never `.scratch/24-11-2026-audit-issues.md` or `.scratch/plan/`), then set status `to-validate`.

### Self-critique (corrections integrated above)
- Assumption: build has no step 0 → **wrong**, it has `### 0. Prerequisite check`. Corrected: add the definition inside existing step 0 (AT-6 satisfied: "defines `<guidelines-dir>` in a step 0").
- Assumption: changing run's worktree string to `&& *` would be canonical → rejected; would break `test-buildit-worktree.sh` AT-8 (bootstrap string with closing paren) and the prefix rule already covers `&&` chains (D2).
- Risk: `test-dry-kiss-yagni-principles.sh` AT-3 may forbid craft definitions inside any SKILL.md, colliding with the new bootstrap template → read the test first (D6).
- Risk: README tests (`test-readme.sh`, `sync_section` in run test line 235) compare README sections with skills; changing run's autonomy text or bootstrap commit message may break a sync check → run the full suite after each file edit, not only at the end.
- Edge: the `<root>/*` pattern still textually matches `<root>/../sibling` — the new note must say so honestly rather than claim anchoring prevents escape.
- Edge: fast path skips step 8 creation of guidelines; craft-principles.md may be missing in a fast-path project → step 8 must create `craft-principles.md` when absent even on the fast path (state it explicitly).
- Edge: re-bootstrap with an existing `.gitignore` already containing the entry → "append only if absent" (idempotent).
- Edge: Generic mode has no `.claude/settings.local.json`; the gitignore step applies to Claude mode only.
- Vague step guarded: "explicit paths" means a literal file list in the skill; tests assert absence of directory-wide `git add`.
- Do not alter Config value rule block or tracking-file discovery blocks (protected by dedicated tests).

## Progress

### Build — 24-11-2026 (TDD mode)
- Failing tests first: 46 new assertions failed on content (AT-TB-1..9 in `tests/test-buildit-project-bootstrap.sh`, AT-GD-1 in `tests/test-buildit-feature-build.sh`, AT-AB-1..3 in `tests/test-buildit-feature-run.sh`); then implemented; `bash tests/run-all.sh` → 796 passed, 0 failed.
- Build decisions (autonomous, no human available):
  - B1 Existing `AT-WD-2` in the run test asserted ≥3 copies of the worktree instruction (it pinned the duplication). Changed to exactly 1 (inside the Subagent autonomy block); per-prompt coverage is asserted by AT-AB-2 (≥4 references).
  - B2 Autonomy block: single block (base text + worktree paragraph included only when use-worktree=yes) used by start, build, validate and ship; start now also gets "relative to the worktree in worktree mode" (harmless in no-worktree mode).
  - B3 Bootstrap template does not add `Bash(bash *)` by default; the note tells the user to add it when the test command is `bash tests/run-all.sh` (the chained command needs its own rule).
  - B4 `test-dry-kiss-yagni-principles.sh` AT-3 only scans build and validate skills, so the bootstrap craft-principles template keeps the full principle names; no test exclusion was needed (D6).
  - B5 Craft-principles template is created when absent on the fast path too, never overwritten (step 8).
  - B6 Bootstrap commit message renamed `chore(config): bootstrap buildit project configuration`; staging list is explicit with "stage only the files this run created or modified".
  - B7 Also appended `· Last error` to the repo's own `.buildit/guidelines/team-practices.md` section list, keeping it identical to the bootstrap template.
- Shared-context: added a Constraint (`&&` subcommand matching) and a Decision (autonomy block defined once).

### Validate — 24-11-2026
- Staging guard: PASS (all feature files staged; only `.scratch/` entries untracked/unstaged, ignored by the guard; `.scratch/24-11-2026-audit-issues.md` and `.scratch/plan/` intentionally untracked).
- Tests: PASS — `bash tests/run-all.sh` (Tier 2 fallback; no `.buildit/config.md`) → 796 passed, 0 failed.
- Base branch: `main` (default, resolves locally).
- Review: GO — Correctness OK; Performance n/a; Security OK (note now honestly states the allowlist is not a boundary; `settings.local.json` gitignored); Style OK (no new README headings, protected Config value / discovery blocks untouched); Test coverage OK (AT-TB-1..9, AT-GD-1, AT-AB-1..3, AT-WD-2 tightened to exactly 1); Craft OK (autonomy block de-duplicated). D2's `&&` subcommand-splitting claim checked against Claude Code permissions docs (Context7): a rule must match each subcommand independently — confirmed.
- Non-blocking observations: (1) bootstrap's fast-path trigger condition ignores whether `craft-principles.md` exists, covered by step 8's "create when absent, on the fast path too"; (2) bootstrap's settings template does not include `Bash(bash *)` although `bash tests/run-all.sh` is the first fallback test command — the note tells the user to add it (B3).
- Acceptance: AT-1..AT-9 all PASS → PASS overall.
- Verdict: GO + PASS → status `to-ship`. (Autonomous run, no human; no confirmations were required.)

### Ship — 24-11-2026
- Readiness: OK to ship — no other IN_PROGRESS branch in Merge readiness, no declared dependencies, no foreign API entries; this feature's constraint is addressed in the shipped skills.
- Shared-context: this feature's Merge readiness row, Constraint and Decision removed (the indexed version had none of them, so nothing to stage).
- Migrations: Constraint (Claude Code `&&` subcommand permission matching, allowlist is not a security boundary) → `.buildit/guidelines/language-framework.md` "Known behaviours / constraints"; Decision (repeated subagent prompt text defined once as a named block) → `.buildit/guidelines/team-practices.md` "Subagent selection and workflow isolation".
- Retro: (1) Slowdown: the worktree permission rationale (D2) had to be amended mid-build once `&&` subcommand splitting was confirmed. (2) A guideline on Claude Code permission matching would have prevented it — now migrated. (3) The plan was precise (files, protected test blocks, ATs listed); no further config change needed.
