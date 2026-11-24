# task-worktree-working-directory

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 findings #4, #7 (full audit: `.scratch/24-11-2026-audit-issues.md`).

The "Working directory" notes in build and validate only redirect code edits and git commands to the worktree: the test command runs in the project root on base-branch code (new tests never execute → false GO), and run tells subagents to use relative paths from `[PROJECT_ROOT]`. Validate 5a (config update on NO-GO) writes rules/guideline files in the root without staging, so the next validate cycle NO-GOs on its own output and the rules never reach the feature commit.

Also known open item: build and validate still list `commit --amend` in their working-directory sentence (ship no longer amends since commit 3137082) — fix that wording too.

Files: `skills/buildit-feature-validate/SKILL.md`, `skills/buildit-feature-build/SKILL.md`, `skills/buildit-feature-run/SKILL.md`, plus tests.

## Acceptance Tests
- AT-1: build and validate state that the test command runs with the worktree as working directory when `## Worktree path` is not `none`.
- AT-2: run's subagent prompts no longer instruct running test scripts relative to the project root in worktree mode.
- AT-3: validate 5a writes `<rules-file>` and guideline edits inside the worktree when applicable (mirroring ship's migration wording) and stages them.
- AT-4: the staging guard no longer NO-GOs on files validate 5a itself updated.
- AT-5: tests assert AT-1 to AT-4; `bash tests/run-all.sh` passes.

## Plan

Context / constraints:
- Work directly on branch `fix/audit` (no worktree). `.claude/skills` is a git-tracked symlink to `../skills` — edit `skills/` only.
- Skill text in English. Do not add new `.buildit/config.md` reads (Config value rule wording enforced by `tests/test-config-parsing-boundary.sh`); `.buildit/config.md` stays read from the project root.
- Do not stage/commit `.scratch/24-11-2026-audit-issues.md` or `.scratch/plan/`.
- Existing `tests/test-buildit-feature-ship.sh` AT-CC-2 already asserts ship has no `commit --amend`; the same `require_absent` pattern is reused for build/validate.

### Step 1 — Failing tests first
Add a section `# --- Worktree working directory (AT-WD-*) ---` to each existing per-skill test file:

`tests/test-buildit-feature-build.sh`:
- AT-WD-1: the `**Working directory:**` line states the test command runs with the worktree as working directory — regex on that line: `[Tt]est.*worktree as (the )?working directory` (or `cd <worktree-path>`).
- AT-WD-amend: `require_absent ... 'commit --amend'`.

`tests/test-buildit-feature-validate.sh`:
- AT-WD-1: same regex on validate's `**Working directory:**` line; additionally the test-suite step (section `### 2b. Run test suite` → next `### `) says Tier 2 ecosystem markers are checked in the worktree (regex `worktree` inside that section).
- AT-WD-amend: `require_absent ... 'commit --amend'`.
- AT-WD-3: section `### 5a.` → `### 5b.` contains `inside the worktree in worktree mode, in the project root otherwise` (ship's wording, step 2) and `git [-C <worktree-path>] add` and mentions `<rules-file>`.
- AT-WD-4: staging-guard section (`### 2a.` → `### 2b.`) uses `git [-C <worktree-path>] status --porcelain` and says files updated by step 5a are staged by 5a (regex `5a.*staged|staged.*5a`).

`tests/test-buildit-feature-run.sh`:
- AT-WD-2: build, validate and ship prompts — the `[If use-worktree=yes]` line instructs running test/script commands with the worktree as working directory (`cd <worktree-path> && `), counted: at least 3 occurrences of the new instruction text.
- AT-WD-2b: `require_absent` on the old pair "Use relative paths for script invocations. Do not cd outside" (without worktree qualification) in the build/validate/ship prompts — implemented as a grep count: the old exact sentence `Use relative paths for script invocations. Do not cd outside the project root` must not appear (start prompt has a different form `(e.g. \`bash tests/…\`)` and is untouched).

Run `bash tests/run-all.sh` → the new assertions fail, old ones pass.

### Step 2 — build `skills/buildit-feature-build/SKILL.md`
Rewrite the `**Working directory:**` paragraph:
- git command list → `(add, status, diff)`; drop `commit`, `commit --amend` (build does not commit; ship commits).
- Add: "Run the test command with the worktree as working directory (`cd <worktree-path> && <test command>`) — the project root holds base-branch code, so tests run there never see this feature's changes."

### Step 3 — validate `skills/buildit-feature-validate/SKILL.md`
1. Same `**Working directory:**` rewrite (git list `(add, status, diff)`; test command sentence). Also say `<rules-file>` and `<guidelines-dir>` edits from step 5a go in the worktree.
2. Step 2a: `git [-C <worktree-path>] status --porcelain`; add a sentence: "Files updated by step 5a in a previous cycle are staged by 5a, so they pass the guard."
3. Step 2b: state the configured command (read from root `.buildit/config.md`) and Tier 2 markers are evaluated / run in the worktree in worktree mode (one sentence before Tier 1, not touching the Config value rule wording).
4. Step 5a: pass the subagent the worktree copies of the files in worktree mode; after "Apply the subagent's output to the files." add: "Make these edits to `<rules-file>` and `<guidelines-dir>` inside the worktree in worktree mode, in the project root otherwise, then stage each touched file with `git [-C <worktree-path>] add <file>...` — unstaged, the next cycle's staging guard would NO-GO on them and the rules would never reach the feature commit."

### Step 4 — run `skills/buildit-feature-run/SKILL.md`
For build, validate and ship prompts, replace the autonomy block's worktree line with:
`[If use-worktree=yes]: Run test and script commands with the worktree as working directory (\`cd <worktree-path> && bash tests/…\`), never from the project root — it holds base-branch code. For git commands inside the worktree, use \`git -C <worktree-path>\` instead of cd. The following permission is required in settings.json: \`Bash(cd */.worktrees/* && *)\``
and change "Use relative paths for script invocations." to "Use relative paths for script invocations (relative to the worktree in worktree mode)." Start prompt unchanged (start runs no tests; the worktree does not exist yet when it is launched).

### Step 5 — Verify and stage
`bash tests/run-all.sh` passes; stage the three skills and three test files with explicit paths; `.scratch/` not staged.

### Self-critique (corrections applied above)
- Assumption: "test command" in build is implicit (build has no detection step, only "re-run the tests"). → The rule lives in the `**Working directory:**` note, which covers every test run in build.
- Edge: Tier 2 detection checks marker files (`tests/run-all.sh`, `package.json`, …) — in the root they reflect base-branch state; a feature adding `package.json` would be missed. → Step 3.3 makes detection run in the worktree.
- Edge: in non-worktree mode, `git add <rules-file>` in 5a could stage pre-existing unrelated user edits to `.claude/CLAUDE.md`. Accepted (same behaviour as ship step 4); not worth extra machinery.
- Edge: in worktree mode, rules written to the worktree copy do not apply to the current root session until merge. Accepted — mirrors ship's migration; the goal is that they reach the feature commit.
- Risk: AT-4 depends on AT-3 (staging in 5a is what makes the guard pass). Rather than adding an exemption list to the guard (complex, could hide real unstaged edits), the guard stays strict and 5a stages — decision recorded.
- Risk: the start prompt also says "Use relative paths for script invocations (e.g. `bash tests/…`)". Decided to leave it: start runs no tests and the worktree path is unknown at launch. The run test must not break on it (match the exact old build/validate/ship sentence only).
- Vague step avoided: test regexes are scoped to extracted sections (awk between headings), like existing AT-SC tests.

## Decisions
- Existing AT-STAGE-1/AT-STAGE-3 in `tests/test-buildit-feature-validate.sh` now match `status --porcelain` (not the literal `git status --porcelain`) since the guard uses `git [-C <worktree-path>] status --porcelain`.
- Validate 5a also passes the subagent the worktree copies of the config files in worktree mode.
- No exemption list in the staging guard; validate 5a stages its own edits instead (keeps the guard strict).
- Start prompt in run left unchanged (no tests run in start).
- `commit` dropped from build/validate git lists along with `commit --amend` (neither phase commits).

## Progress

### Build — 24-11-2026
- Tests added (AT-WD-*) in build/validate/run test files; failed first for the right reasons, then implemented.
- `bash tests/run-all.sh`: 716 passed, 0 failed.
- No new practice; shared-context unchanged.

### Validate — 24-11-2026
- Staging guard: clean (only `.scratch/` entries unstaged/untracked; the 6 feature files are staged-only).
- Tests: `bash tests/run-all.sh` (Tier 2, no `.buildit/config.md`) — 716 passed, 0 failed.
- Review (staged diff on top of HEAD, 6 dimensions): GO. Correctness: build/validate working-directory notes run tests in the worktree and drop `commit`/`commit --amend`; validate 2a/2b/5a worktree-aware, 5a stages its edits; run build/validate/ship prompts run tests from the worktree. No performance/security concerns. Style and craft: wording mirrors ship's migration sentence; guard stays strict (no exemption list — KISS). Tests scoped to extracted sections with negative assertions for superseded wording.
- Acceptance: AT-1 PASS (build + validate `**Working directory:**` lines, validate 2b), AT-2 PASS (old root-relative sentence absent from build/validate/ship prompts; start prompt untouched, runs no tests), AT-3 PASS (5a: "inside the worktree in worktree mode, in the project root otherwise" + `git [-C <worktree-path>] add`), AT-4 PASS (2a notes 5a-staged files pass), AT-5 PASS (AT-WD-* assertions, 716/0).
- Non-blocking notes (bugfix → README not required per team-practices Documentation table): README `buildit-worktree` "Working directory in worktree mode" paragraph (README.md:591) does not mention running tests in the worktree; README validate section NO-GO step 1 does not mention 5a staging its edits; README autonomy block (README.md:167) was already out of sync with run's prompts before this feature. Candidates for a later doc pass.
- Verdict: GO + PASS overall → status `to-ship`.

### Ship — 24-11-2026
- Readiness: OK to ship (only this feature's own Merge readiness row; no dependencies, API or constraint entries).
- Shared-context: removed the `fix/audit` row (working file now identical to HEAD — nothing to stage). No constraints or decisions to migrate.
- Retro: no notable slowdown; plan was precise (test regexes scoped per section). No configuration change needed. Open (non-blocking): README worktree/validate/autonomy paragraphs not yet aligned (see validate notes).
