# task-discover-plan-integration

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 findings #12, #13, #19, #25 (audit fallback part only; the bootstrap wording part of #25 is out of scope).

Scoped design (decisions taken by discover, see Risks & Constraints):
- **#19 Generic discover:** discover's Phase 1 overlap scan, Phase 2 questions and Phase 3 impact list talk about features, components and project modules instead of skills. Phase 1 step 3 scans the project's modules: the source directories detected from the repository layout (e.g. `src/`, `lib/`, `app/`, `packages/`, or `$SKILLS_DIR` when the project is a skills framework) and reads their entry points / README headers to spot overlaps. Phase 2 asks "what problem does this feature solve?", "who uses this feature?", "How does this feature differ from `[module]`?". The Operating mode rule block stays byte-identical (tests/test-mode-detection.sh).
- **#12 Manual flow:** documentation only, ship is not changed. Discover's plan handoff and README (discover section and Manual flow section) state that the manual path (start → ship) does not track plan status: the task stays `todo` in `.scratch/plan/`, so after ship the user updates the task `## Status`, the `plan.md` checkbox and progress counters themselves (or uses `/buildit-feature-run`, which tracks them). Run stays the single owner of plan `## Status`.
- **#13 `task-` prefix:** plan's handoff (step 6) and discover's handoffs / ready short-circuit print the exact command with the bare name (`/buildit-feature-run {name}`, `/buildit-feature-discover {name}`, `/buildit-feature-start {name}`), not `[task-name]` next to a `task-{name}` label. Run and discover share one named block, `**Plan task lookup rule**`, byte-identical in both: look up `.scratch/plan/task-{feature-name}.md`; if it is missing and the argument starts with `task-`, strip the prefix once, retry, and if the stripped lookup finds the task, use the bare name as `feature-name` from then on and tell the user ("Stripped the `task-` prefix: using feature name `{name}`."). README's `[task-name]` mentions are aligned.
- **#25 Audit fallback:** the audit hotspot fallback scans the source directories detected from the repository layout (whichever of `src/`, `lib/`, `app/`, `packages/`, `skills/`, ... exist, from the build manifest or top-level tree), excluding `.scratch/`, docs, vendored and generated directories — `skills/` is not preferred.

### Risks & Constraints
- Decision #12 = documentation, not ship: ship runs as run's subagent, so ship updating the plan would double-write with run step 6 and break run's "verify ship before closing the task" order; documenting keeps ship's step order contract untouched and plan `## Status` owned by run only (discover already states that).
- Decision #13 = strip with a shared named block: tolerant and quiet, and the "no duplicated logic without a shared named block" rule needs one block in run and discover, tested byte-identical. The un-prefixed lookup runs first so a feature genuinely named `task-x` with `task-task-x.md` still works.
- Decision #19 = keep the Operating mode rule and `SKILLS_DIR` in discover (needed for skills-framework projects and the mode-detection test), only widen the scan.
- Existing tests that grep `ls ... skills` (discover AT-2) and `[task-name]` (discover AT-D4, AT-D12) must be updated, not deleted.
- README headings must stay unique (AT-R9): edit sections in place.
- Contracts to keep: Config value rule, Tracking file discovery rule, Operating mode rule, run autonomy block, run step 6, ship step order.

## Acceptance Tests
- AT-1: discover's overlap scan and questions refer to features/components and project modules (detected source directories), not skills: no "this skill" in Phase 2 questions, no `ls $SKILLS_DIR`-only overlap scan; the Operating mode rule block is unchanged.
- AT-2: discover's plan handoff and README state that the manual flow (start → ship) does not update the plan task (status, checkbox, progress) and say what the user must do; ship is unchanged.
- AT-3: plan step 6 and discover print commands with the bare name (no `[task-name]` placeholder left in plan, discover or README); a `**Plan task lookup rule**` block is byte-identical in run and discover and strips a leading `task-` when the prefixed lookup misses.
- AT-4: the audit hotspot fallback uses source directories detected from the repository layout and no longer says "`skills/` directory (or `src/` if present)".
- AT-5: tests assert AT-1 to AT-4 (existing discover/plan tests updated, new checks for the shared block); `bash tests/run-all.sh` passes.

## Plan
### Files in scope
- `skills/buildit-feature-discover/SKILL.md` (#19, #12, #13)
- `skills/buildit-feature-run/SKILL.md` (#13 shared block only)
- `skills/buildit-plan/SKILL.md` (#13 step 6 handoff)
- `skills/buildit-project-audit/SKILL.md` (#25 hotspot fallback)
- `README.md` (discover section, Manual flow section, plan section, `[task-name]` mentions)
- `tests/test-buildit-feature-discover.sh`, `tests/test-buildit-plan.sh`, `tests/test-buildit-feature-run.sh`, `tests/test-buildit-project-audit.sh`, `tests/test-readme.sh`
- `.claude/skills` is a symlink to `../skills`: edit only `skills/` (no duplicate copy).

### Step 1 — Failing tests first (RED)
1. `tests/test-buildit-feature-discover.sh`:
   - Replace AT-2 `(ls|scan|list).*skills` with a check that Phase 1 step 3 scans project modules / detected source directories (e.g. regex `source directories` and `src/`, `lib/`, `app/`, `packages/`), and `require_absent` for the old line `Scan existing skills: \`ls \$SKILLS_DIR\``.
   - New AT-1 checks: `require_absent` "what problem does this skill solve", "who invokes this skill", "How does this skill differ"; `require_text` for "what problem does this feature solve", "who uses this feature", "How does this feature differ from `[module]`".
   - Update AT-D4 to expect `/buildit-feature-run {feature-name}` style (bare name, regex `PLAN_READINESS.*ready.*/buildit-feature-run \{feature-name\}`) and AT-D12 to expect `/buildit-feature-run {feature-name}`.*recommended`; add `require_absent` for `[task-name]`.
   - AT-2 (#12): handoff mentions the manual flow does not update the plan task, with the user actions (`## Status`, `plan.md` checkbox, progress counters).
2. `tests/test-buildit-plan.sh`: `require_absent '[task-name]'`; step 6 handoff prints `/buildit-feature-discover {name}` and `/buildit-feature-run {name}`.
3. Shared block test (in `tests/test-buildit-feature-run.sh` or `test-skills-invariants.sh`, whichever already hosts cross-skill byte-identity checks — check how test-mode-detection.sh extracts a block and reuse its helper): extract the `**Plan task lookup rule**` block from run and discover (from the bold heading to the next blank-line-terminated paragraph/list end), assert it is present in both, byte-identical, and contains the strip rule (`task-` prefix, "Stripped the `task-` prefix").
4. `tests/test-buildit-project-audit.sh`: `require_absent` "full \`skills/\` directory (or \`src/\` if present)"; require text for "source directories detected from the repository layout" and exclusions (`.scratch/`, docs, vendored, generated).
5. `tests/test-readme.sh`: `require_absent '[task-name]'`; Manual flow section and discover section state the plan task is not updated by the manual path.
6. Run `bash tests/run-all.sh` — new checks must FAIL, others pass.

### Step 2 — Discover (#19)
- Phase 1 step 2: "skill file format" stays (guideline extraction is generic enough) but phrase as "file formats".
- Phase 1 step 3: "Scan existing project modules: detect the source directories from the repository layout (whichever of `src/`, `lib/`, `app/`, `packages/` exist, or `$SKILLS_DIR` when the project is a skills framework) and read the entry points / README headers (for skills: the name and description of each `SKILL.md`)". Keep `SKILLS_DIR` definition and the Operating mode rule block untouched.
- Phase 2: questions use "feature"; overlap question "How does this feature differ from `[module]`?" ("If a similar feature/module exists").
- Phase 3 impact list: replace skill-specific wording with components/modules (keep skills as one example).

### Step 3 — Plan task lookup rule (#13)
- Write one block, used verbatim in discover step 0a and run "Detect plan task":
  ```
  **Plan task lookup rule**
  - Look up `.scratch/plan/task-{feature-name}.md`.
  - If it is missing and `feature-name` starts with `task-`, strip that prefix once and retry the lookup.
  - If the stripped lookup finds the task, use the bare name as `feature-name` from then on and tell the user: "Stripped the `task-` prefix: using feature name `{feature-name}`."
  - If neither lookup finds a task file, there is no plan task.
  ```
  (un-prefixed lookup first so `task-task-x.md` for a feature `task-x` still works).
- Discover 0a and run "Detect plan task" open with "If `feature-name` was provided as argument, apply the **Plan task lookup rule**." then keep their existing branches. Do not touch run's Subagent autonomy block or step 6.
- Discover ready short-circuit and Phase 5 handoff: `/buildit-feature-run {feature-name}`, `/buildit-feature-start {feature-name}`; handoff label "plan task 'task-{feature-name}'" may stay (it is the file label) but the commands use the bare name.
- Plan step 6: `- task-{name} — run \`/buildit-feature-discover {name}\`...` and `/buildit-feature-run {name}`.

### Step 4 — Manual flow doc (#12)
- Discover Phase 5 handoff: under the `/buildit-feature-start {feature-name}` option add: the manual path (start → ship) does not track plan status — the task stays `todo` in `.scratch/plan/`; after ship, update the task `## Status` to `done`, tick the `plan.md` checkbox and recompute the progress counters yourself (or use `/buildit-feature-run`, which tracks them).
- README Manual flow section: add one paragraph (no new heading) with the same statement. README discover section "Ends with": same note. Ship skill is NOT modified.

### Step 5 — Audit fallback (#25)
- Replace the fallback bullet with: "fall back to scanning the source directories detected from the repository layout (whichever of `src/`, `lib/`, `app/`, `packages/`, `skills/`, ... exist, from the build manifest or the top-level tree), excluding `.scratch/`, documentation, vendored and generated directories". Update README audit section if it repeats the old wording (grep).

### Step 6 — README alignment
- Replace every `[task-name]` with the bare-name form (`{name}`), lines ~373, 386, 396. No heading added or renamed (AT-R9).

### Step 7 — Verify (GREEN)
- `bash tests/run-all.sh` all green, notably test-mode-detection.sh, test-tracking-file-discovery.sh, test-config-parsing-boundary.sh, test-readme.sh, test-buildit-feature-ship.sh (ship untouched), test-buildit-feature-run.sh (step 6, autonomy block once).
- `git diff --stat` must not list `.scratch/plan/` or `skills/buildit-feature-ship/`.
- Stage all modified files before `to-validate`.

### Self-critique (applied)
- Assumption: a byte-identity extraction helper exists for named blocks — verify in `tests/test-mode-detection.sh` / `tests/lib`; if not, write a small awk extractor (from `**Plan task lookup rule**` line to the first blank line after the list) inside the test, no new lib file unless reused.
- Edge case: argument `task-` alone (strip → empty name) → the rule must only strip when the remainder is non-empty; add "and the remainder is non-empty" to the block.
- Edge case: both `task-x.md` and `task-task-x.md` exist → un-prefixed lookup wins (first), documented in the block order.
- Edge case: discover name lock — after stripping, the locked name is the bare name; the "Name lock" bullet already refers to `feature-name`, which now holds the bare name. Run's later steps (step 6 checkbox `task-{feature-name}`) also use the bare name — consistent.
- Risk: grep-based tests on `{feature-name}` braces need escaping in regex (`\{`); prefer `require_text` (fixed string) where possible.
- Risk: README may mention `skills/` fallback for audit; grep `src/\` if present` across repo (incl. bootstrap kit templates) and align only audit-fallback wording (bootstrap wording of #25 is out of scope).
- Risk: other tests may grep the old discover Phase 2 wording (e.g. test-skills-invariants.sh, test-dry-kiss-yagni-principles.sh) — grep tests for "this skill" / "SKILLS_DIR" before editing and update, not delete.
- Do not modify `.scratch/plan/` or commit (orchestrator constraint for this run).

## Progress
- 24-11-2026 build: RED tests added (discover AT-2/AT-G1/AT-D4/AT-D12/AT-M1, plan AT-H1, run AT-PL-1..4, audit AT-F1, README AT-R10/AT-R11), then implemented steps 2-6; full suite 858 passed, 0 failed. Feature files staged.
