---
name: buildit-feature-run
description: "Use to orchestrate the full buildit cycle (start → build → validate → ship) in a single session — each phase runs in a fresh subagent for context isolation. Accepts optional feature name and --max-cycles N (default 3). /buildit-feature-run [feature-name] [--max-cycles N]."
---

# Feature Run (Orchestrator)

Orchestrates the full buildit cycle — start → build → validate → ship — by delegating each phase to a fresh subagent. Reads the tracking file status between phases to route GO/NO-GO decisions. Keeps the orchestrator context clean; all implementation noise stays in phase subagents.

## When to use

When you want the full cycle to run unattended in a single session, rather than running each skill manually with a clear-context step between them. Most useful for straightforward features; prefer the manual flow for complex features where mid-cycle human judgement is needed.

## Arguments

```
/buildit-feature-run [feature-name] [--max-cycles N]
```

- `feature-name` — optional kebab-case name; passed to each subagent as argument
- `--max-cycles N` — maximum number of build/fix cycles before stopping (default 3, must be a positive integer; if N < 1, warn and use default)

## Subagent selection and workflow isolation

For every phase (start, build/fix, validate, and ship), explicitly select the neutral `general-purpose` agent in the delegation tool's agent-type parameter. Each phase skill defines the delegated subagent's role, procedure, and expected output; the subagent must remain neutral rather than layer another persona or workflow on top.

**Fallback:** if `general-purpose` is not available in the harness, use the harness's default unspecialised subagent — never a specialised persona agent — still prepend the isolation preamble, and warn the user once:
> "`general-purpose` agent not available — using the default unspecialised subagent with the isolation preamble."

**Isolation preamble** — prepend this block verbatim as the first line of every phase subagent prompt (steps 3, 5.2, 5.4 and 6 reference it as `[Isolation preamble — see "Subagent selection and workflow isolation"]`):

> "Remain a neutral execution agent: the requested buildit phase skill defines your role, procedure, and expected output. Execute that skill without adopting an additional persona or substituting another workflow. Do not invoke any skill or agent other than the requested phase skill and the buildit skills and subagents it explicitly references or instructs you to launch (e.g. `buildit-worktree`, the `buildit-feature-validate` §5a config-update subagent). Continue to follow the repository's shared project rules and guidelines."

The ban does not block the buildit skills and subagents a phase skill explicitly references or instructs the subagent to launch (e.g. `buildit-feature-start` → `buildit-worktree`, `buildit-feature-validate` §5a → config-update subagent); everything else stays forbidden. Repository project rules and guidelines still apply.

## Steps

### 0. Initialise

**Parse arguments**

Extract `feature-name` (if present) and `--max-cycles N` (if present, default N=3).

Validate N: if N < 1, warn: "Invalid --max-cycles value — using default N=3." and set N=3.

**Detect project root**

Run `pwd` and store the result as `PROJECT_ROOT`. Never hardcode this path — it varies per machine and project.

**Detect operating mode**

Run `ls .claude/ 2>/dev/null`. If the directory exists → **Claude mode**; otherwise → **Generic mode**. Store as `MODE`.

Use `PROJECT_ROOT` and `MODE` in all subsequent subagent autonomy instructions.

**Detect plan task**

If `feature-name` was provided as argument, check if `.scratch/plan/task-{feature-name}.md` exists.

- If the task file exists:
  - Read the task file. Extract `## Description`, `## Acceptance tests`, `## Readiness`, and `## Status`.
  - Store as `PLAN_TASK_FILE` (the path), `PLAN_DESCRIPTION`, `PLAN_ACCEPTANCE_TESTS`, `PLAN_READINESS`.
  - **Status guard:** if the task's current status is `in-progress` or `done`, warn: "Plan task '{feature-name}' is already marked '{status}' — proceeding anyway." but continue.
  - Update `## Status` in the task file from `todo` to `in-progress`.
  - If `.scratch/plan/plan.md` exists: re-sync the progress counters by re-reading all task file statuses and recomputing `X/Y done` for each epic or flat list. The checkbox stays `- [ ]` at this stage (in-progress is not done).
  - If `.scratch/plan/plan.md` does not exist: update task file only — no error.
- If the task file does not exist: set `PLAN_TASK_FILE=none`. No further plan-related actions — fallthrough to existing behavior unchanged.

### 1. Collect inputs before subagents

Before launching any subagent, collect the following from the user (worktree, name, description, acceptance tests) if not already provided via arguments.

**When `PLAN_TASK_FILE` is set (not `none`):**

Pre-fill `description` with `PLAN_DESCRIPTION` and `acceptance-tests` with `PLAN_ACCEPTANCE_TESTS`. Present them to the user:

> "The plan task provides the following description and acceptance tests. Confirm or override:"

Show the pre-filled values. The user can confirm (use as-is) or provide overrides. The **name** is already provided via argument (required for task file lookup).

The **worktree** question is always asked regardless of plan data — plan tasks do not determine worktree preference.

**When `PLAN_TASK_FILE` is `none` (or no plan detected):**

Ask all questions as before:

- **Worktree:** "Do you want to work in an isolated worktree for this feature?"
- **Name:** kebab-case slug (skip if provided as argument)
- **Description:** short functional description
- **Acceptance tests:** exhaustive list — being precise here determines the quality of all phases

In both cases, ask questions in order. Do not launch the start subagent until all four inputs are confirmed.

Store: `feature-name`, `description`, `acceptance-tests`, `use-worktree` (yes/no).

### 2. Trigger early write permission

<!-- WHY: The first Write operation in the full run cycle normally happens inside the
     start subagent (step 5 of buildit-feature-start) when it updates shared-context.md.
     If the user has not pre-allowed Write permissions, the permission prompt appears
     midway through the start phase, which is jarring. Moving a real, meaningful Write
     here — before any subagent is launched — ensures the permission prompt fires
     immediately at the start of the session. Users who have pre-allowed Write see no
     prompt at all. -->

> **Sequential access:** `shared-context.md` has no locking mechanism. When running parallel features, ensure only one skill session writes to this file at a time. Stagger phases that modify `shared-context.md` (start, build capture, ship cleanup) to avoid overwrites.

Read `.scratch/shared-context.md`. Retrieve the current branch name via `git branch --show-current`.

Write back to `.scratch/shared-context.md`, appending the merge readiness entry for the current branch:

```markdown
| [branch-name] | IN_PROGRESS | — | — |
```

This writes to an existing file — no new files are created, so cancelling after this step leaves no orphan files.

### 3. Subagent: buildit-feature-start

Launch a fresh `general-purpose` subagent (or the fallback — see "Subagent selection and workflow isolation") with the following prompt:

> "[Isolation preamble — see "Subagent selection and workflow isolation"]
> Run /buildit-feature-start [feature-name].
> Use worktree: [yes/no].
> Description: [description].
> Acceptance tests: [acceptance-tests list].
> Skip step 5 (shared-context update) — the merge readiness entry has already been written by the orchestrator.
> Autonomy: you are operating within the project directory `[PROJECT_ROOT]` (mode: [MODE]). Execute bash, python3, and cd commands freely within this directory and its subdirectories (including `.worktrees/`). Use relative paths for script invocations (e.g. `bash tests/…`). Do not cd outside the project root — paths outside require explicit user permission."

Wait for the subagent to complete.

### 4. Detect tracking file and worktree path after start

Read the tracking file: scan `.scratch/` for `*[feature-name]*.md` outside of `done/`.

If the tracking file is not found after start: stop and warn the user:

> "Tracking file not found after buildit-feature-start — possible subagent failure. Inspect `.scratch/` and re-run manually."

If `use-worktree` is yes: read the `## Worktree path` field from the tracking file as the primary source of the worktree path. As secondary verification, run `git worktree list` and confirm the path appears. Pass this path to subsequent subagents.

### 5. Build/fix loop (max N cycles)

Initialise: `cycle = 0`.

**Loop:**

1. Increment `cycle`. If `cycle > N`: stop with message:

   > "Max cycles (N=[N]) reached without a GO. Loop aborted after [N] cycles. Inspect `.scratch/[tracking-file]` and run `/buildit-feature-build [feature-name]` manually to continue."

2. **Subagent: buildit-feature-build**

   Launch a fresh `general-purpose` subagent (or the fallback — see "Subagent selection and workflow isolation"):

   > "[Isolation preamble — see "Subagent selection and workflow isolation"]
   > Run /buildit-feature-build [feature-name]."
   > (Include worktree path if applicable.)
   > "Autonomy: you are operating within the project directory `[PROJECT_ROOT]` (mode: [MODE]). Use relative paths for script invocations. Do not cd outside the project root — paths outside require explicit user permission.
   > [If use-worktree=yes]: For git commands inside the worktree, use `git -C <worktree-path>` instead of cd. The following permission is required in settings.json: `Bash(cd */.worktrees/* && *)`"

   Wait for completion.

3. **Check status after build**

   Read the tracking file status.

   If status has not changed from before the subagent ran: stop with message:

   > "Tracking file status unchanged after buildit-feature-build — possible subagent failure. Manual inspection required."

   If status ≠ `to-validate`: stop with message:

   > "Unexpected status '[status]' after buildit-feature-build — manual inspection required."

4. **Subagent: buildit-feature-validate**

   Launch a fresh `general-purpose` subagent (or the fallback — see "Subagent selection and workflow isolation"):

   > "[Isolation preamble — see "Subagent selection and workflow isolation"]
   > Run /buildit-feature-validate [feature-name]."
   > (Include worktree path if applicable.)
   > "Autonomy: you are operating within the project directory `[PROJECT_ROOT]` (mode: [MODE]). Use relative paths for script invocations. Do not cd outside the project root — paths outside require explicit user permission.
   > [If use-worktree=yes]: For git commands inside the worktree, use `git -C <worktree-path>` instead of cd. The following permission is required in settings.json: `Bash(cd */.worktrees/* && *)`"

   Wait for completion.

5. **Check status after validate**

   Read the tracking file status.

   If status has not changed from `to-validate`: stop with message:

   > "Tracking file status unchanged after buildit-feature-validate — possible subagent failure. Manual inspection required."

   Otherwise, route on the status:

   - `to-ship` → break the loop (GO)
   - `to-fix` → continue loop (increment cycle, repeat)
   - Anything else → stop with message:
     > "Unexpected status '[status]' after buildit-feature-validate — manual inspection required."

### 6. On GO: subagent buildit-feature-ship + manual reminder

**Subagent: buildit-feature-ship**

Launch a fresh `general-purpose` subagent (or the fallback — see "Subagent selection and workflow isolation"):

> "[Isolation preamble — see "Subagent selection and workflow isolation"]
> Run /buildit-feature-ship [feature-name]."
> (Include worktree path if applicable.)
> "Autonomy: you are operating within the project directory `[PROJECT_ROOT]` (mode: [MODE]). Use relative paths for script invocations. Do not cd outside the project root — paths outside require explicit user permission.
> [If use-worktree=yes]: For git commands inside the worktree, use `git -C <worktree-path>` instead of cd. The following permission is required in settings.json: `Bash(cd */.worktrees/* && *)`"

Wait for completion.

**Update plan task on completion**

If `PLAN_TASK_FILE` is set (not `none`):

- Update `## Status` in the task file from `in-progress` to `done`.
- If `.scratch/plan/plan.md` exists:
  - Find the line matching `- [ ] task-{feature-name}` and change it to `- [x] task-{feature-name}` (preserve the rest of the line — priority and readiness tags).
  - Re-sync the progress counters by re-reading all task file statuses and recomputing `X/Y done` for each epic or flat list.
- If `.scratch/plan/plan.md` does not exist: update task file only — no error.

Once the ship subagent completes (and plan updates are done, if applicable), inform the user:

> "Feature '[feature-name]' shipped successfully after [cycle] cycle(s).
>
> Push and PR creation remain manual — run `git push` and open a PR when ready."

If a plan task was tracked, add:

> "Plan task 'task-{feature-name}' marked as done. Progress counters in plan.md updated."

## End of skill
