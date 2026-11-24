# task-start-step-ordering

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 finding #8. `buildit-feature-start` step 0 creates the worktree before the shared-context prerequisite check (0b) and before the feature name is collected (step 2). Without an argument this creates branch `feature/YYYY-MM-DD-` (empty slug); on a non-bootstrapped project it leaves an orphan worktree and blocks a same-day retry. `buildit-worktree` also commits `.gitignore` with a plain `git commit`, sweeping in anything already staged.

Fix: reorder start so the worktree is created only after the prerequisite check and the feature name collection; make `buildit-worktree` refuse an empty feature name and commit only `.gitignore` via a pathspec.

Files: `skills/buildit-feature-start/SKILL.md`, `skills/buildit-worktree/SKILL.md` (plus tests and the README skill descriptions that list the step order).

Context to preserve — the `## Branch` contract: tracking file section with bare branch name after `## Status` and before `## Worktree path`; start step 3 writes it once — from buildit-worktree step 4's `Branch: <BRANCH>` line in worktree mode, else `git branch --show-current`, stopping if HEAD is detached without worktree; start step 5 is the only writer of the Merge readiness row and runs after worktree and tracking file exist. `.claude/skills` is a symlink to `../skills`. Skill files in English. README headings must stay unique (tests/test-readme.sh AT-R9).

## Acceptance Tests
- AT-1: start's step order is prerequisite check → feature name collection → worktree question/creation.
- AT-2: `buildit-worktree` refuses an empty feature name.
- AT-3: `buildit-worktree` commits only `.gitignore` (`git commit -m ... -- .gitignore`).
- AT-4: tests assert AT-1 to AT-3; `bash tests/run-all.sh` passes.

## Plan

### Decisions (taken autonomously — nobody available to answer)
- D1: Worktree mode = no; working directly on `fix/audit` as instructed by the caller.
- D2: Keep step numbers 3 (tracking file) and 5 (Merge readiness) stable, because `buildit-feature-ship` cites "`buildit-feature-start` step 3" for the `## Branch` contract and tests extract `### 5.`. New start order:
  - `### 0. Prerequisite check` (was 0b)
  - `### 1. Read shared-context.md` (unchanged)
  - `### 2. Collect feature information` (unchanged)
  - `### 2b. Worktree?` (was 0) — runs once the feature name is known
  - `### 3. Generate the tracking file` … `### 5.` unchanged.
- D3: README headings are not changed (only the numbered "What it does" lists), so AT-R9 heading uniqueness is unaffected.

### Steps (TDD)
1. Failing tests first:
   - `tests/test-buildit-feature-start.sh`: AT-ORD-1 — line of the prerequisite-check heading < line of `### 2. Collect feature information` < line of the `Worktree?` heading; also assert the worktree heading is not `### 0.` and that `buildit-worktree [feature-name]` is invoked within the worktree step (after collection). AT-ORD-2 — the worktree step states the name is already collected (regex e.g. `feature name.*(collected|known)`).
   - `tests/test-buildit-worktree.sh`: AT-EMPTY — skill contains a refusal for an empty feature name (regex `[Ee]mpty feature name|feature-name.*empty`, plus a `stop` wording). AT-COMMIT — contains `git commit -m "chore(git): ignore .worktrees/ directory (worktree isolation)" -- .gitignore`; require_absent of a plain `git commit -m "chore(git): ignore .worktrees/ directory (worktree isolation)"$` line (regex anchored at end of line).
   - Run both test files → confirm the new assertions fail.
2. Edit `skills/buildit-feature-start/SKILL.md`:
   - Move "0b. Prerequisite check" to top as `### 0. Prerequisite check`.
   - Move the worktree section after step 2 as `### 2b. Worktree?`; open with "Runs only after the prerequisite check passed and the feature name is collected (step 2), so a failed start never leaves an orphan worktree or a `feature/YYYY-MM-DD-` branch." Keep the Yes/No bullets verbatim (Branch: <BRANCH> capture, git branch --show-current, detached HEAD stop) but change "Then continue to step 1" → "Then continue to step 3".
   - Step 2: if no argument, the slug must be non-empty kebab-case; re-ask if empty.
   - Step 5: "after the worktree exists (step 0)" → "(step 2b)".
   - "When to use" section is fine.
3. Edit `skills/buildit-worktree/SKILL.md`:
   - New guard at top of step 0 (or a `### 0. Validate the feature name` sub-bullet before deriving): if `feature-name` is empty/whitespace-only, stop with "Empty feature name — pass a kebab-case slug: `/buildit-worktree <feature-name>`." and create nothing (no branch, no worktree, no `.gitignore` change).
   - Step 1: `git commit -m "chore(git): ignore .worktrees/ directory (worktree isolation)" -- .gitignore` plus a note: the pathspec commits only `.gitignore`, never other already-staged changes.
4. README: update `buildit-feature-start` "What it does" list order (prereq check → read shared context → collect → worktree → …); `buildit-worktree` list: mention empty-name refusal and that the `.gitignore` commit uses `-- .gitignore`. No heading changes.
5. Run `bash tests/run-all.sh` → all green. Also grep for other references to start's "step 0"/"0b" (feature-run, discover) and adjust if any point to start.
6. `git add` the modified skill/test/README files and the tracking file (never `.scratch/24-11-2026-audit-issues.md` nor `.scratch/plan/`).

### Self-critique (applied)
- Assumption: other skills reference start's step numbers. Checked: only ship cites "step 3" — kept stable (D2). `buildit-feature-run` collects the worktree answer itself before launching start and passes "Use worktree: yes/no"; start's ordering change does not affect it, but verify run's text doesn't say "start step 0".
- Edge case: argument provided but whitespace-only/empty → step 2 must treat as missing and ask; buildit-worktree guard is the second line of defence.
- Edge case: `git commit -- .gitignore` when `.gitignore` did not previously exist (untracked) — pathspec commit of an untracked path fails unless it is added first; the plan keeps `git add .gitignore` before the commit, so `--` pathspec works (path is in the index). Keep `git add .gitignore`.
- Edge case: `git commit -- <path>` (`--only` semantics) commits the working-tree content of `.gitignore` even if other hunks were not staged — acceptable, the file is what we just edited.
- Risk: test ordering assertion via `grep -n` must target headings (`^### `) to avoid matching prose that mentions "Worktree?" earlier (e.g. step 5 text). Use `grep -nE '^### [0-9]+b?\. Worktree'`.
- Risk: existing AT-BR-2 checks step 5 contains "after the worktree" — keep that phrase.
- Vague step clarified: AT-EMPTY regex must match the actual wording chosen in step 3 — write the wording and the test together.

## Progress
- 24-11-2026 build (TDD): added AT-ORD-1/2 to `tests/test-buildit-feature-start.sh` and AT-EMPTY/AT-COMMIT to `tests/test-buildit-worktree.sh`; confirmed all 8 new assertions failed on assertion before the edits.
- Start reordered: `### 0. Prerequisite check` → `### 1.` → `### 2. Collect` (empty name re-asked) → `### 2b. Worktree?` → steps 3–5 unchanged; step 5 now cites step 2b.
- `buildit-worktree` step 0 refuses an empty/whitespace-only name and creates nothing; step 1 commits with `-- .gitignore` (kept `git add .gitignore` so an untracked `.gitignore` is in the index).
- README "What it does" lists updated for start (8 items) and buildit-worktree; no heading changes.
- Grep confirmed no other skill cites start's step 0/0b (discover/ship/validate/audit "0b" are their own steps).
- `bash tests/run-all.sh`: 704 passed, 0 failed.
- Build decisions: B1 — plan step 6 said to stage the tracking file, but the build skill (step 5) says `.scratch/` files are committed by ship and must not be staged here; followed the skill, so nothing under `.scratch/` is staged. B2 — no new practice introduced, `shared-context.md` Decisions & Conventions left untouched.
- 24-11-2026 validate: staging guard clean (only `.scratch/` entries unstaged/untracked, ignored by design); `bash tests/run-all.sh` 704 passed, 0 failed; no `.buildit/config.md`, so tests came from the `tests/run-all.sh` fallback and base branch defaulted to `main`. Review GO on all 6 dimensions (staged diff: start reorder 0 → 1 → 2 → 2b, worktree empty-name guard + `-- .gitignore` pathspec, README lists, AT-ORD/AT-EMPTY/AT-COMMIT tests). Acceptance: AT-1 PASS (headings 0 Prerequisite → 2 Collect → 2b Worktree; invocation inside 2b), AT-2 PASS (step 0 stop, creates nothing), AT-3 PASS (`git commit -m ... -- .gitignore`, `git add` kept for an untracked file), AT-4 PASS (tests cover AT-1..3, suite green). Non-blocking: `buildit-feature-run` asks the worktree question up front itself, which is consistent since it passes the collected name to start; the only remaining "step 0" reference to start is in a historical review doc (`docs/buildit/reviews/2026-10-14-skills-audit.md`), left as is.

## Retro
- Readiness: ✓ OK to ship — only this feature's own Merge readiness row; no other IN_PROGRESS branch, no API/constraint entries. Base branch defaulted to `main` (no `.buildit/config.md`).
- Shared-context: removed the `fix/audit` row (never committed, so nothing to stage); no constraints or decisions to migrate.
- What slowed the loop: only the plan's step 6 asking to stage the tracking file, which contradicts the build skill (`.scratch/` is committed by ship) — resolved at build (B1) at no cost.
- Config that would have prevented it: none needed — the build skill already states the rule; no guideline update.
- Plan precision: sufficient — the step-number stability decision (D2) and the heading-anchored test regex avoided rework; build and validate passed in one cycle.
