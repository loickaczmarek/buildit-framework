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

`.buildit/config.md` is the project-level configuration file. No YAML/JSON dependency — stays consistent with the framework's markdown-first approach.

**Config value rule:** the value of a heading is the first non-empty, non-comment line after it, read only within that heading (stop at the next heading); a line starting with `#` is never a value. A heading with no such line is empty, and an empty value is treated exactly like an absent one (the consumer's fallback or default applies). Every skill that reads `.buildit/config.md` restates this rule. Why: an unbounded read of an empty `## Test command` would yield `## Base branch`, which bash runs as a comment and exits 0 — silently bypassing the test gate.

Skills that need configuration (e.g. a test command) read from this file first and fall back to auto-detection heuristics when no configured value is found. An empty `## Test command` falls back to ecosystem detection.

`buildit-project-bootstrap` is responsible for creating and populating this file during project setup: it auto-detects settings, proposes them to the user for confirmation, and writes the confirmed values.

`## Base branch` is the branch the review diff (`buildit-feature-validate`) and the readiness overlap check (`buildit-feature-ship`) compare against. It defaults to `main` when absent or empty. `buildit-project-bootstrap` detects it from `git symbolic-ref refs/remotes/origin/HEAD` (falling back to `main`) and asks for confirmation. Both skills diff with `git diff --cached --merge-base <base-branch>` so staged, uncommitted work is included; `--merge-base` needs git >= 2.30, with the fallback `git diff --cached $(git merge-base <base-branch> HEAD)`. Validate's staging guard (`git status --porcelain`) ignores `.scratch/` paths, which are workflow state committed by ship.

Task synchronization uses three headings: `## Task synchronization` (`enabled`/`disabled`; absent, empty or unrecognized means unconfigured, not disabled), `## Synchronization method` (plain-language description of tool, target and access method — never a shell command) and `## Synchronization tag` (default `technical` when absent or empty). Never store secrets in this file. Only `buildit-plan` and `buildit-project-bootstrap` prompt to configure synchronization; other skills treat unconfigured as disabled.

## Parallel coordination

Multi-feature parallelisation via git worktrees.
Coordination goes through `.scratch/shared-context.md`, local, untracked (gitignored) state coordinating worktrees on a single machine (4 fixed sections):
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

- **Hardcoding agent-specific paths in skill instructions.** Do not reference `.claude/skills/` directly inside a skill file. When listing or referencing skills, use the canonical `skills/` directory. If the mode is relevant, determine it with the `**Operating mode rule**` (agent identity, `.buildit/guidelines/team-practices.md`) and store the result in a variable; never embed agent-specific paths directly in skill instructions. This preserves compatibility with the dual-location deployment model.
- **Appending duplicate rules to guideline files.** Before writing any rule to a guideline file, read the target file and check whether the exact text (or a semantically equivalent rule) is already present. Do not append a rule that already exists — even if it was just generated in the current fix cycle. Deduplicate before writing; never rely on downstream cleanup.
- **Failing to update count references when modifying enumerated tables.** When a row is added to or removed from any table whose row count is referenced elsewhere in the same skill file (e.g. "N dimensions", "N steps"), every such reference — including the YAML frontmatter `description` field and all body text occurrences — must be updated to reflect the new total. Treat the table and its count references as a single atomic unit: never modify the table without auditing and updating every associated count.

## Testing skills

Skill tests are **content-assertion tests**, not execution tests. They grep `SKILL.md` for behavioural rules (required steps, guard clauses, argument handling) and check invariants across the skill suite (dual-deployment parity, required sections). Do not write bash-executable test cases expecting skill files to run as scripts — they are Markdown, not shell.

## Known behaviours / constraints

[automatically enriched via shared-context.md at merge]

- **Claude Code permission matching**: a harness detail for humans, not an agent instruction — do not repeat it in skills (bootstrap's settings template, step 2b, only points to it; run's Subagent autonomy block omits it). Explained once in the README: [settings.json permission file (Claude mode only)](../../README.md#settingsjson-permission-file-claude-mode-only).
