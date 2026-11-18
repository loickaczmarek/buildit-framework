# buildit-plan

## Status
to-ship

## Worktree path
none

## Goal
Decomposes a PRD or structured request into ordered epics and tasks in `.scratch/plan/`, with status tracking, resume/cleanup capability, and readiness marking for integration with the buildit cycle.

## Acceptance Tests
1. Accepts any structured document as input (PRD, user stories, specs, bullet points) — not limited to bmad format
2. Accepts a simple ad-hoc request as input (non-document) and decomposes into tasks without mandatory epic grouping
3. Creates `.scratch/plan/plan.md` with: source reference, epic index (descriptions, task lists, progress per epic), or flat task list if fewer than 3 tasks
4. Creates `.scratch/plan/task-{name}.md` per task with: name, status (todo/in-progress/done), priority, parent epic (if any), description, acceptance tests, readiness (ready/needs-scoping)
5. Offers fast path (auto-decompose then validate) and coaching path (collaborative question-driven decomposition)
6. Tasks marked `needs-scoping` trigger a suggestion to run `/buildit-feature-discover [task-name]` before `/buildit-feature-run`
7. On resume: detects existing `.scratch/plan/`, adds new tasks/epics, modifies existing ones, updates statuses — in coaching mode (asks before modifying)
8. On resume: cleans `.scratch/done/` files older than 7 days (asks confirmation before deletion)
9. On resume: proposes cleanup of completed epics and their tasks in `.scratch/plan/` (asks before deleting)
10. `plan.md` progress counters stay in sync with individual task file statuses
11. Skill ends with explicit handoff: lists actionable tasks and suggests next step (`/buildit-feature-discover` or `/buildit-feature-run`)
12. Follows dual-deployment (`skills/` + `.claude/skills/`)
13. Skill file in English only
14. Design spec in `docs/buildit/specs/`
15. README updated with new skill entry

## Plan

### Step 1: Write design spec
Create `docs/buildit/specs/2026-10-22-buildit-plan-design.md` documenting:
- Input flexibility: structured documents vs ad-hoc requests — the skill detects input type from conversation context, not a flag
- Epic/flat threshold: < 3 tasks => flat list in plan.md (no epic grouping); >= 3 tasks => grouped into epics
- Fast path vs coaching path: fast = agent auto-decomposes then presents for validation; coaching = iterative question-driven decomposition
- Resume detection: check `.scratch/plan/` existence at step 0
- Progress synchronization: plan.md counters computed from task file statuses, re-synced on resume
- `.scratch/done/` cleanup: 7-day threshold, confirmation-gated
- Integration with buildit cycle: each task maps to a `/buildit-feature-run` or `/buildit-feature-discover` invocation
- Readiness criteria: `ready` if scope is bounded and acceptance tests are clear; `needs-scoping` if description is vague or acceptance tests are missing

### Step 2: Create skill file
Create `skills/buildit-plan/SKILL.md` with YAML frontmatter and the following step structure:

**Step 0 — Detect mode and check resume**
- Detect Claude vs generic mode (`ls .claude/ 2>/dev/null`)
- Check if `.scratch/plan/` exists — if yes, go to step 6 (resume flow)

**Step 1 — Collect input**
- Ask the user for the source: structured document (PRD, specs, user stories, bullet points) or ad-hoc request
- Accept any format — no schema requirement (AT-1, AT-2)
- Store the source reference for plan.md

**Step 2 — Choose decomposition path**
- Ask the user: fast path or coaching path? (AT-5)
- Fast path: agent auto-decomposes into tasks/epics, presents for validation
- Coaching path: agent asks targeted questions to collaboratively identify tasks, boundaries, and priorities

**Step 3 — Decompose into tasks**
- Parse the input and identify task boundaries
- For each task, determine: name (kebab-case), description, acceptance tests, priority (high/medium/low), readiness (ready/needs-scoping)
- Readiness criteria: `ready` if scope is bounded and acceptance tests are clear; `needs-scoping` if vague or missing tests
- If < 3 tasks: flat list, no epic grouping (AT-2, AT-3)
- If >= 3 tasks: group into epics with descriptions (AT-3)
- Fast path: present decomposition for user validation; iterate on contested parts
- Coaching path: build incrementally with user input

**Step 4 — Create task files**
- Create `.scratch/plan/` directory
- For each task, create `.scratch/plan/task-{name}.md` with: name, status (todo), priority, parent epic (if any), description, acceptance tests, readiness (AT-4)
- Template:
  ```
  # task-{name}
  ## Status
  todo
  ## Priority
  [high/medium/low]
  ## Parent epic
  [epic name or "none"]
  ## Description
  [task description]
  ## Acceptance tests
  [list]
  ## Readiness
  [ready/needs-scoping]
  ```

**Step 5 — Create plan.md**
- Create `.scratch/plan/plan.md` with: source reference, epic index (or flat task list), progress counters per epic (AT-3, AT-10)
- Counters computed from task file statuses: `X/Y done`
- Template (with epics):
  ```
  # Plan
  ## Source
  [reference to input document/request]
  ## Epics
  ### Epic 1: [name]
  [description]
  Progress: 0/N done
  - [ ] task-{name-1} (priority) [ready/needs-scoping]
  - [ ] task-{name-2} ...
  ### Epic 2: ...
  ```
- Template (flat, < 3 tasks):
  ```
  # Plan
  ## Source
  [reference]
  ## Tasks
  Progress: 0/N done
  - [ ] task-{name-1} (priority) [ready/needs-scoping]
  - [ ] task-{name-2} ...
  ```

**Step 6 — Handoff (also used after resume)**
- List all actionable tasks grouped by readiness (AT-11)
- For `needs-scoping` tasks: suggest `/buildit-feature-discover [task-name]` (AT-6)
- For `ready` tasks: suggest `/buildit-feature-run [task-name]`
- Display progress summary

**Step 7 — Resume flow (entered from step 0)**
- Read existing `.scratch/plan/plan.md` and all task files
- Present current plan state (statuses, progress)
- Check `.scratch/done/` for files older than 7 days: if found, list them and ask confirmation before deletion (AT-8)
- Check for completed epics (all tasks `done`): propose cleanup from `.scratch/plan/` (AT-9)
- Enter coaching mode: present options (add tasks, modify existing tasks, update statuses, add epics) — ask before each modification (AT-7)
- After modifications: re-sync progress counters in plan.md (AT-10)
- Go to step 6 (handoff)

### Step 3: Deploy copy
Copy `skills/buildit-plan/SKILL.md` to `.claude/skills/buildit-plan/SKILL.md` (AT-12).

### Step 4: Create tests
Create `tests/test-buildit-plan.sh` with content-assertion tests mapping to each acceptance criterion:
- AT-1: skill accepts structured documents (grep for PRD, specs, user stories, bullet points)
- AT-2: skill accepts ad-hoc requests and flat task list (grep for ad-hoc, flat)
- AT-3: plan.md structure with source, epic index, progress (grep for plan.md, source, epic, progress)
- AT-4: task file structure (grep for task-{name}, status, priority, readiness, needs-scoping)
- AT-5: fast and coaching paths (grep for fast, coaching)
- AT-6: needs-scoping triggers discover suggestion (grep for needs-scoping, buildit-feature-discover)
- AT-7: resume detection and coaching mode (grep for resume, .scratch/plan/, coaching)
- AT-8: .scratch/done/ cleanup > 7 days (grep for done, 7 day, confirmation)
- AT-9: completed epic cleanup (grep for completed epic, cleanup)
- AT-10: progress counter sync (grep for progress, sync, counter)
- AT-11: handoff with actionable tasks (grep for handoff or next step, buildit-feature-run)
- Dual-deployment check (file existence + diff)

### Step 5: Update invariant tests
Add `buildit-plan` to the SKILLS array in `tests/test-skills-invariants.sh`.

### Step 6: Update README
- Update skill count from "8 skills" to "9 skills" in the intro line
- Add a `### buildit-plan` section in the Skills list (between `buildit-project-audit` and `buildit-feature-discover`, since it sits at the planning stage before feature discovery)
- Update the flow diagram to show `buildit-plan` as an optional upstream step before `buildit-feature-discover`

### Self-critique corrections

**Assumption: `.scratch/plan/` won't conflict with existing `.scratch/` conventions.**
Verified: `.scratch/` currently holds only `shared-context.md` and `done/`. The `plan/` subdirectory introduces a new namespace that doesn't collide with `DD-MM-YYYY-*.md` tracking files.

**Assumption: no argument needed for plan name.**
The plan is a singleton (`.scratch/plan/plan.md` is a fixed path). There is only one active plan at a time. If the user runs `/buildit-plan` again, resume flow takes over. This is consistent with ATs 7-9.

**Edge case: what if plan.md exists but `.scratch/plan/` has no task files?**
The resume flow should handle this gracefully — detect an incomplete/corrupt plan state and offer to start fresh or repair. Added: the skill should check for plan.md AND at least one task file before entering resume mode. If plan.md exists but no task files, warn and offer to restart.

**Edge case: task name collisions across epics.**
Task names are kebab-case slugs used as filenames. If two epics have tasks with the same name, the files would collide. The skill must ensure task names are globally unique across the plan. Added: uniqueness check during decomposition.

**Edge case: priority field values.**
The acceptance tests mention "priority" but don't constrain values. Using high/medium/low aligns with common project management conventions and keeps the schema simple.

**Risk: the invariant test WRITERS array.**
This skill does NOT write to `shared-context.md`, so it should NOT be added to the WRITERS array. Verified.

**Risk: README flow diagram.**
The current README flow diagram uses ASCII art with specific character widths. Inserting `buildit-plan` must preserve the visual alignment. The diagram should show it as an optional step before `buildit-feature-discover` or `buildit-feature-run`.

**Vague step: "Parse the input and identify task boundaries."**
This is intentionally high-level because the agent uses its language understanding to parse arbitrary input. The skill file should provide heuristics: look for numbered lists, section headers, user story patterns, acceptance criteria boundaries, and natural scope breaks. The agent applies judgement — the skill cannot enumerate every possible input format.

**Missing from initial plan: readiness criteria definition.**
Added to Step 3: `ready` means scope is bounded and acceptance tests are clear and verifiable. `needs-scoping` means the description is vague, scope is unbounded, acceptance tests are missing, or technical approach is uncertain.

## Progress
### Build cycle 1
- Step 1: design spec created at `docs/buildit/specs/2026-10-22-buildit-plan-design.md`
- Step 2: skill file created at `skills/buildit-plan/SKILL.md` (7 steps: detect/resume, collect, choose path, decompose, create tasks, create plan.md, handoff + resume flow)
- Step 3: deployed copy via `.claude/skills` symlink (no separate copy needed)
- Step 4: test file created at `tests/test-buildit-plan.sh` (34 tests, all pass)
- Step 5: `buildit-plan` added to SKILLS array in `tests/test-skills-invariants.sh` and `tests/test-quote-skill-descriptions.sh`
- Step 6: README updated — skill count 8->9, flow diagram with `buildit-plan` upstream of `buildit-feature-discover`, new skill section, reference added
- Full test suite: 362 passed, 0 failed
