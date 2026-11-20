# discover-plan-task-integration

## Status
to-ship

## Worktree path
none

## Goal
Make `buildit-feature-discover` plan-task aware, closing the loop opened by `buildit-plan` §6 ("needs-scoping tasks → run /buildit-feature-discover [task-name]"), mirroring how `buildit-feature-run` already integrates plan tasks.

- Step 0 (detection): if a `feature-name` is provided, look up `.scratch/plan/task-{feature-name}.md`. If it exists, store `PLAN_TASK_FILE` and extract `## Description`, `## Acceptance tests`, `## Readiness`, `## Status`. The feature name is then locked to the task name (otherwise `buildit-feature-run` will not find the task file). If task Readiness is already `ready` with description + acceptance tests → short-circuit: report it and suggest `/buildit-feature-run [task-name]`, offering to re-scope anyway. If task `## Status` is `in-progress` or `done` → warn and ask for confirmation before re-scoping.
- Phases 1–3: use the task description/ATs as the starting point for functional exploration; do not re-ask questions already answered by the task.
- Phase 5 (on brief validation), if `PLAN_TASK_FILE` is set: replace `## Description` and `## Acceptance tests` in the task file with the brief content; add or replace a `## Risks & Constraints` section; set `## Readiness` to `ready` (brief validation = ready). In `.scratch/plan/plan.md`, on the `task-{name}` line, replace `[needs-scoping]` with `[ready]` (preserve checkbox and priority). If plan.md is missing or the line is not found → update the task file only (warn if line not found), no error. Never modify `## Status` (owned by buildit-feature-run). Handoff recommends `/buildit-feature-run [task-name]` first.
- Without a plan task: behaviour strictly unchanged.

Use the exact readiness strings written by buildit-plan (`ready` / `needs-scoping`). The new `## Risks & Constraints` section stays optional; do NOT modify the buildit-plan template (YAGNI). No design spec required (same pattern as the existing run integration).

## Acceptance Tests
- [x] Step 0 detects `.scratch/plan/task-{feature-name}.md` when `feature-name` is provided and extracts Description / Acceptance tests / Readiness
- [x] Without a matching task file (or without `feature-name`), the skill behaves as before (explicit fallthrough)
- [x] When a task is detected, the feature name is locked to the task name (explicit rule)
- [x] Task `ready` with description + ATs → short-circuit suggesting `/buildit-feature-run [task-name]`, with an option to re-scope
- [x] Task `Status` `in-progress` or `done` → warning + confirmation before continuing
- [x] Phase 2 uses task data as starting point and does not re-ask already-answered questions
- [x] On brief validation: task file Description, Acceptance tests and Risks & Constraints updated, Readiness → `ready`
- [x] On brief validation: in `plan.md`, `[needs-scoping]` → `[ready]` on the task line, checkbox and priority preserved
- [x] `plan.md` missing or line not found → task file updated only, warning if line missing, no error
- [x] The skill explicitly states it never modifies `## Status`
- [x] If the brief is not validated (user stops), task file and plan.md are untouched
- [x] Handoff recommends `/buildit-feature-run [task-name]` when a task is detected
- [x] `skills/` and `.claude/skills/` in sync; all content in English
- [x] `tests/test-buildit-feature-discover.sh` covers the ATs above (content assertions), `tests/run-all.sh` passes
- [x] README (`buildit-feature-discover` section) updated with the plan integration
- [x] Guideline "Plan-task integration in orchestrators" in `.buildit/guidelines/team-practices.md` extended to discover (ownership: Readiness = discover, Status = run)

## Plan

Files touched:
- `skills/buildit-feature-discover/SKILL.md` (canonical) + mirror to `.claude/skills/buildit-feature-discover/SKILL.md` (copy with `cp`, then `diff -q`)
- `tests/test-buildit-feature-discover.sh`
- `README.md` (`buildit-feature-discover` section only)
- `.buildit/guidelines/team-practices.md` ("Plan-task integration in orchestrators" section)

### Step 1 — Failing tests first (`tests/test-buildit-feature-discover.sh`)
Add a "Plan-task integration" block (AT-D1..AT-D12) of `require_regex` / `require_text` assertions against `$SKILL_SRC`, plus README and guideline assertions. Keep the existing AT-1..AT-8 and the sync check untouched. Proposed assertions (regexes kept specific enough to fail before implementation):
- AT-D1 detection: `plan/task-\{feature-name\}\.md` present; `PLAN_TASK_FILE` present; extraction of `## Readiness` mentioned alongside `## Description` / `## Acceptance tests`.
- AT-D2 fallthrough: `PLAN_TASK_FILE=none` and `(fall.?through|unchanged)`.
- AT-D3 name lock: regex `[Ff]eature name is locked to the task name` (or `locked to the task name`).
- AT-D4 ready short-circuit: line containing `ready` and `/buildit-feature-run [task-name]` in step 0; `re-scope` option present.
- AT-D5 status guard: `in-progress` + `done` + `confirm` within the guard (regex `(in-progress|done).*confirm` on same line).
- AT-D6 Phase 2 reuse: `(do not|don't) re-ask` text.
- AT-D7 task file update: `## Risks & Constraints` text; `Readiness.*ready` set rule.
- AT-D8 plan.md: `\[needs-scoping\].*\[ready\]` and `preserve.*(checkbox|priority)`.
- AT-D9 graceful: `plan\.md.*(does not exist|missing).*task file only` and `not found.*warn` (or `warn.*not found`).
- AT-D10 status ownership: `[Nn]ever modif(y|ies).*## Status`.
- AT-D11 not validated: `(not validated|stops|abandon).*untouched`.
- AT-D12 handoff: `/buildit-feature-run [task-name]` in the Phase 5 handoff with "recommended".
- AT-D13 README: README `buildit-feature-discover` section mentions `.scratch/plan/task-` and `needs-scoping` — extract section with `sed -n '/^### `buildit-feature-discover`/,/^---/p'` and grep it.
- AT-D14 guideline: team-practices "Plan-task integration" section mentions `buildit-feature-discover` and `Readiness` ownership — extract section with sed between `### Plan-task integration` and next `### `.
Run the test → confirm failures.

### Step 2 — SKILL.md edits (canonical)
1. Replace "### 0. Short-circuit if brief is already clear" with:
   - **### 0a. Detect plan task** — if `feature-name` provided, check `.scratch/plan/task-{feature-name}.md`.
     - Exists: read it; extract `## Description`, `## Acceptance tests`, `## Readiness`, `## Status`; store `PLAN_TASK_FILE`, `PLAN_DESCRIPTION`, `PLAN_ACCEPTANCE_TESTS`, `PLAN_READINESS`, `PLAN_STATUS`.
     - Name lock rule: "The feature name is locked to the task name — do not rename it in the brief (otherwise `buildit-feature-run` will not find the task file)."
     - Status guard: if `PLAN_STATUS` is `in-progress` or `done` → warn and ask for confirmation before re-scoping; user declines → stop, nothing modified.
     - Ready short-circuit: if `PLAN_READINESS` is `ready` and both description and ATs are non-empty → report and suggest `/buildit-feature-run [task-name]`; offer "re-scope anyway?" — yes → continue Phase 1; no → end skill, nothing modified.
     - Ordering: status guard first, then readiness short-circuit (a done task that's ready should warn first). Keep it simple: guard, then readiness.
     - Not exists / no feature-name: `PLAN_TASK_FILE=none` → fallthrough to existing behaviour unchanged (step 0b).
   - **### 0b. Short-circuit if brief is already clear** — existing text, applies only when `PLAN_TASK_FILE` is `none`.
2. Phase 1: no change except a note? Not needed — keep minimal. Phase 1 step 4 (external docs) still asked (task file is not external doc). Add one line: "If `PLAN_TASK_FILE` is set, also read the task file's parent epic in `.scratch/plan/plan.md` for context"? YAGNI — skip.
3. Phase 2: add a block "When `PLAN_TASK_FILE` is set": start from `PLAN_DESCRIPTION` / `PLAN_ACCEPTANCE_TESTS` — present them as the current understanding, ask only questions they leave unanswered (vague points, missing ATs, uncertain approach); do not re-ask questions already answered by the task.
4. Phase 3: one line — use task description/ATs as input alongside answers (covered by "Phases 1–3" requirement). Keep brief.
5. Phase 4: note brief **Name** = task name when `PLAN_TASK_FILE` set.
6. Phase 5: 
   - On validation, if `PLAN_TASK_FILE` set → "Update plan task" sub-step:
     - Replace `## Description` content with brief description; replace `## Acceptance tests` content with brief ATs; add `## Risks & Constraints` section (after `## Acceptance tests`... place at end of file is simplest; spec says add or replace) — replace if exists else append at end of file.
     - Set `## Readiness` to `ready`.
     - plan.md: if exists, find line containing `task-{feature-name}` (pattern `- [ ] task-{feature-name}` or `- [x]`), replace `[needs-scoping]` with `[ready]`, preserve checkbox and priority. If the line already has `[ready]` → no-op. Line not found → warn "Task line not found in plan.md — task file updated only." plan.md missing → task file only, no error.
     - "Never modify `## Status` — owned by `buildit-feature-run`." Also no progress counter re-sync needed (counters depend on Status only) — state this explicitly.
   - If brief not validated (user stops) → task file and plan.md untouched (explicit line: all writes happen only after validation).
   - Handoff variant when `PLAN_TASK_FILE` set: recommended `/buildit-feature-run [task-name]` first, then `/buildit-feature-start [task-name]`. Otherwise unchanged handoff.
7. Frontmatter description: leave unchanged (quote-skill-descriptions tests; minimal risk). Possibly not needed.
8. `cp skills/... .claude/skills/...`.

### Step 3 — README
In `buildit-feature-discover` section: add to "What it does" a step 0 item about plan task detection (pre-fill, name lock, ready short-circuit, status guard) and a step about updating task file + plan.md on validation; update "Ends with" to mention `/buildit-feature-run [task-name]` recommended when a plan task is detected.

### Step 4 — Guideline
Extend "Plan-task integration in orchestrators" paragraph: add discover behaviour and ownership rule — `## Readiness` (and plan.md `[needs-scoping]`/`[ready]` tag) is owned by `buildit-feature-discover`; `## Status` (and plan.md checkbox + counters) owned by `buildit-feature-run`. Each skill never writes the other's field.

### Step 5 — Verify
`bash tests/test-buildit-feature-discover.sh`, `bash tests/run-all.sh`, `diff -q` skills vs .claude/skills. Check `tests/test-skills-invariants.sh` / `test-dry-kiss-yagni-principles.sh` still pass (they may enforce section structure, e.g. "## End of skill").

### Step 6 — Stage
`git add` all touched files + tracking file before `to-validate` (do NOT stage `.scratch/shared-context.md` changes beyond what the orchestrator wrote — it's already modified by the orchestrator; leave as-is).

### Self-critique (applied)
- **Assumption — step numbering:** existing step 0 is the "brief already clear" short-circuit. Splitting into 0a/0b keeps the existing short-circuit and behaviour for non-plan cases; the existing test AT-8 etc. still pass. Check `test-skills-invariants.sh` doesn't require a specific heading like `### 0.` — verify before editing.
- **Edge case — name provided + description/ATs supplied by user AND task file exists:** plan task takes precedence (0a runs first); user-supplied description is treated as extra input for Phase 2. State: 0b only applies when `PLAN_TASK_FILE` is `none`.
- **Edge case — task `ready` but description or ATs empty:** no short-circuit; continue scoping (Readiness inconsistent). Covered by "with description + acceptance tests" condition.
- **Edge case — Status `done` AND readiness `ready`:** status guard runs first; if user confirms, then readiness short-circuit applies. Acceptable.
- **Edge case — plan.md line has `[ready]` already (re-scope of a ready task):** no-op on plan.md, task file still updated.
- **Edge case — plan.md line matching:** must match `task-{feature-name}` exactly as a token (avoid matching `task-foo-bar` when name is `task-foo`). Instruct: match the line `- [ ] task-{feature-name} ` / `- [x] task-{feature-name} ` (token followed by a space). Keep phrasing simple.
- **Edge case — user renames feature in Phase 5 corrections:** name lock rule forbids it; if user insists, explain the task file link would break and suggest editing the plan via `/buildit-plan` instead. One sentence.
- **Risk — regex tests too loose (always pass) or too tight (fragile):** write each assertion against a distinctive phrase that does not exist today; run the test before implementation to confirm each new assertion fails.
- **Risk — quote-skill-descriptions / invariants tests:** don't touch frontmatter.
- **Risk — Phase 5 progress counters:** counters are computed from Status only, so discover must not re-sync them — state "no progress counter re-sync needed" to avoid an agent doing unnecessary work.
- **Vague step fixed:** "add or replace `## Risks & Constraints`" → explicit location: replace existing section content if present; otherwise append the section after `## Readiness` at end of file.

## Progress
- 18-11-2026 build: added AT-D1..AT-D14 to `tests/test-buildit-feature-discover.sh` (20 new assertions, all failing before implementation on content regexes).
- SKILL.md: step 0 split into 0a (plan task detection, name lock, status guard, ready short-circuit, `PLAN_TASK_FILE=none` fallthrough) and 0b (existing short-circuit, only when no plan task); Phase 2/3/4 plan-aware notes; Phase 5 plan task update (task file sections, Readiness → ready, plan.md tag swap, graceful missing plan.md/line, never modify Status, no writes if not validated) and plan handoff recommending `/buildit-feature-run [task-name]`.
- `.claude/skills/buildit-feature-discover/SKILL.md` is a symlink to the canonical file — in sync by construction.
- README discover section and team-practices "Plan-task integration in orchestrators" guideline (ownership: Readiness = discover, Status = run) updated.
- `bash tests/run-all.sh`: 418 passed, 0 failed.
