# quote-skill-descriptions

## Status
shipped

## Worktree path
/home/loic-kaczmarek/mission/build-it-framework/.worktrees/feature/2026-10-21-quote-skill-descriptions

## Goal
Wrap skill YAML frontmatter description values in double quotes with proper escaping for cross-tool YAML compatibility (Copilot and other tools beyond Claude Code).

## Acceptance Tests
1. All `description:` values in `skills/*/SKILL.md` are wrapped in double quotes
2. All `description:` values in `.claude/skills/*/SKILL.md` are identical to their `skills/` counterpart
3. Special chars inside descriptions (em dashes, colons, arrows, brackets) are properly escaped or safe inside the quotes
4. The guideline template in `.buildit/guidelines/language-framework.md` shows the quoted format
5. All SKILL.md files parse as valid YAML frontmatter (no syntax errors)
6. Existing content-assertion tests still pass

## Plan

### Step 1: Update all 9 `skills/*/SKILL.md` description lines
For each skill file, wrap the `description:` value in double quotes. The current descriptions contain these special characters that would be problematic in unquoted YAML:
- Em dashes (`---`): all 9 skills
- Colons (`:`): most skills (triggers YAML value parsing)
- Arrows (`->`): buildit-feature-run
- Square brackets (`[]`): most skills (YAML flow sequence syntax)
- Parentheses (`()`): most skills

In YAML double-quoted scalars, only `\` and `"` need escaping. None of the current descriptions contain these characters, so the values are safe inside double quotes as-is.

Files (9 total):
- `skills/buildit-feature-build/SKILL.md`
- `skills/buildit-feature-discover/SKILL.md`
- `skills/buildit-feature-run/SKILL.md`
- `skills/buildit-feature-ship/SKILL.md`
- `skills/buildit-feature-start/SKILL.md`
- `skills/buildit-feature-validate/SKILL.md`
- `skills/buildit-project-audit/SKILL.md`
- `skills/buildit-project-bootstrap/SKILL.md`
- `skills/buildit-worktree/SKILL.md`

### Step 2: Copy all 9 to `.claude/skills/*/SKILL.md`
Use `cp` to sync each modified source to its deployed counterpart, preserving the dual-deployment invariant.

### Step 3: Update the guideline template
In `.buildit/guidelines/language-framework.md`, change the template from:
```
description: <one-line trigger description>
```
to:
```
description: "<one-line trigger description>"
```

### Step 4: Validate YAML frontmatter
Write a quick Python script to parse each SKILL.md frontmatter as YAML and confirm no syntax errors.

### Step 5: Run existing tests
Run `bash tests/run-all.sh` to confirm all 280 existing content-assertion tests still pass.

### Self-critique corrections
- **Risk: test regex mismatch.** The invariant test `test-skills-invariants.sh` uses `^description:` as a regex. Adding quotes after the colon does NOT break this regex -- it matches the line prefix. Verified safe.
- **Risk: descriptions containing literal double-quote characters.** Audited all 9 descriptions -- none contain `"` or `\`. No escaping needed beyond wrapping.
- **Risk: multiline descriptions.** All descriptions are single-line. No folding/block scalar concerns.
- **Edge case: trailing whitespace.** Will ensure no trailing whitespace is introduced after the closing quote.
- **Assumption check: Python availability.** The YAML validation step uses Python 3. Confirmed available in the environment.

## Progress
