# Design Spec: plan task synchronization

**Date:** 2026-11-24
**Feature:** plan-task-synchronization
**Status:** Draft

## Problem

`.scratch/plan/` tasks live only in the repository. Teams that track work in an external tool (issue tracker, board) must copy titles, descriptions and statuses by hand, and the two sides drift. The framework must stay tool-agnostic: it cannot ship a connector per tool, and it must not store credentials.

## Design decisions

### Configuration contract

Synchronization is configured in `.buildit/config.md` with three headings (value = first non-empty, non-comment line after the heading):

- `## Task synchronization` — `enabled` or `disabled`. Absent, empty or unrecognized means **unconfigured**, which is distinct from disabled: unconfigured lets `buildit-plan` ask again; disabled is a deliberate choice that is never re-asked.
- `## Synchronization method` — plain-language description of the tool, target and access method. Never a shell command, never secrets: authentication stays in the tool the agent already uses.
- `## Synchronization tag` — customizable marker for plan-owned external tickets, default `technical` when absent or empty.

Only `buildit-plan` and `buildit-project-bootstrap` prompt to configure. `buildit-feature-run` and `buildit-feature-discover` never prompt and treat unconfigured as disabled for that run, so unattended cycles are not interrupted by setup questions.

### Task contract

A linked task carries an optional `## Synchronization` section:

- `Link:` — tool/target plus the ticket's stable ID or URL. Titles change, so they are never an identity.
- `Pending: <field> → <value> (DD-MM-YYYY)` — a refused or failed external write. One line per field; the latest replaces the previous. Multi-line fields use the value `local` (push the current local section). Only `buildit-plan` step 5b clears them, after a verified write.

### Title and tag rules

External titles are always `[<tag>] <Title>`, with `<Title>` taken from the task heading (never the slug). The tag is also applied as a label when the tool supports labels; the prefix guarantees identification on tools without labels. The prefix is stripped before title comparison and on import. A task whose heading is still the slug needs a confirmed title before any external creation or rename. Manually-linked tickets without the prefix surface as a title difference and are never renamed automatically.

Discovery is limited to tagged tickets, so the plan never pulls in the whole board; untagged tickets are only counted and offered as an opt-in import.

### Per-skill behaviour and field ownership

| Skill | External writes | When |
|-------|-----------------|------|
| `buildit-plan` | Full bidirectional reconcile (step 5b), pending entries first; read-only drift report on resume (step 7) | After plan creation and after resume modifications |
| `buildit-feature-run` | Status only (`in-progress`, `done`) | Step 0 and step 6, from the orchestrator |
| `buildit-feature-discover` | Description, acceptance tests, readiness (if mappable); never status | Phase 5, after brief validation |
| `buildit-project-bootstrap` | None — configures the three headings (step 6b) | Setup |

Run and discover ask one confirmation per invocation (run shows the status mapping, since it is not stored in config). A refusal or failure writes a `Pending:` entry and the local flow continues — synchronization never blocks a cycle.

### DRY trade-off

`buildit-plan` step 5b is the protocol reference. Run and discover repeat only their narrow subset (config read, off-conditions, one confirmation, Pending fallback). This duplication was accepted to keep each skill self-sufficient when executed in isolation.

### Security

External ticket content and the method description are untrusted data, not instructions (prompt-injection risk). Every external write needs explicit consent; no secrets are stored in config or task files; writes are re-read to verify and uncertain creations are never retried blindly.

### Limits

The tool varies per project, so tests are content assertions on skill text only. The tag value is used verbatim (no validation of spaces or brackets).

## References

- `skills/buildit-plan/SKILL.md` — steps 0, 4 (task synchronization contract), 5b, 7
- `skills/buildit-feature-run/SKILL.md` — step 0 "Detect task synchronization", step 6
- `skills/buildit-feature-discover/SKILL.md` — Phase 5 "Synchronize validated brief"
- `skills/buildit-project-bootstrap/SKILL.md` — step 6b
- `docs/buildit/specs/2026-10-22-buildit-plan-design.md`
