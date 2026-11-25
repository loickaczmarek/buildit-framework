# shared-context-local-state

## Status
to-ship

## Branch
feature/2026-11-25-shared-context-local-state

## Worktree path
/home/loic-kaczmarek/mission/build-it-framework/.worktrees/feature/2026-11-25-shared-context-local-state

## Goal
Make `.scratch/shared-context.md` untracked local state instead of a git-tracked file. Today it is tracked (committed by bootstrap) but feature rows are only ever written to the root working copy and never committed, so the committed version is always the empty template; yet `buildit-feature-ship` step 4 carries a whole mechanism (the "Shared-context rule", `git show :` + `git hash-object -w --stdin` + `git update-index --cacheinfo`, replaying removals on the worktree copy) to stage removals that are almost always empty, and the root file sits permanently modified (risk of accidental commit with other features' rows, checkout friction). The durable value — migrating Decisions & Conventions and durable Constraints into the guidelines — stays and is committed with the feature. shared-context.md coordinates worktrees on a single machine; document that explicitly.

## Acceptance Tests
1. `.scratch/shared-context.md` is listed in the repo `.gitignore` and removed from the index (`git rm --cached`, file kept on disk); `buildit-project-bootstrap` adds `.scratch/shared-context.md` to `.gitignore` when absent and its commit step no longer stages `.scratch/shared-context.md` (both Claude and generic variants).
2. `buildit-feature-start` creates `.scratch/shared-context.md` from the 4-section template (API & Contracts modified, Constraints discovered, Decisions & Conventions, Merge readiness with the `| Branch | Status | Main files touched |` table) when it is absent, instead of stopping and pointing to bootstrap. The template's four section headings are identical in start and bootstrap (locked by a cross-skill contract test).
3. `buildit-feature-build`, `buildit-feature-validate` and `buildit-feature-ship` no longer stop when `.scratch/shared-context.md` is absent: they treat it as empty (nothing to read, nothing to clean). Ship's prerequisite stop (0a) and its `## Last error` line for this case are removed; the "Deliberate stops" list in ship is updated accordingly.
4. `buildit-feature-ship` never stages or commits `.scratch/shared-context.md`: the "Shared-context rule", the `git hash-object` / `git update-index --cacheinfo` procedure, the "apply removals to the worktree's own copy" step and every `git add .scratch/shared-context.md` are gone. Ship still edits the project-root file (removes its Merge readiness row, its API section, migrates durable entries into guidelines/rules file then deletes them) and stages only the guideline/rules files it touched plus the archived tracking file.
5. The rule "Cleaning shared-context.md mandatory in the closing commit" is replaced, in `.claude/CLAUDE.md` and in bootstrap's rules-file templates (Claude and generic), by wording that says durable entries migrate into guidelines at ship time and shared-context.md is local, untracked state.
6. README: the "Parallel coordination" section states that shared-context.md is local untracked state coordinating worktrees on a single machine; the ship "Stage the closing changes" description, the worktree "Working directory" paragraph and any other mention of committing shared-context are updated; `buildit-feature-start` description reflects creation-if-absent.
7. Tests: existing assertions about the removed mechanism are updated or removed; new assertions cover AT1–AT6 (section-scoped, using `tests/lib/assertions.sh` helpers, following the content-assertion convention in README "Running tests"); `bash tests/run-all.sh` passes.

Constraints: do not push, do not open a PR, do not switch the branch of the project root (`fix/audit`). No plan task for this feature.

## Plan

All edits happen inside the worktree (`skills/` is the single source; `.claude/skills` is a symlink to `../skills`, so dual deployment is automatic). Run tests with `cd <worktree> && bash tests/run-all.sh`; git with `git -C <worktree>`.

### Step 0 — Failing tests first (TDD)
Write/adjust the assertions below before touching skills, run the suite, confirm the new ones fail for the right reason.

- `tests/test-buildit-project-bootstrap.sh` (AT1, AT5):
  - Step 9 (Commit) section: `require_absent`-style scoped check that the staging block no longer contains `.scratch/shared-context.md` (both the Claude and Generic `git add` lines).
  - Step 9 (or the step that handles `.gitignore`) instructs appending `.scratch/shared-context.md` to `.gitignore` when absent, and stages `.gitignore`.
  - Rules-file template(s) (the `` `<rules-file>`: `` block — check whether a separate generic template exists; if there are two, test both): absent "Cleaning shared-context.md mandatory in the closing commit"; present wording "local, untracked" + "migrate into the appropriate guideline at ship".
  - Shared-context template block still has the four headings.
- `tests/test-buildit-feature-start.sh` (AT2): replace AT-6 (stop when missing) with: prerequisite/step 0 section says create from template when absent; absent the "run `/buildit-project-bootstrap`" stop; the template block contains the 4 headings and the `| Branch | Status | Main files touched |` header. Update AT-1 if needed.
- `tests/test-buildit-feature-build.sh` AT-9, `tests/test-buildit-feature-validate.sh` AT-12, `tests/test-buildit-feature-ship.sh` AT-6 (AT3): replace "stops if missing" with "absent → treated as empty, no stop" (scoped to the step that reads shared-context); assert absence of the stop message in those skills.
- `tests/test-buildit-feature-ship.sh` (AT3, AT4):
  - absent `### 0a. Prerequisite check` heading, absent `shared-context.md not found`; Deliberate stops paragraph no longer lists "prerequisite check (0a)".
  - Remove/rewrite AT-CC-1 (shared-context rule), AT-CC-3 shared-context staging line, AT-CC-5 README "only this feature's removals".
  - New: whole-skill `require_absent` for `Shared-context rule`, `hash-object`, `update-index`, `git (-C [^ ]+ )?add \.scratch/shared-context\.md`, "worktree's own"; step 4 section states shared-context.md is never staged (local, untracked); step 2 section still edits the project-root file (Merge readiness row removal, API section, migrate-then-delete). Step 6 sentence "stays modified in the project root on purpose" replaced (file is untracked — never "modified").
  - Keep AT-CC-2 step ordering test (ship step numbering must stay: if 0a is removed, check nothing references `0a` anymore; keep 0b label or renumber — decision: keep `### 0b. Detect environment paths` unchanged to minimise churn? No: a dangling "0b" with no "0a" is confusing. Decision: rename `### 0b. Detect environment paths` → keep label `0b` only if tests/other skills reference it (grep `0b` in ship, run, README, tests first); otherwise rename to `### 0a. Detect environment paths` and update every reference, including the Deliberate stops list "migration note (0b)".)
- `tests/test-cross-skill-contracts.sh`:
  - AT-6 prerequisite-stop loop (lines ~110-116): restrict to `buildit-project-audit` only (audit keeps its stop — out of scope) or drop the loop for start/build/validate/ship and add a loop asserting they do NOT contain the stop message.
  - AT-7 ship 0a Last error assertions (~249-250): remove.
  - AT-7 team-practices worktree paragraph assertions (~297-305): rewrite — paragraph says shared-context.md is untracked local state and is never staged; absent "removals are applied to the worktree's own".
  - New AT2 contract: the four `## ` headings of the shared-context template block in start equal (same ordered list) those in bootstrap's `` `.scratch/shared-context.md`: `` block. Use `named_block`/`fenced_block` extractors from `tests/lib/assertions.sh` (check their signatures first) and compare `grep '^## '` output with `same`.
  - New AT1 contract on the repo itself: `.gitignore` contains a line `.scratch/shared-context.md`, and `git ls-files --error-unmatch .scratch/shared-context.md` fails (not tracked). Guard: run git from the test's repo root (`git -C "$ROOT"`), skip gracefully only if not a git repo.
- `tests/test-readme.sh` (AT6): Parallel coordination section contains "local", "untracked", "single machine"; absent "Cleanup happens in each feature's closing commit"; ship "4. Stage the closing changes" paragraph absent "update-index", "only this feature's removals", states shared-context is never staged; worktree "Working directory in worktree mode" paragraph absent "worktree's own copy"; start section step 1 says created from the template when absent (absent "otherwise points to `/buildit-project-bootstrap`").
- `tests/test-skills-invariants.sh` sequential-access invariant: unchanged (start, build, ship still write).
- Check `tests/test-buildit-project-audit.sh` and discover tests stay green (audit untouched; discover reads shared-context — add "if absent, treat as empty" to discover? Not in ATs → leave discover's read untouched, but if trivial, a one-line "absent → nothing to note" is consistent; decision: leave out, YAGNI/scope).

### Step 1 — Repo state (AT1)
- Append `.scratch/shared-context.md` to `<worktree>/.gitignore`.
- `git -C <worktree> rm --cached .scratch/shared-context.md` (keeps the worktree copy on disk). Stage `.gitignore`.
- The project root copy is not touched by this step; note that when the feature branch is merged into a checkout where the file is unmodified, git deletes it from disk — start recreates it (AT2) and build/validate/ship treat absence as empty (AT3), so this is safe. If the root copy holds rows at merge time, git refuses the merge ("local changes would be overwritten") → document the workaround in the README Parallel coordination section: back the file up / move it aside before merging the change that untracks it, then restore it (one-time migration note).

### Step 2 — buildit-project-bootstrap (AT1, AT5)
- Step 2 detection list: keep `.scratch/shared-context.md` (bootstrap still creates it from the template locally).
- Step 9: add "if `.gitignore` does not already list `.scratch/shared-context.md`, append it (local coordination state, never committed)" for both modes (next to the existing `.claude/settings.local.json` rule, but mode-independent). Generic mode must stage `.gitignore` too (currently only the Claude block has `git add .gitignore`) → add `git add .gitignore` under "Both modes" or the Generic block.
- Remove `.scratch/shared-context.md` from both `git add` lines.
- If the project already tracks it (re-bootstrap of an existing project): add `git rm --cached --quiet --ignore-unmatch .scratch/shared-context.md` in step 9 so the resync migrates existing projects. (Self-critic: required, otherwise .gitignore has no effect on an already-tracked file.)
- Rules-file template: replace "Cleaning shared-context.md mandatory in the closing commit" with e.g. "shared-context.md is local, untracked state (gitignored) coordinating worktrees on a single machine — never committed" and change "Durable constraints → migrate into the appropriate guideline at commit" to "...at ship time (committed with the feature)". Check whether bootstrap holds a separate generic rules template (grep "Cleaning shared-context" — only one occurrence found at line 344, so one template serves both modes; verify).
- `language-framework.md` design-spec template line "[automatically enriched via shared-context.md at merge]" — leave (not about committing).

### Step 3 — buildit-feature-start (AT2)
- Replace step 0 "Prerequisite check" stop with "Ensure shared-context.md exists": if absent, create it from the template (embed the same 4-section template as bootstrap, verbatim incl. comments) — local, untracked; no bootstrap needed.
- Timing (self-critic): creation must not happen before the feature name / existing-tracking-file check if that would leave artefacts? Creating an empty template is harmless (untracked, idempotent) — keep it at step 0 so step 1 can read it. Document "creating it is not a start artefact; a failed start may leave the empty template".
- Update description frontmatter ("initialises shared-context entry" → mention creates shared-context.md if absent) — keep quoted (test-quote-skill-descriptions).
- Step 1 unchanged.

### Step 4 — build, validate, ship absent-handling (AT3)
- build step 0: replace stop with "If `.scratch/shared-context.md` does not exist, treat it as empty: nothing to read in step 'API & Contracts', and the practice capture step creates it from the template in `buildit-feature-start` step 0 only if it needs to write" — simpler: build's capture step writes Decisions & Conventions; if absent, create it from the `buildit-feature-start` template first. Keep wording short. Rename step heading accordingly (e.g. `### 0. Shared context`), or remove step 0 and put the "absent = empty" note in the read step. Check tests referencing `### 0. Prerequisite check` in build/validate first (cross-skill loop greps `Prerequisite check`).
- validate step 0b: same — absent = no constraints to check. Staging guard sentence "(tracking file and `shared-context.md` are workflow state, modified by this skill and committed by ship)" → shared-context.md is untracked/gitignored, so it never shows in porcelain; reword to "tracking file is workflow state committed by ship; shared-context.md is gitignored local state".
- ship: delete `### 0a. Prerequisite check`; step 1 readiness: "absent → treat as empty (no rows, no overlaps)"; step 2: "If absent, nothing to clean — skip"; Deliberate stops paragraph: drop "the prerequisite check (0a)". Renumber per Step 0 decision. Check `buildit-feature-run` for any reference to ship's 0a stop / `shared-context.md not found` (grep) and README too.

### Step 5 — ship never stages shared-context (AT4)
- Step 4: delete the Shared-context rule paragraph and both Shared-context bullets; add one line: "`.scratch/shared-context.md` is never staged: it is gitignored local state; step 2 edited the project-root copy only."
- Step 2 intro: keep "Edit the project root `.scratch/shared-context.md`"; ensure the migrations land in the worktree.
- Step 6: replace "`shared-context.md` stays modified in the project root on purpose" with "`shared-context.md` stays in the project root — it is untracked local coordination state."
- End of skill line "Commit done, shared-context cleaned." fine.
- Grep whole skill for `hash-object`, `update-index`, `git show :`, "worktree's own".

### Step 6 — Rules & guidelines (AT5 + consistency)
- `.claude/CLAUDE.md` Parallel coordination: replace "Cleaning `shared-context.md` mandatory in the closing commit" with the same wording as the bootstrap template (backticked variant).
- `.buildit/guidelines/team-practices.md` worktree paragraph (line ~21): remove the "shared-context removals are applied to the worktree's own `shared-context.md`, and the root `shared-context.md` is never copied" clause → "shared-context.md is gitignored local state edited only in the project root and never committed".
- `.buildit/guidelines/language-framework.md` Parallel coordination: add "local, untracked (gitignored), single machine".

### Step 7 — README (AT6)
- Parallel coordination section: add local/untracked/single-machine statement; replace "Cleanup happens in each feature's closing commit" with "ship cleans this feature's entries in the local file and commits only the guideline migrations"; add the one-time migration note (Step 1).
- Bootstrap section (line ~342/353): mention it gitignores `.scratch/shared-context.md` and untracks it on resync.
- Start section: step 1 → "Creates `.scratch/shared-context.md` from the 4-section template if absent".
- Build/validate sections if they mention the stop.
- Ship: "4. Stage the closing changes" — drop the Shared-context rule / update-index sentence, state shared-context.md is never staged; ship step list "1. Readiness check" — absent = empty; remove any 0a mention.
- Worktree "Working directory in worktree mode": drop "applies this feature's `shared-context.md` removals to the worktree's own copy..." → "shared-context.md is never committed".
- Diagrams lines 51/56/71/94 ("init shared-context", "shared-context cleanup") — fine as is.

### Step 8 — Verify & stage
- `cd <worktree> && bash tests/run-all.sh` green.
- Final grep across worktree (excluding `.scratch/done/`, `docs/buildit/reviews`): `hash-object|update-index|Shared-context rule|closing commit.*shared|shared-context.*closing commit|worktree's own` → no hits in skills/README/guidelines/CLAUDE.md.
- Stage every modified file by explicit path with `git -C <worktree> add`, plus the `rm --cached` deletion; `git -C <worktree> status --porcelain` shows no unstaged/untracked relevant file. Then status `to-validate`.

### Self-critique (applied above)
- Assumption "one rules template in bootstrap": verify by grep — if a generic-specific template exists, edit both (AT5 says both variants).
- Edge: re-bootstrap of an already-tracking project — `.gitignore` alone doesn't untrack; added `git rm --cached` to bootstrap step 9.
- Edge: Generic mode bootstrap commit did not stage `.gitignore` — must now, or the ignore entry is left uncommitted.
- Edge: merging this branch deletes the root copy (or refuses the merge if it holds rows) — mitigated by AT2/AT3 and a README migration note.
- Edge: this feature's own ship runs the base-branch (old) ship skill from the project root: its step 4 would try to stage `.scratch/shared-context.md` in the worktree; `git add` on a now-ignored, untracked path errors ("paths are ignored"). Ship operator must skip that bullet (nothing to stage) — note it in Progress at to-validate time so ship knows.
- Edge: `buildit-project-audit` and `buildit-feature-discover` still read/stop on shared-context — out of AT scope; audit keeps its prerequisite stop (pointing to bootstrap, which still creates it). Cross-skill prerequisite loop must be narrowed to audit, not deleted silently. Flag as a possible follow-up.
- Risk: step renumbering in ship (0a removal) can break tests and README references to "0b" — grep `0a`/`0b` across skills, README, tests before choosing.
- Risk: `tests/test-tracking-file-discovery.sh` AT-2 still requires `shared-context.md` mentioned in the discovery rule — unaffected.
- Vague step guard: each test change is named with the file and the assertion; extractor signatures (`section`, `named_block`, `fenced_block`) must be checked in `tests/lib/assertions.sh` before use.

## Progress

### Build — 25-11-2026
- TDD: new/updated assertions written first (ship AT-6/AT-CC-1/3/5, build AT-9, validate AT-12, start AT-6/AT-ORD-1, bootstrap AT-SCL-*, cross-skill AT-SCL-1/2/3/5 + AT-7 rewrites, README AT-SCL-6); confirmed failing on assertions, then implemented. `bash tests/run-all.sh`: 1288 passed, 0 failed.
- Repo: `.scratch/shared-context.md` appended to `.gitignore`, removed from the index with `git rm --cached` (file kept on disk in the worktree).
- Ship: `### 0a. Prerequisite check` removed; `### 0b. Detect environment paths` renumbered `### 0a.` (no external reference to ship's 0b — checked skills, README, tests); Deliberate stops now lists "the migration note (0a)" and the base-branch stop. Steps 1 and 2 treat an absent file as empty. Step 4: Shared-context rule, hash-object/update-index procedure and both Shared-context bullets removed, replaced by one line "never staged: gitignored local state". Step 6 wording updated.
- Build: step 0 is now "Path shorthand" only; step 2 treats an absent file as empty; step 4 creates it from start's step 0 template before writing a Decisions entry. Validate: `### 0b. Prerequisite check` removed; step 2 treats absent as empty; staging guard wording updated.
- Start: step 0 "Ensure shared-context.md exists" embeds bootstrap's template verbatim (contract test asserts identical blocks + the four headings in order); description updated.
- Bootstrap: step 9 gitignores `.scratch/shared-context.md` in both modes, untracks it (`git rm --cached --quiet --ignore-unmatch`) for resync of existing projects, `git add .gitignore` moved under "Both modes"; shared-context removed from both `git add` lines; rules-file template rule replaced. `.claude/CLAUDE.md` rule replaced identically (backticked).
- Guidelines: team-practices worktree paragraph and language-framework Parallel coordination updated. README: Parallel coordination (local/untracked/gitignored/single machine + one-time migration note), bootstrap step 9, start step 1, build step 2, ship steps 1 and 4, worktree working-directory paragraph. Also aligned `docs/buildit/specs/2026-11-24-worktree-mode-design.md` ("Ship carries only this feature's state").
- Out of scope, untouched: `buildit-project-audit` keeps its prerequisite stop (cross-skill loop narrowed to audit); `buildit-feature-discover` reads shared-context without an absent-handling note (possible follow-up).
- **Note for ship of THIS feature:** ship runs from the project root (`fix/audit`, old ship skill). Its step 4 Shared-context bullet would `git -C <worktree> add .scratch/shared-context.md` — the path is now gitignored and untracked in the branch, so skip that bullet (nothing to stage). The staged deletion `D .scratch/shared-context.md` is intentional. When this branch is later merged into a checkout whose root `shared-context.md` holds rows, move the file aside before the merge and restore it afterwards (README one-time migration note).
- No new shared-context Decisions entry: the convention is written directly into the guidelines/rules files by this feature.
