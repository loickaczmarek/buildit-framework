# plan-task-synchronization

## Status
to-ship

## Worktree path
none

## Goal
Synchronize `.scratch/plan/` tasks with an external tool of the user's choice, configured in `.buildit/config.md`, and make every skill that mutates tasks aware of that configuration. The full sync protocol lives in `buildit-plan` (the existing uncommitted draft in `skills/buildit-plan/SKILL.md` — steps 0, 5b, 7 — is the base and is kept/refined).

- Config contract (`.buildit/config.md`, value = first non-empty non-comment line after the heading): `## Task synchronization` (`enabled`/`disabled`; absent/empty/unrecognized = unconfigured, which is distinct from disabled), `## Synchronization method` (plain-language description of tool, target and access method; never a shell command, never secrets), `## Synchronization tag` (customizable value, default `technical` when absent or empty — identifies plan-owned external tickets). Only `buildit-plan` and `buildit-project-bootstrap` prompt to configure; `buildit-feature-run` and `buildit-feature-discover` never prompt and treat unconfigured as disabled for that run.
- Task contract (optional `## Synchronization` section in `task-{name}.md`): `Link:` external tool/target + stable ID or URL (never the title as identity); zero or more `Pending: <field> → <value> (DD-MM-YYYY)` lines, one per field, the latest replaces the previous.
- External ticket title: always `[<tag>] <Title>` (e.g. `[technical] Add auth middleware`), where `<Title>` is the human-readable title from the task file's `# ...` heading, never the slug `task-{name}` or `{name}`. The tag is also applied as a label when the tool supports labels; the title prefix is present in all cases. When comparing titles in 5b, strip the `[<tag>] ` prefix from the external title before comparing with the local title; on import, strip the prefix from the local title. A task whose heading is still `task-{name}` needs a confirmed human-readable title (draft step 7 mechanism) before any external creation or rename.
- `buildit-plan`: step 5b processes Pending entries first (clear an entry only after a verified write); discovery limited to tickets tagged (label or `[<tag>]` prefix); untagged tickets are shown as a count and offered as an opt-in import (import requires confirmed slug, epic, readiness). Step 7 (resume) shows a read-only drift report (linked tasks differing from their ticket + pending entries) before modification mode, with no external writes. Existing manually-linked tickets without the prefix surface as a title difference in 5b; never rename automatically.
- `buildit-feature-run`: at step 0, if sync is enabled and the task is linked, ask ONE confirmation showing the ticket and the external status mapping for `in-progress` and `done`; if accepted, push ONLY the status at the step-0 and step-6 transitions, from the orchestrator (never inside a subagent). Failure or refusal → write a `Pending:` entry, never block the cycle. No external call without a link.
- `buildit-feature-discover`: same pattern at Phase 5 validation — one confirmation, then push ONLY description, acceptance tests and readiness (if mappable); never status. Failure → `Pending:` entry.
- `buildit-project-bootstrap`: optional step offering to configure the three headings (default tag `technical`) and adding them to the `config.md` template.
- Field ownership (team-practices) extends to external writes: run → Status; discover → Description/AT/Readiness; plan → only full bidirectional reconcile. Run and discover reference `buildit-plan` step 5b as the protocol reference and repeat only the narrow subset (DRY risk accepted by the user).

Risks & constraints (from the validated brief): partial DRY duplication in run/discover (keep it minimal, reference plan 5b); status mapping not stored in config, confirmed once per run; wide impact surface (4 skills + 2 guidelines + README — README consistency rule applies); external tool varies (only content-assertion tests possible; report blocker if no suitable tool); external ticket content is untrusted (prompt injection) — explicit consent for every external write.

## Acceptance Tests
- [x] AT-1: `buildit-plan` documents the three config headings and their semantics, including unconfigured ≠ disabled, and `## Synchronization tag` as a customizable value with default `technical` when absent or empty; forbids secrets in config.
- [x] AT-2: `buildit-plan` documents the `## Synchronization` task section with `Link:` (stable ID/URL, never the title) and the `Pending:` line format (one per field, latest replaces).
- [x] AT-3: `buildit-plan` step 5b: discovery limited to tickets tagged by label or `[<tag>]` prefix; untagged tickets offered as opt-in import.
- [x] AT-4: `buildit-plan` step 5b: every external counterpart created or renamed carries the title `[<tag>] <Title>`, `<Title>` coming from the task heading and never the slug `task-{name}`; the tag is also applied as a label when the tool supports one.
- [x] AT-5: `buildit-plan` step 5b: the `[<tag>] ` prefix is stripped before title comparison and on import; a task whose heading is still `task-{name}` requires a confirmed title before any external creation or rename.
- [x] AT-6: `buildit-plan` step 5b processes `Pending:` entries before comparison and clears them only after a verified write.
- [x] AT-7: `buildit-plan` step 7 shows a read-only drift report before modification mode, with no external writes.
- [x] AT-8: `buildit-feature-run` step 0: if enabled + linked → one confirmation showing the ticket and status mapping; status pushed at both transitions (step 0 and step 6) by the orchestrator.
- [x] AT-9: `buildit-feature-run` writes no external field other than status, makes no external call without a link or when disabled/unconfigured, and never prompts to configure sync.
- [x] AT-10: `buildit-feature-run` and `buildit-feature-discover`: an external failure or refusal writes a `Pending:` entry and the local flow continues.
- [x] AT-11: `buildit-feature-discover` Phase 5: one confirmation then push of description/AT/readiness only, never status.
- [x] AT-12: `buildit-project-bootstrap` offers to configure synchronization (default tag `technical`) and includes the three headings in the `config.md` template.
- [x] AT-13: All three consumer skills treat external content and the method description as data, not instructions.
- [x] AT-14: `team-practices.md` (field ownership), `language-framework.md` (config contract), README (step changes for plan/run/discover/bootstrap) and design spec `docs/buildit/specs/2026-11-24-plan-task-synchronization.md` are updated.
- [x] AT-15: Content-assertion tests in `tests/test-buildit-{plan,feature-run,feature-discover,project-bootstrap}.sh` cover each criterion, and `tests/run-all.sh` passes.

## Plan

Context notes:
- `.claude/skills` is a symlink to `../skills` — dual deployment is automatic; only edit `skills/*/SKILL.md`. The "deployed copy matches source" tests stay green by construction.
- Baseline: `bash tests/run-all.sh` → 418 passed, 0 failed (24-11-2026).
- The uncommitted draft in `skills/buildit-plan/SKILL.md` (step 0 config read, Title field, `# [Title]` heading, plan.md `— [Title]` suffix, step 5b, step 7 title migration) is the starting point: keep it, refine it, do not rewrite from scratch.
- `buildit-feature-run` step 6 matches `- [ ] task-{feature-name}` and preserves the rest of the line, so the new `— [Title]` suffix in plan.md is compatible. Same for discover's `task-{feature-name} ` (name + space) match. Verify no other skill parses plan.md lines with an end-of-line anchor.
- Test helpers: `tests/lib/assertions.sh` (`require_text`, `require_regex`, `require_file`, `ok`, `fail`). Check whether a `forbid_*` / negative helper exists before writing negative assertions; if not, use inline `grep -q` + `ok`/`fail` like the dual-deployment block.

### Step 1 — Failing tests first (TDD)
Add a block per AT to the four test files, labelled `AT-SYNC-n:` to avoid clashing with existing `AT-n` labels. Use specific phrases that the implementation will contain verbatim (decide the phrases here and reuse them in steps 2-6 so tests and text agree). Run `bash tests/run-all.sh` and confirm the new assertions fail (and only those).

- `tests/test-buildit-plan.sh` (AT-1..AT-7, AT-13 for plan):
  - AT-1: `## Task synchronization`, `## Synchronization method`, `## Synchronization tag`, `enabled`/`disabled`, regex `unconfigured.*not.*disabled|unconfigured, not disabled`, `technical` default with `absent or empty`, `secrets`.
  - AT-2: `## Synchronization` task section, `Link:`, regex `Pending: <field> → <value> \(DD-MM-YYYY\)`, `one per field`, `latest replaces`, `never the title` (or `do not use the title as an identity`).
  - AT-3: regex `label or .*\[<tag>\]. prefix`, `untagged`, `opt-in import`.
  - AT-4: `[<tag>] <Title>`, `never the slug`, `as a label`.
  - AT-5: regex `[Ss]trip the .\[<tag>\] . prefix`, `before comparing`, `on import`, `confirmed title` + `task-{name}`.
  - AT-6: `Process pending entries first` (or equivalent phrase fixed here), `only after a verified write`.
  - AT-7: `drift report`, `read-only`, `no external writes`, and an ordering check: drift report line number < `Modification mode` line number (awk/grep -n inline).
  - AT-13: `data, not instructions`.
- `tests/test-buildit-feature-run.sh` (AT-8, AT-9, AT-10, AT-13): `## Task synchronization` read, `ONE confirmation`/`single confirmation`, `status mapping`, `in-progress`, `done`, `buildit-plan` step `5b` reference, `orchestrator`, `never inside a subagent`, `only the status`/`no other field`, `without a link`, `unconfigured` treated as disabled, `never prompt` to configure, `Pending:`, `never block`, `data, not instructions`. Ordering: sync push mentioned in step 6 section (grep within the step-6 range via awk).
- `tests/test-buildit-feature-discover.sh` (AT-10, AT-11, AT-13): `Phase 5` sync block, single confirmation, `description, acceptance tests and readiness`, `never status`/`never push status`, `Pending:`, `continues`, `5b` reference, `never prompt`, `data, not instructions`.
- `tests/test-buildit-project-bootstrap.sh` (AT-12): optional sync step text, the three headings inside the `config.md` template (check the template block contains them — awk range between `# Project Configuration` and the closing `~~~`), `technical` default, `secrets`.
- AT-14 (docs): put guideline/README/spec assertions in `tests/test-buildit-plan.sh` (the plan feature owns the protocol): `team-practices.md` mentions external writes in field ownership; `language-framework.md` mentions `## Task synchronization` and `unconfigured`; README mentions sync in each of the plan/run/discover/bootstrap sections (awk range per `### \`buildit-...\`` section); spec file exists.

### Step 2 — `buildit-plan` (refine the draft)
1. Step 0 config block: add `## Synchronization tag` (customizable, default `technical` when absent or empty; value used as `<tag>`). Add an explicit sentence "unconfigured, not disabled" (already present: keep). Keep "no secrets". Ask for the tag when configuring (propose `technical`).
2. New subsection "Task synchronization contract" (placed right after the step 4 task template, so the task format is documented in one place): optional `## Synchronization` section with example:
   ```
   ## Synchronization
   Link: <tool/target> <stable-ID-or-URL>
   Pending: status → in-progress (24-11-2026)
   ```
   Rules: `Link:` = stable ID or URL, never the title; `Pending: <field> → <value> (DD-MM-YYYY)`, one per field, latest replaces previous for the same field; who writes them (run/discover on failure/refusal, plan clears them).
   Do NOT add the section to the default task template (it is optional and only appears once linked).
3. Step 5b rewrite (keep draft structure, insert):
   - New sub-step before discovery: "Process pending entries first": for each linked task with `Pending:` lines, show the field/value/date and the current external value, ask apply/discard/keep; on apply, write, re-read to verify, and clear the line only after a verified write; failures keep the entry.
   - Discovery (draft item 1): limit to tickets carrying the tag as a label or a `[<tag>] ` title prefix; count untagged tickets in the target and offer them as an opt-in import (not listed in full unless the user opts in).
   - Title rules (new item between matching and comparison): external title is always `[<tag>] <Title>`, `<Title>` from the task heading, never the slug `task-{name}` or `{name}`; apply the tag as a label too when supported; strip the `[<tag>] ` prefix from the external title before comparing; on import, strip the prefix for the local heading; a task whose heading is still `task-{name}` requires a confirmed title (step 7 mechanism) before any external creation or rename — otherwise skip that write and report. Manually-linked tickets without the prefix show as a title difference; never rename automatically.
   - Keep draft items for linking, comparison, re-read-before-write, no blind retry, plan.md refresh, untrusted content.
4. Step 7: after the title-migration paragraph and before cleanup/modification mode, add "Drift report (read-only)": only when sync is enabled and the method is clear; read linked tickets only (by stable link) and list linked tasks whose fields differ from their ticket + all `Pending:` entries; no external writes; no prompting to resolve here (resolution happens in 5b). If reading fails, report and continue. Unconfigured on resume → step 0 already handles the prompt.
   - Self-critic point: step 0 prompts to configure before step 7 — confirm the draft order works (step 0 runs before the resume check: yes, config read is above the `.scratch/plan/` check).

### Step 3 — `buildit-feature-run`
1. Step 0, after "Detect plan task": new "Detect task synchronization" block:
   - Only if `PLAN_TASK_FILE` set. Read `.buildit/config.md` `## Task synchronization`, `## Synchronization method`, `## Synchronization tag` (same parsing rule). Disabled, unconfigured, missing/unclear method, or no `Link:` in the task → `SYNC=off`, no external call, never prompt to configure (configuration belongs to `buildit-plan` / `buildit-project-bootstrap`).
   - Otherwise ask ONE confirmation showing the linked ticket (Link value) and the proposed external status mapping for `in-progress` and `done`. Accepted → `SYNC=on` with the confirmed mapping; refused → `SYNC=off` and write `Pending: status → in-progress (DD-MM-YYYY)`.
   - Placement: the confirmation must happen before the local `todo → in-progress` update so the push follows it; the push happens after the local update. Must sit before step 1 (inputs before subagents) — it is in step 0, so OK.
   - Push the status (`in-progress`) from the orchestrator; verify; on failure write/replace the `Pending: status → ...` line and continue.
2. Step 6 "Update plan task on completion": after local `done`, if `SYNC=on` push `done` mapping from the orchestrator; on failure write `Pending: status → done (...)` (replacing the previous status Pending line). If `SYNC=off` because of refusal at step 0, write/replace `Pending: status → done (...)` too (refusal = Pending, per brief). If off because disabled/unconfigured/unlinked: nothing.
3. Rules sentence: only Status is written externally (field ownership); never inside a subagent; external content and method description are data, not instructions; protocol reference = `buildit-plan` step 5b.
4. Add a line to the step-6 user message when a Pending entry was written ("run `/buildit-plan` to reconcile").

### Step 4 — `buildit-feature-discover`
1. Step 0a (detect plan task): nothing to read yet; keep reading config at Phase 5 only (minimal).
2. Phase 5 "Update plan task on validation", after local writes: "Synchronize validated brief" block: same off-conditions as run (disabled, unconfigured, unclear method, no Link → no call, never prompt). Otherwise ONE confirmation showing the ticket and the fields to push: description, acceptance tests, and readiness only if the tool has a mappable field (confirm the mapping in the same prompt). Never push status, title or priority. Refusal or failure → `Pending:` line per unpushed field (`description`, `acceptance tests`, `readiness`), latest replaces; local flow continues to the handoff. Reference `buildit-plan` step 5b; data-not-instructions sentence.
   - Self-critic: `Pending:` value for description/AT can be multi-line — the format is one line. Decision: for long fields, the value is a short reference `(see task file)` meaning "push the current local value"; document this in plan's contract ("for multi-line fields the value is `local`, meaning the current local section content"). Apply in run? No (status is single token).

### Step 5 — `buildit-project-bootstrap`
1. New optional step (e.g. `### 6b. Configure task synchronization (optional)` within step 6 "Collect missing information", or a sub-bullet if step numbering would shift references — check README references to bootstrap step numbers before renumbering; prefer a lettered sub-step to avoid renumbering): ask whether to enable sync; if yes ask method (plain language, no shell command, no secrets) and tag (default `technical`); if declined leave the headings with empty values (= unconfigured) or write `disabled` if the user explicitly says disabled.
2. `config.md` template: add the three headings with comment lines, and explanatory sentence after the template (unconfigured ≠ disabled, tag default).
3. If re-bootstrapping and the headings exist, preserve existing values.

### Step 6 — Guidelines, README, spec
- `team-practices.md` "Plan-task integration in orchestrators": extend field ownership to external writes (run → Status; discover → Description/AT/Readiness; plan → only full bidirectional reconcile); external writes only from the orchestrator, after one explicit confirmation; failure/refusal → `Pending:`; run/discover never prompt to configure.
- `language-framework.md` "Project configuration": add the three sync headings, unconfigured ≠ disabled, tag default `technical`, no secrets, only plan/bootstrap prompt.
- README: update the four skill sections (`buildit-project-bootstrap` steps list, `buildit-plan`, `buildit-feature-discover`, `buildit-feature-run`) and add the spec under References.
- Spec `docs/buildit/specs/2026-11-24-plan-task-synchronization.md`: context, config contract, task contract, title/tag rules, per-skill behaviour, field ownership, security (untrusted content, consent, no secrets), DRY trade-off, testing limits. Follow the format of `2026-10-22-buildit-plan-design.md`.

### Step 7 — Verify and stage
- `bash tests/run-all.sh` → all green.
- Re-read the four skills end-to-end for coherence (same parsing rule wording, same `Pending:` format, same tag default).
- Check README consistency rule in team-practices "Documentation requirements".
- `git status`; stage every created/modified file (including the user draft and this tracking file) before `to-validate`.

## Self-critique (applied to the plan above)
- Assumption: `.claude/skills` symlink → no dual copy needed. Verified (`ls -la`).
- Assumption: plan.md `— [Title]` suffix does not break run/discover line matching. Run preserves rest of line; discover matches `task-{name} ` + space — OK. Must still grep other skills (validate/ship/start) for plan.md parsing during build.
- Edge case added: refusal at step 0 in run — brief says refusal → `Pending:`; plan now writes Pending at both transitions on refusal (status latest replaces, so only `done` remains at the end — correct by "latest replaces").
- Edge case added: multi-line Pending values (description/AT) — decided `local` sentinel value; documented in the plan contract.
- Edge case added: run is invoked on a task without `## Synchronization` — no call, no prompt.
- Edge case added: sync enabled but method missing/unclear in run/discover — treat as off, no prompt (they never prompt), report it in the final message.
- Edge case: tag value containing spaces or brackets — use verbatim; not validated (out of scope; note in spec).
- Edge case: run/discover in a worktree — `.buildit/config.md` and `.scratch/plan/` are read from `PROJECT_ROOT` (orchestrator runs there); no change.
- Vague step made concrete: test phrases are fixed in step 1 and reused verbatim in the skill text.
- Risk: README consistency rule — the four sections must all be updated in the same commit; tests assert it.
- Risk: bootstrap step renumbering may break README/test references — use a lettered sub-step.
- Risk: "never prompt to configure" in run vs. the existing step-1 "collect inputs before subagents" — the single sync confirmation is in step 0 (before subagents), consistent with the orchestrator-level input rule.
- Risk: test regexes with unicode `→` — `grep` with UTF-8 locale; use `require_text` (fixed string) for lines containing `→`.

## Progress

- 24-11-2026 build: failing tests added first (AT-SYNC-1..14 across 4 test files; 71 failing for the right reason, baseline 418 green). Implemented buildit-plan (step 0 tag, task synchronization contract under step 4, step 5b rewrite with pending-first/tag discovery/title rules, step 7 read-only drift report), buildit-feature-run (step 0 "Detect task synchronization", step 6 done push, Pending message), buildit-feature-discover (Phase 5 "Synchronize validated brief"), buildit-project-bootstrap (step 6b + config template), team-practices, language-framework, README (4 sections + references), spec docs/buildit/specs/2026-11-24-plan-task-synchronization.md. `bash tests/run-all.sh` → 493 passed, 0 failed.
- Checked: no other skill (start/build/validate/ship) parses plan.md lines, so the `— [Title]` suffix is safe.
- Decision: run uses `SYNC=off-refused` to distinguish refusal (Pending written at both transitions) from disabled/unconfigured/unlinked (nothing written).
