# Design Spec: buildit-feature-run orchestrator

**Date:** 2026-11-24
**Feature:** docs-and-hygiene (replaces the deleted 2026-09-08 feature-run spec)
**Status:** Current behaviour

## Problem

The manual flow (start → build → validate → ship) needs a context clear between phases and a human to read each status and launch the next skill. Most features do not need mid-cycle judgement, so the routing can be automated — but without accumulating every phase's noise in one context, and without the orchestrator trusting a phase's own report of success.

## Design decisions

### One fresh subagent per phase

Each phase runs in a fresh subagent that executes the phase skill unchanged (see [subagent isolation](2026-11-24-subagent-isolation-design.md)). The orchestrator keeps only inputs, the tracking file name and the cycle counter. The phase skills stay usable on their own: run adds no phase logic, it only routes.

### Inputs before any subagent (step 1)

Worktree choice, name, description and acceptance tests are collected before the first launch. Subagents cannot ask questions, and an unattended cycle must not stop on a prompt halfway through. A matching plan task (`.scratch/plan/task-{name}.md`, Plan task lookup rule) pre-fills description and acceptance tests; the worktree question is always asked.

### Nothing written before start (step 2)

The Merge readiness row is keyed by the tracking file's `## Branch`, which exists only after start has created the worktree and the tracking file. A row pre-written by the orchestrator would be mis-keyed in worktree mode and orphaned when start fails, so start writes it (see `team-practices.md`, "Orchestrator-level permission trigger").

### The tracking file is the only routing signal

After each phase the orchestrator re-reads `## Status` from the tracking file (Tracking file discovery rule, named lookup):

| After | Expected | Otherwise |
|-------|----------|-----------|
| start | tracking file exists | stop: possible subagent failure |
| build | `to-validate` | stop: unchanged or unexpected status |
| validate | `to-ship` (GO) or `to-fix` (loop) | `## Last error` present → report it; else stop |

An unchanged status is treated as a failure, never retried silently. A phase that stops on purpose records one line in `## Last error`, so run can report the cause instead of "possible subagent failure".

### Bounded build/fix loop (`--max-cycles N`, default 3)

The default mirrors validate's warning on the 3rd NO-GO: beyond it, accumulated context degrades fixes. N < 1 falls back to 3. On exhaustion run stops and the user resumes with `/buildit-feature-build`.

### Ship is verified, not trusted (step 6)

Before ship, run records `SHIP_REF` (the `## Branch` value), `PRE_SHIP_HEAD` and the tracking file name. After ship it checks three facts: `SHIP_REF` moved, the archived tracking file exists in that commit (`git cat-file -e`), and no copy remains outside `.scratch/done/`. Any failure stops with "Unexpected state after ship", quoting ship's `SHIP BLOCKED:` line or `## Last error`. The plan task and external ticket are updated only after the three checks pass, so a blocked ship never marks a task `done`.

### Plan task ownership

Run owns the task `## Status` (`todo` → `in-progress` at step 0, `done` after verified ship), the `plan.md` checkbox and progress counters. Re-running a `done` task needs confirmation. External status writes happen from the orchestrator only, after one confirmation, and failures become `Pending:` entries (see [plan task synchronization](2026-11-24-plan-task-synchronization.md)).

### Push and PR stay manual

Run ends after the commit. Publishing is a human decision.

## Limits

- Tests are content assertions on the skill text (`tests/test-buildit-feature-run.sh`, `tests/test-cross-skill-contracts.sh`); the loop itself is not executed in CI.
- The orchestrator cannot detect a phase that changed the status but did poor work: that is validate's job.

## References

- `skills/buildit-feature-run/SKILL.md`
- [Worktree mode](2026-11-24-worktree-mode-design.md), [Subagent isolation](2026-11-24-subagent-isolation-design.md)
