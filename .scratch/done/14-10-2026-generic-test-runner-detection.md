# generic-test-runner-detection

## Status
to-ship

## Worktree path
/home/loic-kaczmarek/mission/build-it-framework/.worktrees/feature/2026-10-14-fix-critical-audit-issues

## Goal
Replace hardcoded test runner detection in buildit-feature-validate with a bootstrap-configured test command (bootstrap auto-detects ecosystem and proposes, user confirms) plus multi-ecosystem fallback heuristic in validate.

## Acceptance Tests
1. buildit-project-bootstrap detects the project ecosystem (package.json, pom.xml, build.gradle, pyproject.toml, Makefile, tests/run-all.sh...), proposes the deduced test command, and asks the user for confirmation before storing it in `.buildit/`
2. buildit-feature-validate reads the configured test command first; if absent, uses ecosystem detection as fallback
3. Ecosystem detection covers at minimum: tests/run-all.sh, package.json (npm test), pom.xml (mvn test), build.gradle (gradle test), pyproject.toml (pytest), Makefile (make test)
4. If no configured command and no ecosystem detected, warn and proceed
5. Existing tests (bash tests/run-all.sh) still pass after changes

## Plan

### Context from shared-context review
- No API changes, constraints, or decisions in shared-context.md that affect this feature.
- The branch already has one commit (fix(skills): harden validate, ship, and shared-context against audit findings) which added the current hardcoded step 2b in validate.

### Current state
- **validate step 2b** (worktree): hardcoded 3-item cascade: `tests/run-all.sh` > `npm test` > warn. This needs to become config-first with fallback heuristic.
- **bootstrap**: does light coring (step 4) detecting test directories and reading package.json, but never extracts or persists a test command. Needs a new sub-step.
- **`.buildit/`**: contains only `guidelines/`. No config file mechanism exists. Need to introduce one.
- **Dual deployment**: all skill changes must be mirrored to both `skills/` and `.claude/skills/`.

### Step 1: Create `.buildit/config.md` convention

Introduce a lightweight config file at `.buildit/config.md` that stores project-level settings detected by bootstrap. Using markdown to stay consistent with the framework's markdown-first approach. Structure:

```markdown
# Project Configuration

## Test command
<!-- Auto-detected by bootstrap, confirmed by user -->
bash tests/run-all.sh
```

The test command is the raw shell command on a single line after the `## Test command` heading. Skills read it with a simple grep/sed pattern. No YAML/JSON dependency.

**Self-critique addressed**: Markdown config is simpler than JSON/YAML for a markdown-native framework but requires careful parsing. The convention is: first non-empty, non-comment line after `## Test command` is the command. This is unambiguous and grep-friendly.

### Step 2: Add ecosystem detection + test command step to bootstrap

Add a new step **4e** to `buildit-project-bootstrap/SKILL.md` between step 4d and step 5. This step:

1. Detects ecosystem markers in priority order:
   - `tests/run-all.sh` exists -> `bash tests/run-all.sh`
   - `package.json` exists -> `npm test`
   - `pom.xml` exists -> `mvn test`
   - `build.gradle` or `build.gradle.kts` exists -> `gradle test`
   - `pyproject.toml` exists -> `pytest`
   - `Makefile` exists and contains a `test` target -> `make test`
2. Proposes the detected command to the user:
   > "Detected test command: `[command]`. Confirm or provide the correct command:"
3. If no ecosystem detected, asks the user for the test command (or skip).
4. Stores the confirmed command in `.buildit/config.md` under `## Test command`.

Also update step 8 to include `.buildit/config.md` in the template for new projects (empty `## Test command` section with comment placeholder).

### Step 3: Update validate to read config first, fallback to heuristic

Rewrite validate step 2b to use a two-tier detection:

**Tier 1 — Configured command:** Read `.buildit/config.md`, extract the line under `## Test command`. If found and non-empty, use it.

**Tier 2 — Ecosystem fallback heuristic:** If no config found, apply the same detection cascade as bootstrap (step 2 above) covering all 6 ecosystems.

**Tier 3 — No detection:** Warn "No test runner detected — no configured command in `.buildit/config.md` and no ecosystem markers found. Proceeding to review phase without running tests." and continue.

### Step 4: Write tests

Create/update tests to verify:
- `test-buildit-project-bootstrap.sh`: add assertions that the SKILL.md contains ecosystem detection markers (package.json, pom.xml, build.gradle, pyproject.toml, Makefile, tests/run-all.sh), user confirmation prompt, and `.buildit/config.md` storage.
- `test-buildit-feature-validate.sh`: add assertions that step 2b references `.buildit/config.md` as primary source, includes the fallback heuristic with all 6 ecosystems, and warns when nothing detected.
- Optionally: a dedicated `test-generic-test-runner-detection.sh` for cross-skill consistency (both skills list the same ecosystems).

### Step 5: Run existing tests

Run `bash tests/run-all.sh` to ensure no regressions. All existing tests must pass.

### Step 6: Dual deployment

Mirror changes from `skills/` to `.claude/skills/` for both modified skills:
- `skills/buildit-project-bootstrap/SKILL.md` -> `.claude/skills/buildit-project-bootstrap/SKILL.md`
- `skills/buildit-feature-validate/SKILL.md` -> `.claude/skills/buildit-feature-validate/SKILL.md`

### Step 7: Documentation

Per the documentation requirements table in team-practices.md:
- **Skill modification** with interface change: README.md update required (mention the new config.md and the test command detection in the bootstrap/validate descriptions).
- **Design spec**: required — the config.md convention and the two-tier detection pattern are non-obvious design choices. Create `docs/buildit/specs/2026-10-14-generic-test-runner-detection.md`.

### Self-critique corrections applied to plan

1. **Config file format risk**: Chose markdown over JSON/YAML to stay consistent with the framework's all-markdown approach. Parsing is simple (first non-empty non-comment line after heading). Risk: a user might add extra content. Mitigation: the convention is clearly documented in the file header comment.

2. **Ecosystem priority order**: `tests/run-all.sh` must come first because it's the project's own custom runner and should always take precedence over generic ecosystem commands. This matches the current worktree behavior.

3. **build.gradle vs build.gradle.kts**: Need to check for both Groovy and Kotlin DSL variants. Added to the detection list.

4. **Makefile target detection**: Simply checking for Makefile existence is insufficient — it might not have a `test` target. Need to grep for `^test:` in the Makefile. Plan updated.

5. **Dual deployment must happen in the worktree**: All file operations happen in the worktree path, where both `skills/` and `.claude/skills/` exist.

6. **Existing test coverage**: `test-buildit-feature-validate.sh` and `test-buildit-project-bootstrap.sh` already exist. Need to read them first to understand existing assertions before adding new ones — avoid breaking existing patterns.

7. **bootstrap step numbering**: Adding 4e keeps existing step references stable — steps 1-4d and 5-9 remain unchanged.

## Problems to fix
<!-- cleared -->

## Progress

### Build cycle 1 -- 14-10-2026
- Tests written: 3 test files updated/created (bootstrap +3 assertions, validate +5 assertions, cross-skill consistency 16 assertions)
- Implementation: bootstrap step 4e (ecosystem detection + config storage), validate step 2b rewritten (two-tier: config-first + fallback heuristic)
- Dual deployment: hardlinked, no copy needed
- All 205 tests pass, zero regressions
- New practice documented in shared-context: `.buildit/config.md` convention

### NO-GO cycle 1 — 14-10-2026
- Review: NO-GO — missing README.md update and design spec (team-practices.md documentation requirements)
- Acceptance: PASS — all 5 acceptance tests satisfied

### Fix cycle 2 — 14-10-2026
- README.md updated: bootstrap description mentions test command detection + config.md; validate description mentions two-tier detection; References section updated
- Design spec created: `docs/buildit/specs/2026-10-14-generic-test-runner-detection.md` — documents markdown config convention, two-tier detection pattern, cross-skill ecosystem consistency
- All 205 tests pass, zero regressions
