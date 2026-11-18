---
name: buildit-plan
description: "Use when decomposing a PRD, spec, or ad-hoc request into ordered tasks — creates .scratch/plan/ with epic index, task files, progress tracking, and resume capability. Accepts optional feature name: /buildit-plan [plan-name]."
---

# Plan

Decomposes a structured document (PRD, specs, user stories, bullet points) or an ad-hoc request into ordered epics and tasks, with status tracking and readiness marking for integration with the buildit cycle.

## When to use

Before starting a batch of features, when the scope is larger than a single feature. If the request is already a single well-defined feature, skip this skill and invoke `/buildit-feature-discover` or `/buildit-feature-start` directly.

## Steps

### 0. Detect mode and check resume

Detect your operating mode:
- Run `ls .claude/ 2>/dev/null` — if the directory exists, you are in **Claude mode**; otherwise **Generic mode**.

Check if `.scratch/plan/` exists:
- If `.scratch/plan/plan.md` exists AND at least one `task-*.md` file exists in `.scratch/plan/` — go to **step 7** (resume flow).
- If `.scratch/plan/plan.md` exists but NO `task-*.md` files are found — warn the user about incomplete/corrupt plan state. Offer two options: restart from scratch (delete `plan.md` and continue to step 1) or attempt repair (continue to step 1 with existing `plan.md` as partial input).
- If `.scratch/plan/` does not exist — continue to step 1.

---

### 1. Collect input

Ask the user for the source material:

> "What would you like to decompose into a plan? You can provide:
> - A structured document (PRD, specs, user stories, bullet points)
> - An ad-hoc request describing what you want to build
> - A file path to an existing document"

Accept any format — no schema requirement. The skill works with PRDs, specs, user stories, bullet points, or plain conversational requests.

If a file path is provided, read the file content.

Store the source reference (document title, file path, or summary of the ad-hoc request) for inclusion in `plan.md`.

---

### 2. Choose decomposition path

Ask the user:

> "How would you like to decompose this?
> - **Fast path**: I auto-decompose into tasks/epics, then present for your validation
> - **Coaching path**: we collaboratively identify tasks through targeted questions"

- **Fast path**: proceed to step 3, agent-driven decomposition.
- **Coaching path**: proceed to step 3, but build the decomposition incrementally with user input at each decision point.

---

### 3. Decompose into tasks

Parse the input and identify task boundaries. Use these heuristics:
- Look for numbered lists, section headers, user story patterns (`As a... I want... So that...`), acceptance criteria boundaries
- Identify natural scope breaks: separate concerns, independent deliverables, sequential dependencies
- Each task should be a single feature-sized unit of work (suitable for one `/buildit-feature-run` invocation)

For each task, determine:
- **Name**: kebab-case slug (e.g. `add-auth-middleware`), globally unique across the entire plan
- **Description**: what the task delivers, anchored in the source material
- **Acceptance tests**: verifiable criteria for task completion
- **Priority**: `high`, `medium`, or `low`
- **Readiness**: `ready` if scope is bounded and acceptance tests are clear and verifiable; `needs-scoping` if description is vague, scope is unbounded, acceptance tests are missing, or technical approach is uncertain

**Uniqueness check**: task names are used as filenames. Verify that no two tasks share the same kebab-case name across the entire plan. If a collision is detected, append a disambiguating suffix or ask the user to rename.

**Grouping threshold**:
- If fewer than 3 tasks: use a flat task list, no epic grouping.
- If 3 or more tasks: group into epics. Each epic has a name, description, and contains a subset of related tasks.

**Fast path**: present the full decomposition for user validation. Iterate only on contested parts — do not re-present the entire plan after each change.

**Coaching path**: build the decomposition incrementally. For each potential task, ask the user to confirm scope, acceptance tests, and priority. Propose epic groupings once all tasks are identified.

---

### 4. Create task files

Create the `.scratch/plan/` directory if it does not exist:

```bash
mkdir -p .scratch/plan
```

For each task, create `.scratch/plan/task-{name}.md` using this template:

```markdown
# task-{name}

## Status
todo

## Priority
[high/medium/low]

## Parent epic
[epic name or "none"]

## Description
[task description from step 3]

## Acceptance tests
[list of verifiable criteria from step 3]

## Readiness
[ready/needs-scoping]
```

---

### 5. Create plan.md

Create `.scratch/plan/plan.md`.

**Template with epics** (3 or more tasks):

```markdown
# Plan

## Source
[reference to input document/request]

## Epics

### Epic 1: [name]
[description]

Progress: 0/N done

- [ ] task-{name-1} (high) [ready]
- [ ] task-{name-2} (medium) [needs-scoping]
...

### Epic 2: [name]
[description]

Progress: 0/N done

- [ ] task-{name-3} (high) [ready]
...
```

**Template without epics** (flat list, fewer than 3 tasks):

```markdown
# Plan

## Source
[reference to input document/request]

## Tasks

Progress: 0/N done

- [ ] task-{name-1} (high) [ready]
- [ ] task-{name-2} (medium) [needs-scoping]
```

Progress counters are computed from task file statuses: count files with `## Status` set to `done` vs total task files.

---

### 6. Handoff

Display a progress summary showing all tasks grouped by readiness.

For tasks marked `needs-scoping`:

> "The following tasks need scoping before implementation:
> - `task-{name}` — run `/buildit-feature-discover [task-name]` to produce a structured brief"

For tasks marked `ready`:

> "The following tasks are ready for implementation:
> - `task-{name}` — run `/buildit-feature-run [task-name]` to execute the full cycle"

Suggest the recommended next step based on priority ordering: start with the highest-priority `ready` task, or scope the highest-priority `needs-scoping` task first.

---

### 7. Resume flow (entered from step 0)

Read existing `.scratch/plan/plan.md` and all `task-*.md` files in `.scratch/plan/`.

Present the current plan state: task statuses, progress counters, epic completion.

**Cleanup checks:**

1. **`.scratch/done/` cleanup**: check for files in `.scratch/done/` older than 7 days (by modification time). If found, list them and ask for confirmation before deletion.

   > "The following completed tracking files are older than 7 days:
   > - [file list]
   > Delete them? (yes/no)"

2. **Completed epic cleanup**: check for epics where all tasks have status `done`. If found, propose removing the epic and its task files from `.scratch/plan/`.

   > "The following epics are fully completed:
   > - [epic name] (N/N tasks done)
   > Remove them from the plan? (yes/no)"

**Modification mode** (coaching — ask before each modification):

Present available actions:
- Add new tasks or epics
- Modify existing task descriptions, acceptance tests, priority, or readiness
- Update task statuses (todo/in-progress/done)
- Remove tasks or epics

Ask before each modification — do not apply changes without confirmation.

After all modifications: re-sync progress counters in `plan.md` by re-reading all task file statuses and recomputing `X/Y done` for each epic (or the flat list).

Go to **step 6** (handoff).

## End of skill
