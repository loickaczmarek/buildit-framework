# run-tests-before-push

## Status
to-ship

## Goal
Automatically run the full test suite (`tests/run-all.sh`) before any `git push`, blocking the push if tests fail. This prevents broken PRs by catching regressions locally before they hit CI.

## Acceptance Tests
1. A pre-push hook script exists at `scripts/hooks/pre-push` and is marked executable.
2. The hook calls `tests/run-all.sh` (resolved relative to the repo root, not the hook's location).
3. The hook exits non-zero when tests fail, which causes `git push` to abort.
4. The hook exits 0 when all tests pass, allowing the push to proceed.
5. An installer script `scripts/install-hooks.sh` exists, is executable, and copies/symlinks the hook to `.git/hooks/pre-push`.
6. The installer is idempotent: running it twice does not break the hook.
7. `team-practices.md` documents the hook setup step (run `scripts/install-hooks.sh` after cloning).
8. A test file `tests/test-run-tests-before-push.sh` validates criteria 1, 2, 5, 6, and 7 via structural checks.

## Plan

### Step 1 — Write the failing test (TDD artefact)
Create `tests/test-run-tests-before-push.sh` that asserts:
- `scripts/hooks/pre-push` exists and is executable
- `scripts/hooks/pre-push` contains a reference to `run-all.sh`
- `scripts/install-hooks.sh` exists and is executable
- `scripts/install-hooks.sh` contains a reference to `pre-push`
- `.buildit/guidelines/team-practices.md` mentions `install-hooks.sh`

### Step 2 — Create `scripts/hooks/pre-push`
Shell script that:
- Resolves the repo root via `git rev-parse --show-toplevel`
- Runs `bash "$REPO_ROOT/tests/run-all.sh"` (explicit `bash` call avoids permission issues on fresh clones)
- On failure: prints a clear error ("Tests failed — push aborted. Fix tests or use --no-verify to bypass.") and exits 1
- On success: exits 0

### Step 3 — Create `scripts/install-hooks.sh`
Shell script that:
- Resolves the repo root via `git rev-parse --show-toplevel`
- If `.git/hooks/pre-push` already exists and differs from the source, prints a notice before overwriting
- Copies `scripts/hooks/pre-push` to `.git/hooks/pre-push` (copy, not symlink — avoids dangling refs if repo is moved)
- Makes `.git/hooks/pre-push` executable
- Prints a confirmation message on success

**Note:** Acceptance tests 3 & 4 (hook exit-code behaviour under real `git push`) require a live git environment and cannot be covered by structural bash tests. They are validated manually in Step 5.

### Step 4 — Update `team-practices.md`
Add a "Setup" section (or extend the existing Testing section) instructing contributors to run `scripts/install-hooks.sh` after cloning.
Mirror the change to `.claude/skills/` if any skill file references team-practices — but since team-practices is a guideline, no mirror needed.

### Step 5 — Verify
Run `tests/run-all.sh` and confirm the new test file passes.
Manually test: install the hook, run `git push --dry-run` (or inspect hook output with `bash .git/hooks/pre-push`).

## Progress

### GO cycle 1 — 31-08-2026
- Review: GO
- Acceptance: PASS — 8/8 criteria satisfied, 93/93 test assertions passing

## Problems to fix
