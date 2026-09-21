# Design Spec: Craft Principles — Single Source of Truth

**Date:** 2026-09-21
**Branch:** feat/craft-principles
**Skills affected:** buildit-feature-build, buildit-feature-validate

## Context

DRY, KISS, and YAGNI are standard software craft principles that belong in both the build phase (self-review before marking work done) and the validate phase (explicit review dimension). The naive approach would be to write their definitions inline in both skill files — but that duplicates knowledge and breaks consistency: when a definition is refined, two files must be updated in sync.

## Design decision: definitions in guideline, pointer in skill

The three principle definitions live exclusively in `.buildit/guidelines/craft-principles.md`. Both skill files reference that path. They do not copy the definitions.

This mirrors how the skills already handle other guidelines (team-practices, language-framework): the skill says "see `<guidelines-dir>/X`" and the agent reads the guideline at runtime.

### Why this matters

- **Single edit point:** refining a definition (e.g. adding a new violation sign) requires touching one file.
- **Consistent terminology:** both skills use the exact same wording because they read the same source.
- **Cheaper tests:** the invariant "definitions must not be in skill files" is machine-checkable via `require_absent`.

## Alternative considered: inline definitions in both skills

Inline definitions would be self-contained and readable without navigation. Rejected because duplication is itself a DRY violation — it would be ironic to enforce DRY by duplicating its own definition.

## Test strategy

Three test files cover this feature:

| File | What it checks |
|------|----------------|
| `tests/test-buildit-feature-build.sh` | Build skill mentions DRY, KISS, YAGNI and references `craft-principles.md` |
| `tests/test-buildit-feature-validate.sh` | Validate skill mentions DRY, KISS, YAGNI and references `craft-principles.md` |
| `tests/test-dry-kiss-yagni-principles.sh` | Cross-skill invariants: definitions absent from skills, same file reference in both, guideline file exists |
