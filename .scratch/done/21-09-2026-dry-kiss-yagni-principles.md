# dry-kiss-yagni-principles

## Status
to-ship

## Worktree path
none

## Goal
Integrate DRY, KISS, and YAGNI as explicit criteria in the build and validate phases of the buildit framework. The 3 principles must have a single source of truth in the project guidelines and be referenced (not duplicated) by both skills.

## Acceptance Tests
1. The `buildit-feature-build` skill explicitly references DRY, KISS, and YAGNI as principles for reviewing the produced code.
2. The `buildit-feature-validate` skill explicitly references DRY, KISS, and YAGNI as validation criteria.
3. The definitions of the 3 principles have a single source of truth (a guideline file) — no duplication between skills.
4. The formulation is consistent between build and validate (same terminology, same file reference).
5. The principles are integrated into the project guidelines (`.buildit/guidelines/`).

## Plan

### Step 1 — Create `.buildit/guidelines/craft-principles.md`

Create a new guideline file with canonical definitions of DRY, KISS, and YAGNI:
- DRY (Don't Repeat Yourself): every piece of knowledge or logic has a single, authoritative representation. Duplication signals that abstraction is missing.
- KISS (Keep It Simple, Stupid): prefer the simplest solution that correctly solves the problem. Complexity is a liability — add it only when simplicity genuinely cannot satisfy the requirement.
- YAGNI (You Aren't Gonna Need It): do not implement functionality until it is actually required. Speculative additions increase maintenance cost without delivering value.

Each definition should also include the failure mode (what a violation looks like) to make evaluation concrete for the agent.

### Step 2 — Modify `skills/buildit-feature-build/SKILL.md`

Add a new step **3c** (in normal TDD mode, after 3b Implement) for craft-principles self-review:
- Instructs the agent to verify the implementation against DRY, KISS, YAGNI before moving to step 4.
- References `<guidelines-dir>/craft-principles.md` for definitions — does NOT copy them.
- If a violation is found, fix it before proceeding.

In fix mode (3b Fix), append a similar reminder at the end of step 3b.

### Step 3 — Modify `skills/buildit-feature-validate/SKILL.md`

Add a 6th row to the 5-dimension review table in step 3:
- Dimension: **Craft principles**
- Question: Does the code respect DRY, KISS, and YAGNI? (see `<guidelines-dir>/craft-principles.md`)

This keeps definitions in the guideline and uses the exact same file reference as the build skill, ensuring consistent terminology.

### Step 4 — Mirror both skills to `.claude/skills/`

Copy the modified canonical files:
- `skills/buildit-feature-build/SKILL.md` → `.claude/skills/buildit-feature-build/SKILL.md`
- `skills/buildit-feature-validate/SKILL.md` → `.claude/skills/buildit-feature-validate/SKILL.md`

### Step 5 — Add content-assertion tests

Update `tests/test-buildit-feature-build.sh`:
- Assert that the skill mentions DRY, KISS, and YAGNI.
- Assert that it references `craft-principles.md`.

Update `tests/test-buildit-feature-validate.sh`:
- Assert that the skill mentions DRY, KISS, and YAGNI as a review dimension.
- Assert that it references `craft-principles.md`.

Create `tests/test-dry-kiss-yagni-principles.sh` for cross-skill invariants:
- AT-3: Definitions live only in `craft-principles.md` — the skill files must not contain the definitions (only a reference/pointer).
- AT-4: Both skills reference `craft-principles.md` (same filename, same variable `<guidelines-dir>`).
- AT-5: `craft-principles.md` exists in `.buildit/guidelines/`.

### Step 6 — Documentation (per team-practices.md)

Per team-practices.md: skill modifications with non-obvious design choices require a design spec. The single-source-of-truth pattern (definitions in guideline, pointer in skill) is a non-obvious design choice. Create `docs/skills/specs/2026-09-21-craft-principles-single-source-of-truth.md`.

## Problems to fix

## Progress

### NO-GO cycle 1 — 21-09-2026
- Review: NO-GO — count reference "5 dimensions" not updated after adding the "Craft principles" row (table now has 6 rows); two locations in the validate skill + both mirrors.
- Acceptance: PASS — all 5 acceptance tests pass.
