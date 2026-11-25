# Design Spec: worktree mode

**Date:** 2026-11-24
**Feature:** docs-and-hygiene
**Status:** Current behaviour

## Problem

Parallel features need isolated working copies, but the workflow state (`.scratch/`, `.buildit/config.md`) must stay shared so that other features see the Merge readiness rows, constraints and decisions. A git worktree isolates code and its index; it does not isolate untracked coordination files cleanly, and every git command run from the project root sees the base branch, not the feature.

## Design decisions

### Created by the internal `buildit-worktree` skill

`buildit-feature-start` calls `buildit-worktree` only after the prerequisite check and once the feature name is known, so a failed start leaves no orphan worktree. The skill derives `feature/YYYY-MM-DD-<name>`, ensures `.worktrees/` is gitignored (committing only `.gitignore`), creates `.worktrees/<branch>` and returns the absolute path and branch. No external worktree tooling is referenced.

### Two tracking-file fields

- `## Branch` — bare branch name, written once by start. It keys the Merge readiness row and ship's overlap self-skip. In worktree mode the project root is on another branch, so `git branch --show-current` in the root is never used for this.
- `## Worktree path` — absolute path or `none`. Build, validate and ship read it; ship reads it once at step 0 because step 4 moves the tracking file.

### State in the root, code in the worktree

`.scratch/` and `.buildit/config.md` are always read and written in the project root. Code edits happen in the worktree. Every git command on feature code uses `git -C <worktree-path>`: each worktree has its own index, so staged work is visible only there (validate's staging guard and diff depend on it).

### Tests run in the worktree

Build and validate run the test command with the worktree as working directory (`cd <worktree-path> && <test command>`), and validate checks the ecosystem markers inside the worktree. The project root holds base-branch code; tests run there never see the feature.

### Ship carries only this feature's state

Ship copies only the archived tracking file into the worktree. `shared-context.md` is gitignored local state, cleaned in the project root and never committed, so the feature commit never carries other features' rows. Guideline migrations and validate's 5a rule updates are made inside the worktree so they land in the feature commit. After the commit, ship removes the root copy of the archived tracking file (it would block the merge) and runs `git worktree remove`. Removal failure warns but does not block.

### Permissions (Claude mode)

Allow rules for the chained `cd <worktree-path> && <test command>`: see the README section [settings.json permission file (Claude mode only)](../../../README.md#settingsjson-permission-file-claude-mode-only), the single explanation. Bootstrap points to it and run's Subagent autonomy block does not repeat it — it is a harness detail for humans, not an agent instruction.

## Limits

- Ship's overlap check only sees other branches' commits, not files staged in another worktree.
- `shared-context.md` has no locking; phases that write it must be staggered.

## References

- `skills/buildit-worktree/SKILL.md`, `skills/buildit-feature-start/SKILL.md`, `skills/buildit-feature-ship/SKILL.md`
- [buildit-feature-run design](2026-11-24-buildit-feature-run-design.md)
