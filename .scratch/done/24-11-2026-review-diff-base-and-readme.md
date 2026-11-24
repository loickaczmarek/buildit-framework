# review-diff-base-and-readme

## Status
to-ship

## Worktree path
none

## Goal
Two fixes and a README overhaul.

1. Review diff covers staged work and a configurable base branch.
   - In buildit-feature-validate step 3, replace `git diff main...HEAD` with `git diff --cached --merge-base <base-branch>`. This covers both the branch commits and the staged changes, which is where the work sits at validate time because build stages but never commits.
   - Do the same for the feature's file list in buildit-feature-ship step 1: `git diff --cached --merge-base <base-branch> --name-only`.
   - The other-branch overlap check becomes `git diff --name-only --merge-base <base-branch> <branch>`. It only sees commits; that limitation is documented.
   - Add the fallback `git diff --cached $(git merge-base <base-branch> HEAD)` for git < 2.30.
2. `## Base branch` in .buildit/config.md. The value is the first non-empty, non-comment line, the same convention as `## Test command`. It defaults to `main` when absent or empty. validate and ship read it. buildit-project-bootstrap auto-detects it from `git symbolic-ref refs/remotes/origin/HEAD` (falling back to main), proposes it for confirmation, and adds it to the config.md template. language-framework.md documents the key.
3. Staging guard in validate. Before the review, run `git status --porcelain`. If untracked or unstaged files remain, the review is a NO-GO listing those files, because code that isn't staged hasn't been reviewed. This follows the existing rule in .claude/CLAUDE.md that everything is staged before to-validate.
4. README:
   - Factual: remove both references to the deleted 2026-09-08-buildit-feature-run-design.md spec. Change the skill count to "10 skills (9 user-facing + the internal buildit-worktree)". Update the validate and ship wording to match the new diff and the staging guard.
   - Project configuration section: .buildit/config.md with `## Test command`, `## Base branch` and the 3 sync headings (`## Task synchronization`, `## Synchronization method`, `## Synchronization tag`), the rule that unconfigured is not the same as disabled, the ban on secrets, which skill writes each key, and an example file.
   - Plan files section: format of plan.md and task-{name}.md, the status lifecycle todo → in-progress → done, readiness, the `## Synchronization` section (Link: / Pending:), and which skill owns which field (run → Status, discover → Description/AT/Readiness, plan → full reconcile). The plan, discover and run steps are shortened to point to this section instead of repeating the sync details.
   - Structure & tests: move buildit-worktree into the skills list under an "Internal" subheading. Demote "Manual flow skills" so it is no longer a heading at the same level as the skills it introduces. Realign the manual-flow diagram. Add a "Running tests" part: `bash tests/run-all.sh`, the content-assertion convention, and tests/lib/assertions.sh.

## Acceptance Tests
- [ ] buildit-feature-validate step 3 uses `git diff --cached --merge-base <base-branch>` (with the git < 2.30 fallback) and no longer contains `main...HEAD`.
- [ ] buildit-feature-validate runs `git status --porcelain` before the review and issues a NO-GO listing the files when any are untracked or unstaged.
- [ ] buildit-feature-ship step 1 builds the feature's file list with `--cached --merge-base <base-branch>`, builds the other-branch lists with `--merge-base <base-branch> <branch>`, documents the commits-only limitation, and no longer contains `main...`.
- [ ] validate and ship read `## Base branch` from .buildit/config.md and fall back to main when it is absent or empty.
- [ ] buildit-project-bootstrap detects the base branch (origin/HEAD, falling back to main), proposes it for confirmation, and includes `## Base branch` in the config.md template.
- [ ] language-framework.md documents the `## Base branch` key.
- [ ] No SKILL.md contains a hardcoded `main...` or `main..HEAD` anymore.
- [ ] The README no longer references 2026-09-08-buildit-feature-run-design.md, and the skill count matches the number of directories in skills/ (with the internal skill noted).
- [ ] The README has a "Project configuration" section listing the 5 keys, the rule that unconfigured is not the same as disabled, and an example file.
- [ ] The README has a "Plan files" section with the task format, the status lifecycle, `## Synchronization` (Link: / Pending:) and field ownership. The plan, discover and run steps point to it.
- [ ] buildit-worktree sits in the skills list, the heading levels are consistent, the manual-flow diagram is aligned, and a "Running tests" part exists.
- [ ] The README descriptions of validate and ship mention the staged diff, the base branch and the staging guard.
- [ ] Content-assertion tests in tests/test-buildit-{feature-validate,feature-ship,project-bootstrap}.sh (and a README check) cover these criteria, the existing README assertions (AT-D13, AT-9, AT-SYNC-14) still pass, and tests/run-all.sh is green.

## Plan

Context facts (verified at start):
- `.claude/skills` is a tracked symlink to `../skills` (team-practices.md): edit `skills/` only, never `cp`; `diff -q` sanity checks in tests stay valid by construction.
- Only `skills/buildit-feature-validate/SKILL.md:70` and `skills/buildit-feature-ship/SKILL.md:48,51` contain `main...`. No `main..HEAD` in any SKILL.md.
- This repo has no `.buildit/config.md`; the convention is documented in `.buildit/guidelines/language-framework.md` "## Project configuration" and in the bootstrap step 8 template (`skills/buildit-project-bootstrap/SKILL.md` ~:409-431).
- `docs/buildit/specs/2026-09-08-buildit-feature-run-design.md` no longer exists. README references it at :325 and :498.
- Existing README tests that must stay green:
  - AT-D13 (`tests/test-buildit-feature-discover.sh`): `sed -n '/^### \`buildit-feature-discover\`/,/^---/p'` must contain `.scratch/plan/task-` and `needs-scoping`.
  - AT-SYNC-14 (`tests/test-buildit-plan.sh`): the README section from ``### `<skill>` `` to the next ``### ` `` for bootstrap, plan, discover and run must each contain "synchroniz" (case-insensitive); README must reference `2026-11-24-plan-task-synchronization.md`.
  - AT-9 (`tests/test-buildit-feature-run.sh`): README contains `buildit-feature-run`.
- git here is 2.43; `refs/remotes/origin/HEAD` is not set in this clone (detection must fall back to `main`).

### Step 1 — Failing tests first
1. `tests/test-buildit-feature-validate.sh` — add assertions (label prefix `AT-BASE-*` / `AT-STAGE-*`):
   - `require_text` `git diff --cached --merge-base <base-branch>`.
   - `require_text` fallback `git diff --cached $(git merge-base <base-branch> HEAD)` and `require_text` `2.30`.
   - `require_absent` `main...HEAD` and `main..HEAD`.
   - `require_text` `## Base branch`; `require_regex` default-to-main wording (e.g. `defaults? to .main.|fall(s)? back to .main.`).
   - `require_text` `git status --porcelain`; `require_regex` NO-GO + listing files wording; ordering check: line of `git status --porcelain` < line of `git diff --cached --merge-base` (guard runs before review reads the diff).
2. `tests/test-buildit-feature-ship.sh` — add:
   - `require_text` `git diff --cached --merge-base <base-branch> --name-only`.
   - `require_text` `git diff --name-only --merge-base <base-branch> <branch>`.
   - `require_regex` commits-only limitation (`only (sees|compares) commit|commits only|staged .* invisible|not visible`).
   - `require_text` git < 2.30 fallback (`git merge-base <base-branch>`).
   - `require_absent` `main...`; `require_text` `## Base branch` + default main regex.
3. `tests/test-buildit-project-bootstrap.sh` — add:
   - `require_text` `git symbolic-ref refs/remotes/origin/HEAD`; `require_regex` fall back to main; `require_regex` confirmation prompt (`Detected base branch`); `require_text` `## Base branch` (template); `require_text` on language-framework.md `## Base branch`.
4. New `tests/test-readme.sh` (sourced `tests/lib/assertions.sh`, picked up by `run-all.sh` glob) — assertions:
   - `require_absent` `2026-09-08-buildit-feature-run-design.md`.
   - Skill count: `N=$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l)`; README contains `$N skills` and `internal`.
   - `## Project configuration` heading exists; that section contains the 5 headings `## Test command`, `## Base branch`, `## Task synchronization`, `## Synchronization method`, `## Synchronization tag`, the phrase `unconfigured, not disabled` (case-insensitive variant acceptable via regex), `secret`, and a fenced example (```` ```markdown ````).
   - `## Plan files` heading exists; section contains `task-{name}.md`, `plan.md`, `todo`, `in-progress`, `done`, `Readiness`, `## Synchronization`, `Link:`, `Pending:`, and ownership of `buildit-feature-run`, `buildit-feature-discover`, `buildit-plan`.
   - The plan, discover and run README skill sections each contain a pointer `Plan files` (link `#plan-files`).
   - ``### `buildit-worktree` `` appears between `## Skills` and the next `## ` heading (inside the skills list) and an `Internal` subheading precedes it; no `(internal)` heading after "Continuous improvement loop".
   - `require_absent` regex `^### Manual flow skills`.
   - "Running tests" heading exists and contains `bash tests/run-all.sh` and `tests/lib/assertions.sh`.
   - Diagram alignment: within the Manual flow code block, every line containing a right-border `│` or `┐`/`┘` for the loop arrow has that char at the same display column (check with a small awk on character positions using `LC_ALL=C.UTF-8` / python3 fallback); keep the check simple: all loop-border chars share one column.
   - Validate section (`### \`buildit-feature-validate\``..`---`) contains `--cached --merge-base`, `Base branch` and `staging guard` (case-insensitive); ship section contains `--cached --merge-base` and `Base branch`.
5. Run each new/modified test file → confirm the new assertions FAIL and pre-existing ones still PASS.

### Step 2 — buildit-feature-validate (`skills/buildit-feature-validate/SKILL.md`)
1. Add a base-branch resolution (new sub-step `### 2a. Resolve base branch` after step 2 / before 2b, or inside step 3 preamble): read `.buildit/config.md`, value = first non-empty, non-comment line after `## Base branch`; if file/heading absent or value empty → `main`. Store as `<base-branch>`. If `git rev-parse --verify <base-branch>` fails → set status `to-fix`? No — this is an environment problem, not a code defect: stop with an explicit message asking to set `## Base branch` or fetch the branch (status left at `validating` is undesirable → restore `to-validate` before stopping).
2. Step 3 starts with **Staging guard**: run `git status --porcelain`; consider lines with untracked (`??`) or unstaged changes (second status column non-blank, e.g. ` M`, `MM`, ` D`), **excluding paths under `.scratch/`** (tracking file and shared-context.md are workflow state modified by validate itself and committed by ship). If any remain → review verdict NO-GO with the issue "Unstaged/untracked files — code that isn't staged hasn't been reviewed" listing each file; skip the diff review and the acceptance phase, go directly to the NO-GO path (Problems to fix lists the files with instruction to stage them; the §5a config-update subagent still runs per the NO-GO path, it will usually find the CLAUDE.md rule already present).
3. Replace `git diff main...HEAD` with `git diff --cached --merge-base <base-branch>`, explain it covers branch commits + staged changes, and give the git < 2.30 fallback `git diff --cached $(git merge-base <base-branch> HEAD)`.

### Step 3 — buildit-feature-ship (`skills/buildit-feature-ship/SKILL.md`)
1. Same base-branch resolution (self-contained text; skills have no include mechanism) at the start of step 1.
2. Feature file list: `git diff --cached --merge-base <base-branch> --name-only` (+ fallback `git diff --cached --name-only $(git merge-base <base-branch> HEAD)`).
3. Other branches: `git diff --name-only --merge-base <base-branch> <branch>` (+ fallback `git diff --name-only $(git merge-base <base-branch> <branch>) <branch>`). Document limitation: only committed work of the other branch is seen; files only staged in another worktree are invisible to the overlap check.
4. Ensure no `main...` remains.

### Step 4 — buildit-project-bootstrap (`skills/buildit-project-bootstrap/SKILL.md`)
1. Add `**4f. Base branch detection**` after 4e: run `git symbolic-ref refs/remotes/origin/HEAD` (strip `refs/remotes/origin/`); if it fails (no remote / origin/HEAD unset) → `main`. Propose: "Detected base branch: `[branch]`. Confirm or provide the correct branch:". Store under `## Base branch`.
2. Add "Base branch" to the coring summary list.
3. Add `## Base branch` block to the step 8 config.md template (comment: auto-detected, default main) and extend the convention sentence (empty → `main`).
4. Check step 6 diagnostic / README step 5 wording mention base branch where test command is mentioned.

### Step 5 — Guideline (`.buildit/guidelines/language-framework.md` "## Project configuration")
Add a paragraph: `## Base branch` — branch the review diff and overlap check compare against; read by validate and ship; default `main` when absent or empty; detected by bootstrap from origin/HEAD. Mention git ≥ 2.30 requirement for `--merge-base` with the fallback.

### Step 6 — README overhaul (`README.md`)
Constraints: keep every ``### `buildit-…` `` heading and every `---` separator; keep "synchroniz" + `.scratch/plan/task-` + `needs-scoping` in the relevant sections; keep the 2026-11-24 spec reference.
1. Line 3: "A framework of 10 skills (9 user-facing + the internal `buildit-worktree`)".
2. Realign the manual-flow diagram (loop return border in a single column).
3. Add `## Project configuration` (before `## Skills`, after `## Autonomy configuration`): table key / meaning / default / written by (Test command → bootstrap; Base branch → bootstrap; 3 sync headings → bootstrap step 6b or buildit-plan when unconfigured), value convention, unconfigured ≠ disabled rule, no secrets, example file.
4. Add `## Plan files` (after Project configuration): layout `.scratch/plan/plan.md` + `task-{name}.md`, task file format sample (Status, Readiness, Description, Acceptance tests, Synchronization with `Link:` / `Pending:`), lifecycle `todo → in-progress → done`, readiness `ready` / `needs-scoping` and plan.md tags, field ownership table (run → Status; discover → Description/AT/Readiness; plan → full reconcile), sync rules (orchestrator only, one confirmation, Pending on refusal/failure, never blocks). Verify the task format against `skills/buildit-plan/SKILL.md` before writing.
5. Shorten plan step 7, discover step 9 and run step 1 sync details to one sentence each that still contains "synchroniz" and a link `[Plan files](#plan-files)`.
6. Remove `**Design spec:** …2026-09-08…` in run section and the References line.
7. Replace `### Manual flow skills` heading with a plain paragraph (e.g. `**Manual flow skills** — the following skills …`).
8. Validate section: staging guard sentence + `git diff --cached --merge-base <base-branch>` + base branch from `.buildit/config.md` (default `main`). Ship section: readiness check uses staged diff vs base branch, other branches' committed diff, commits-only limitation.
9. Move `### \`buildit-worktree\`` block into the skills list after `buildit-feature-ship`, preceded by a `#### Internal` or bold "Internal" subheading — pick a form that does not collide with the `### ` `` end markers (a `####` heading is fine because tests stop at ``### ` `` or `---`). Keep the `---` separators around it; remove the old block after "Continuous improvement loop".
10. Add `## Running tests` (structure & tests) near Setup or before References: `bash tests/run-all.sh`, one `tests/test-<skill>.sh` per skill asserting on SKILL.md content (content-assertion convention), shared helpers in `tests/lib/assertions.sh` (`require_text`, `require_regex`, `require_absent`, `require_file`), pre-push hook runs the suite.

### Step 7 — Verify and stage
1. `bash tests/run-all.sh` green; `grep -rn 'main\.\.' skills/*/SKILL.md` empty.
2. `git status` → stage every created/modified file (skills, guideline, README, tests, tracking file) before setting `to-validate`.

### Self-critique (corrections integrated above)
- **Wide surface** (3 skills, 1 guideline, README overhaul, 4 test files) — user confirmed full scope. Mitigation: tests first per AT, README edited last, run-all after each step.
- **README test fragility**: tests slice sections with `sed '/^### `buildit-…`/,/^---/'` and ``### ` `` end markers. Never rename/relevel ``### `buildit-…` `` headings, keep `---` separators, keep "synchroniz" in the shortened plan/discover/run sections (AT-SYNC-14) and `.scratch/plan/task-` + `needs-scoping` in discover (AT-D13). New sections use `##` and sit outside the skill sections.
- **Staging guard self-trigger (was missing)**: validate step 1 sets the tracking file to `validating`, and `.scratch/shared-context.md` is routinely modified and unstaged (it is right now). A naive `git status --porcelain` check would NO-GO every run. Decision: exclude `.scratch/` paths from the guard; document why.
- **Porcelain parsing**: define precisely — `??` = untracked; second column non-space = unstaged; staged-only (`M `, `A `) is fine. Renames (`R `) are staged. Ignored files never appear.
- **Guard placement vs tests**: guard must run before the review (AT); placing it at the start of step 3 (after the test suite) is acceptable, but running tests on an unstaged tree is harmless. Keep at step 3 start to match "before the review".
- **NO-GO path coupling**: guard NO-GO must still go through "If NO-GO or FAIL" (Problems to fix + status `to-fix`), skipping acceptance phase — state that acceptance is not evaluated.
- **origin/HEAD format**: `git symbolic-ref refs/remotes/origin/HEAD` prints `refs/remotes/origin/main`; strip the prefix (or use `--short` and strip `origin/`). In this clone it fails → `main`.
- **Base branch not resolvable locally** (e.g. only `origin/main`): validate/ship must not silently produce an empty diff. Add a `git rev-parse --verify` check and an explicit stop message.
- **git < 2.30**: `--merge-base` unavailable; fallback documented in both skills and the guideline. Fallback for the other-branch diff must compare to `<branch>`, not HEAD.
- **Ship limitation**: other branches' staged-only files are invisible — documented, not fixed (user decision).
- **Ship commit ordering**: at ship step 1 the feature work is still staged (commit happens in step 2), so `--cached` is correct there.
- **Skill count test**: derive N from `skills/` directories rather than hardcoding 10, so the test stays valid when skills are added.
- **Dual deployment**: symlink → no copy needed; existing `diff -q` checks keep passing.
- **Documentation table** (team-practices): skill modification changes the validate interface (new NO-GO trigger) → README required (covered). No non-obvious new pattern requiring a design spec beyond the guideline entry; the `.scratch/` exclusion is documented inline in the skill and the guideline note.
- **Diagram alignment check**: box-drawing chars are multi-byte; compare columns by character (python3 or `awk` under UTF-8 locale), not byte offsets.

## Progress

### Build — 24-11-2026
- Tests first: new AT-BASE-*/AT-STAGE-* assertions in test-buildit-feature-{validate,ship}.sh and test-buildit-project-bootstrap.sh (ship AT-4 updated from `main...<branch` to the merge-base form); new tests/test-readme.sh (AT-R1..R8). All failed on content before implementation.
- validate: new step 2c (base branch resolution + `git rev-parse --verify` stop, restoring `to-validate`); step 3 starts with the staging guard (excludes `.scratch/`), then `git diff --cached --merge-base <base-branch>` with git < 2.30 fallback.
- ship: base branch resolution, staged feature file list, other-branch merge-base diff, commits-only limitation, fallbacks.
- bootstrap: step 4f base branch detection, coring summary, config.md template + convention sentence. language-framework.md documents `## Base branch`.
- README: 10-skill count, Running tests, Project configuration, Plan files, shortened plan/discover/run sync steps with `#plan-files` links, removed 2026-09-08 refs, "Manual flow skills" and "Internal" demoted to bold labels (worktree moved into the skills list), diagram realigned by display width (emoji = 2 columns, test measures the same way), validate/ship wording updated.
- bash tests/run-all.sh: 555 passed, 0 failed.
