# Design spec — buildit-feature-run

**Date:** 2026-09-08
**Feature:** buildit-feature-run (orchestrator skill)

---

## Context isolation via fresh subagents

Each phase (start, build, validate, ship) is delegated to a **fresh subagent** with zero prior conversation context.

**Why:** The buildit manual flow explicitly requires clearing context between phases ("🔄 CLEAR CONTEXT"). Accumulated context degrades reasoning quality across build/fix cycles, and causes the agent to rationalise past decisions rather than evaluate the current state objectively. Delegating to a fresh subagent recreates the clean-context boundary without requiring the human to close and reopen sessions.

**Consequence:** the orchestrator itself only holds coordination state (tracking file path, worktree path, cycle counter, current status). All implementation noise stays in the phase subagents and does not accumulate in the orchestrator.

---

## Signal-passing via tracking file status

The orchestrator communicates with phase subagents exclusively through the tracking file status field — not through direct return values or in-memory state.

**Why:** each subagent runs in its own context and cannot return structured values to the orchestrator. The tracking file is the single source of truth for feature state already in the buildit protocol. Using it as the signal channel requires no new protocol — the orchestrator reads what the human would read manually.

**Known limitation:** if a subagent crashes before updating the tracking file status, the orchestrator re-reads the pre-crash status. To detect this, the orchestrator checks whether the status changed after each phase completes. If unchanged, it stops and warns instead of looping silently on stale state (see C4 in the tracking file self-critic).

---

## Worktree detection post-start via `git worktree list`

The orchestrator asks whether to use a worktree before launching the start subagent. If yes, after start completes it runs `git worktree list` to extract the worktree path.

**Why:** the worktree is created inside the start subagent (which invokes `using-git-worktrees`). The orchestrator cannot receive the path as a return value. `git worktree list` is the authoritative source for active worktrees in the current repo.

**Known limitation:** worktree name detection relies on the branch naming convention `feature/YYYY-MM-DD-[feature-name]`. Non-standard branch names require manual worktree path identification.

---

## No-rollback behaviour on mid-phase failure

If a phase subagent fails mid-execution (crash, unexpected status, tracking file not found), the orchestrator stops immediately and instructs the user to inspect manually.

**Why:** partial rollback would require the orchestrator to undo work done by the failed subagent, which is infeasible without knowing the subagent's internal state. Stopping cleanly and surfacing the issue is safer than attempting recovery that could corrupt the tracking file or shared-context.

---

## --max-cycles default and validation

Default N=3 mirrors the warning threshold in `buildit-feature-validate` (which warns on the 3rd NO-GO cycle or more). If N < 1, the orchestrator warns and uses the default to prevent infinite or zero-iteration loops.
