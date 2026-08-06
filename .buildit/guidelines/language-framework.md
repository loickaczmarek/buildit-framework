# Language & Framework

## Stack

- Framework: Claude Code Skills (markdown-based agent workflow)
- Format: Markdown with YAML frontmatter
- Runtime: Claude Code harness — reads `.claude/skills/<skill-name>/SKILL.md`

## Skill file structure

Each skill file follows this structure:

```
---
name: <skill-name>
description: <one-line trigger description>
---

# <Skill Title>

<short description>

## When to use

<trigger conditions>

## Steps

### 0. ...
### 1. ...
```

## Deployment model

Dual-location: canonical source in `skills/`, deployed copy in `.claude/skills/`.
The harness reads from `.claude/skills/` — `skills/` is the source of truth for development and review.

## Design decisions

Design specs live in `docs/<domain>/specs/YYYY-MM-DD-kebab-name.md`.
They document the WHY behind non-obvious skill design choices.

## Parallel coordination

Multi-feature parallelisation via git worktrees.
Coordination goes through `.scratch/shared-context.md` (4 fixed sections):
- API & Contracts modified
- Constraints discovered
- Decisions & Conventions
- Merge readiness

## Preferred patterns

- Each skill ends by instructing the agent which skill to invoke next (explicit handoff)
- Steps are numbered (`### 0.`, `### 1.`, …) for unambiguous reference in reviews and fix cycles
- Acceptance tests in tracking files use PASS/FAIL verdicts with precise justification
- Why clear-context between phases: cuts contextual noise, keeps reasoning clean across build/fix cycles

## Patterns to avoid

[enriched as features are shipped]

## Known behaviours / constraints

[automatically enriched via shared-context.md at merge]
