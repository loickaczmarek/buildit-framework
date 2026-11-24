# Design Spec: subagent isolation

**Date:** 2026-11-24
**Feature:** docs-and-hygiene
**Status:** Current behaviour

## Problem

`buildit-feature-run`, `buildit-project-audit` and `buildit-feature-validate` (config-update step 5a) delegate work to subagents. A delegated agent can drift: adopt a persona, swap in another installed workflow, or stop on a question no human will answer. Each skill is also deployed standalone, so the protection cannot live in a shared include.

## Design decisions

### Neutral agent type

Every subagent uses the neutral `general-purpose` agent type. If the harness lacks it, the skill falls back to the default unspecialised subagent — never a specialised persona agent — and warns the user once.

### Isolation preamble, defined once per skill

Each launching skill defines an **Isolation preamble** as a named block in a "Subagent selection and workflow isolation" section and prepends it as the first line of every subagent prompt. It keeps the subagent neutral and forbids invoking any other skill or agent, except the buildit skills and subagents the delegated skill explicitly references or instructs it to launch (e.g. `buildit-worktree`, the validate §5a config-update subagent). A ban without that exemption would make an obedient subagent skip a required step (see `team-practices.md`, "Restriction wording in delegated-subagent preambles").

### Autonomy block, defined once in run

Run appends one "Subagent autonomy block" to every phase prompt: project root, mode (agent identity, Operating mode rule), relative script paths, no `cd` outside the root, and — in worktree mode only — tests run in the worktree and git through `git -C`. Defining it once replaced four inline copies that had drifted; `tests/test-cross-skill-contracts.sh` keeps it single and `tests/test-readme.sh` keeps the README copy identical.

### The tracking file is the only hand-off

A phase subagent receives the skill name, the feature name and the two blocks; it reads everything else from the tracking file and writes its result there (`## Status`, `## Problems to fix`, `## Last error`). The orchestrator never relies on the subagent's prose: it re-reads the status, and after ship it verifies git state.

### No human behind a subagent

A phase running as a subagent never waits for an answer. Ambiguous tracking-file discovery stops and lists the candidates; ship returns `SHIP BLOCKED: <reason>` with a `## Last error` line instead of waiting for confirmation; decisions taken without a human are recorded in the tracking file. External writes (plan task synchronization) happen only in the orchestrator, after one explicit confirmation.

### Category subagents (audit)

Audit runs parallel category subagents, each critiqued by a dedicated subagent that sees only that category (see [audit parallel pipeline](2026-10-19-audit-parallel-pipeline.md)). The same preamble rule applies.

## Limits

- Isolation relies on the subagent following its prompt; it is not enforced by the harness.
- Content tests check that the blocks exist and match; they cannot prove runtime compliance.

## References

- `skills/buildit-feature-run/SKILL.md`, `skills/buildit-project-audit/SKILL.md`, `skills/buildit-feature-validate/SKILL.md`
- `.buildit/guidelines/team-practices.md` — "Subagent selection and workflow isolation"
