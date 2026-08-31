# skill-test-harness

## Status
to-ship

## Goal
A reusable bash test harness for the buildit skill suite. Extracts shared assertion helpers into `tests/lib/assertions.sh`, adds a cross-skill structural invariants test, and provides per-skill acceptance criteria tests for all 6 skills. A `run-all.sh` entry point aggregates results. No test runner dependency — pure bash + grep, consistent with the existing testing convention documented in team-practices.md.

## Acceptance Tests
- [ ] `tests/lib/assertions.sh` exists and exposes `ok`, `fail`, `require_file`, `require_text`, `require_regex` — usable via `source`
- [ ] `tests/test-skills-invariants.sh` validates all 6 skills for: file existence (source + deployed), source/deployed sync, frontmatter (`name:`, `description:`), `## Steps` section, closing handoff instruction
- [ ] `tests/test-buildit-feature-discover.sh` is refactored to source `lib/assertions.sh` and all 18 existing assertions still pass
- [ ] Per-skill test files exist for `start`, `build`, `validate`, `ship`, `project-bootstrap`, each with ≥3 skill-specific acceptance criteria assertions
- [ ] `tests/run-all.sh` runs all test files and exits non-zero if any file fails
- [ ] Running `bash tests/run-all.sh` from the repo root produces a combined summary (total passed / total failed across all files)

## Plan

### 1. Create `tests/lib/assertions.sh`
Extract `ok`, `fail`, `require_file`, `require_text`, `require_regex` from `test-buildit-feature-discover.sh` into a shared library. Initialize `PASS=0` and `FAIL=0`. Preserve the `((PASS++)) || true` pattern to handle `set -e` safely in sourcing test files.

### 2. Refactor `tests/test-buildit-feature-discover.sh`
Replace the 5 inline function definitions and the `PASS=0`/`FAIL=0` lines with a single `source "$(dirname "$0")/lib/assertions.sh"`. Verify the 18 existing assertions still pass before and after the refactor.

### 3. Create `tests/test-skills-invariants.sh`
Loop over all 6 skills (`buildit-feature-discover`, `buildit-feature-start`, `buildit-feature-build`, `buildit-feature-validate`, `buildit-feature-ship`, `buildit-project-bootstrap`). For each skill, assert:
1. Source file exists: `skills/<skill>/SKILL.md`
2. Deployed file exists: `.claude/skills/<skill>/SKILL.md`
3. Source and deployed are in sync (`diff -q`)
4. Frontmatter has `name: <skill>` (exact match)
5. Frontmatter has `description:` field
6. `## Steps` section is present
7. `## End of skill` section is present (closing handoff invariant)

### 4. Create per-skill test files (≥3 assertions each)

**`tests/test-buildit-feature-start.sh`**
- Reads `shared-context.md` before planning
- Tracking file template includes `to-build` status
- Handoff instruction references `/buildit-feature-build`

**`tests/test-buildit-feature-build.sh`**
- Detects fix mode via "Problems to fix" section
- TDD mode writes failing tests before implementing
- Handoff instruction references `/buildit-feature-validate`

**`tests/test-buildit-feature-validate.sh`**
- Evaluates on 5 dimensions (correctness, performance, security, style, coverage)
- Routes to `/buildit-feature-build` on NO-GO
- Reads shared-context constraints before reviewing

**`tests/test-buildit-feature-ship.sh`**
- Cleans shared-context.md at close
- Migrates durable constraints to guidelines
- Does NOT push or create the PR (explicit in skill)

**`tests/test-buildit-project-bootstrap.sh`**
- Scans the guidelines directory (`<guidelines-dir>`)
- Detects Claude mode vs generic mode
- Produces a bootstrap commit

### 5. Create `tests/run-all.sh`
- Locates all `test-*.sh` files relative to the script's own directory
- Runs each as `bash <file>` from the repo root (preserving cwd so skill paths resolve correctly)
- Captures output per file, prints it, parses `Results: X passed, Y failed` line
- Accumulates totals across files
- Prints `Total: X passed, Y failed`
- Exits non-zero if any test file exited non-zero or if total failed > 0

## Progress

### GO cycle 1 — 31-08-2026
- Review: GO
- Acceptance: PASS — 85/85 assertions passing across 7 test files
