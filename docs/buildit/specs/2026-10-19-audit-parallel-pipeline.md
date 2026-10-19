# Design Spec: Audit Parallel Pipeline

**Date:** 2026-10-19
**Skill:** buildit-project-audit
**Status:** Implemented

## Context

The original audit skill ran as a monolithic inline pass: one agent evaluated all 9 dimensions sequentially, produced a draft report, then a single critique subagent reviewed the entire report. This worked but had two problems: long wall-clock time for the full pass, and a single critique agent reviewing findings across unrelated domains (code quality, architecture, documentation).

## Decision: 3 parallel category subagents

The audit dimensions naturally group into 3 categories:
- **Category A** — Code quality (6 dimensions: correctness, performance, security, style, test coverage, craft principles)
- **Category B** — Architecture health (1 dimension: coupling & cohesion)
- **Category C** — Project health (2 dimensions: documentation gaps, config/setup health)

Each category runs as an independent subagent. All 3 are launched in a single message with multiple Agent tool calls, enabling true parallelism.

**Why parallel, not sequential:** The categories are independent — no category's findings depend on another's. Running them in parallel reduces wall-clock time without sacrificing quality.

**Why 3 categories, not 9 subagents:** One subagent per dimension would create excessive orchestration overhead. The 3-category grouping matches the natural domain boundaries (code vs. architecture vs. project health) and keeps the orchestrator's coordination logic manageable.

## Decision: Per-category critique instead of single critique

Each category subagent's findings are critiqued by a dedicated critique subagent. The critique subagent receives ONLY the findings from its category.

**Why per-category critique:** A single critique agent reviewing all 9 dimensions across 3 domains produces shallow, unfocused critique. A critique agent scoped to one category can deeply challenge the findings within that domain. This also prevents cross-category contamination — a code quality critique should not be influenced by architecture findings.

**Why the critique subagent receives only category findings:** Providing the full audit context would defeat independence. The critique subagent should challenge what the findings say, not rationalise them using the audit agent's reasoning.

## Decision: Progressive presentation

Findings are presented to the user as each category+critique pair finishes, rather than waiting for all 3. Categories B and C have fewer dimensions and will typically finish before Category A.

**Why progressive:** In a synchronous agent session, waiting for the slowest category before showing any results creates a poor user experience. Progressive presentation gives the user actionable findings sooner and provides visibility into audit progress.

## Interactions with existing architecture

- **Early write permission trigger** (step 2): The orchestrator writes a placeholder to the report file before launching subagents, surfacing the file-write permission prompt at session start rather than mid-subagent.
- **Final report format** is unchanged: severity-grouped findings with a critique integration section. The compile step (step 5) merges across categories and re-sorts by severity.
- **Hotspot analysis** (step 1) is unchanged — it runs before the parallel phase and provides `AUDIT_SCOPE` to all 3 subagents.
