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
description: "<one-line trigger description>"
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

## Project configuration

`.buildit/config.md` is the project-level configuration file. Convention: values are the first non-empty, non-comment line after a `## Section` heading. No YAML/JSON dependency — stays consistent with the framework's markdown-first approach.

Skills that need configuration (e.g. a test command) read from this file first and fall back to auto-detection heuristics when no configured value is found.

`buildit-project-bootstrap` is responsible for creating and populating this file during project setup: it auto-detects settings, proposes them to the user for confirmation, and writes the confirmed values.

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

- **Hardcoding agent-specific paths in skill instructions.** Do not reference `.claude/skills/` directly inside a skill file. When listing or referencing skills, use the canonical `skills/` directory. If agent identity is relevant, detect it first (e.g. check for a `.claude/` directory) and store the result in a variable; never embed agent-specific paths directly in skill instructions. This preserves compatibility with the dual-location deployment model.
- **Appending duplicate rules to guideline files.** Before writing any rule to a guideline file, read the target file and check whether the exact text (or a semantically equivalent rule) is already present. Do not append a rule that already exists — even if it was just generated in the current fix cycle. Deduplicate before writing; never rely on downstream cleanup.
- **Failing to update count references when modifying enumerated tables.** When a row is added to or removed from any table whose row count is referenced elsewhere in the same skill file (e.g. "N dimensions", "N steps"), every such reference — including the YAML frontmatter `description` field and all body text occurrences — must be updated to reflect the new total. Treat the table and its count references as a single atomic unit: never modify the table without auditing and updating every associated count.

## Testing skills

Skill tests are **content-assertion tests**, not execution tests. They grep `SKILL.md` for behavioural rules (required steps, guard clauses, argument handling) and check invariants across the skill suite (dual-deployment parity, required sections). Do not write bash-executable test cases expecting skill files to run as scripts — they are Markdown, not shell.

## Known behaviours / constraints

[automatically enriched via shared-context.md at merge]
