# audit-pipeline-restructure

## Status
to-ship

## Worktree path
none

## Goal
Restructure the buildit-project-audit skill to replace the monolithic inline audit (step 2) with 3 parallel category subagents, each critiqued independently upon completion. Findings are presented progressively to the user as each category+critique pair finishes, then compiled into the final report file.

## Acceptance Tests
- [ ] AT-P1: The audit skill launches 3 parallel subagents (one per category), not a single inline pass
- [ ] AT-P2: Each category has its own critique subagent that runs immediately after the category audit completes
- [ ] AT-P3: The critique subagent receives only the findings from its category (not the full audit)
- [ ] AT-P4: Findings are presented to the user progressively as each category+critique pair finishes
- [ ] AT-P5: The final report is compiled into `.scratch/DD-MM-YYYY-audit-issues.md` with the same format (severity grouping, critique integration section)
- [ ] AT-P6: The orchestrator triggers an early write permission before launching subagents (team-practices guideline)
- [ ] AT-P7: The hotspot analysis step (step 1) remains unchanged
- [ ] AT-P8: The skill description and frontmatter are updated to reflect the new pipeline architecture
- [ ] AT-P9: Existing test assertions (AT-1 through AT-13) pass or are updated to match the new structure
- [ ] AT-P10: Dual deployment: `skills/` and `.claude/skills/` stay in sync
- [ ] AT-DOC1: Design spec written (non-obvious pattern: parallel category subagents with per-category critique) — derived from team-practices documentation requirements

## Plan

### Phase 1 — Write failing tests (TDD red)

1. **Add new test assertions** to `tests/test-buildit-project-audit.sh` for the new pipeline structure:
   - AT-P1: grep for "parallel" + "subagent" + "category" (3 parallel subagents)
   - AT-P2: grep for per-category critique (critique runs per category, not once for whole audit)
   - AT-P3: grep for "only the findings from its category" or equivalent scoping language
   - AT-P4: grep for "progressive" or "present.*as each" (progressive presentation)
   - AT-P6: grep for early write permission trigger language
   - AT-P8: frontmatter description updated — check for "parallel" in description

2. **Verify existing AT-1 through AT-13 still match** the planned new structure. Pre-audit each regex against what the new SKILL.md will contain:
   - AT-1 (numbered steps): will still have numbered step headings — PASS expected
   - AT-3 (scope/hotspot): step 1 unchanged — PASS expected
   - AT-4 (6 dimensions): same dimension names present in Category A — PASS expected
   - AT-5 (architecture/docs/config): same text in Category B and C — PASS expected
   - AT-6 (report in .scratch/): report compilation step still references same path — PASS expected
   - AT-7 (independent critique subagent): still present, now per-category — PASS expected
   - AT-8 (critique incorporated): critique integration section still present — PASS expected
   - AT-9 (craft-principles.md reference): same reference, no inline duplication — PASS expected
   - AT-10 (bootstrap boundary): unchanged intro paragraph — PASS expected
   - AT-12 (mode detection): step 0 unchanged — PASS expected
   - AT-13 (shared-context prerequisite): step 0b unchanged — PASS expected

3. **Run tests** — confirm new assertions fail (red).

### Phase 2 — Restructure SKILL.md (TDD green)

4. **Update frontmatter** — change description to reflect parallel pipeline architecture. Include "parallel" and "subagent" in the description.

5. **Update intro paragraph** — describe the new parallel pipeline: 3 category subagents, per-category critique, progressive presentation. Keep the bootstrap boundary paragraph unchanged.

6. **Keep steps 0, 0b, 1 unchanged** (environment detection, prerequisite check, audit scope).

7. **Add step 2: Early write permission trigger** — the orchestrator writes a placeholder header to `.scratch/DD-MM-YYYY-audit-issues.md` before launching any subagents. This surfaces the file-write permission prompt early (per team-practices guideline on orchestrator-level permission trigger).

8. **Rewrite step 3: Launch 3 parallel category subagents** — define each category's audit scope:
   - **Category A subagent — Code quality:** 6 dimensions (Correctness, Performance, Security, Style, Test coverage, Craft principles). Receives `AUDIT_SCOPE` and `<guidelines-dir>` paths.
   - **Category B subagent — Architecture health:** Coupling & cohesion. Receives `AUDIT_SCOPE`.
   - **Category C subagent — Project health:** Documentation gaps, Config/setup health. Receives `AUDIT_SCOPE` and `<rules-file>`.
   - All 3 launched in parallel (single message with multiple Agent tool calls).
   - Each returns structured findings (severity, dimension, location, description, proposed fix).

9. **Write step 4: Per-category critique + progressive presentation** — as each category subagent returns:
   a. Launch a critique subagent for that category. The critique subagent receives ONLY the findings from that category (not other categories' findings, not the audit reasoning context).
   b. Critique prompt is adversarial (same requirements as current step 4).
   c. When critique returns, the orchestrator incorporates the critique (accept/reject/add).
   d. Present the critiqued findings to the user immediately (progressive output).
   
   This step repeats for each of the 3 categories as they complete. Order of completion is non-deterministic.

10. **Write step 5: Compile final report** — after all 3 category+critique pairs are complete, merge all findings into `.scratch/DD-MM-YYYY-audit-issues.md`. Group by severity (Critical > High > Medium > Low). Include a per-category "Critique integration" section at the bottom.

11. **Update step 6: Present results** — present the final report path and summary table. Same end-of-skill message.

12. **Run tests** — confirm all assertions pass (green), including existing AT-1 through AT-13.

### Phase 3 — Dual deployment + documentation

13. **Mirror SKILL.md** — copy `skills/buildit-project-audit/SKILL.md` to `.claude/skills/buildit-project-audit/SKILL.md`.

14. **Write design spec** — `docs/buildit/specs/2026-10-19-audit-parallel-pipeline.md` documenting the WHY: why parallel subagents instead of inline, why per-category critique instead of single critique, why progressive presentation matters for UX.

15. **Run full test suite** (`tests/run-all.sh`) — confirm no regressions.

### Self-critic corrections

**Assumption risk: "3 parallel subagents" implies the Agent tool can launch 3 in one message.**
This is a skill file (markdown instructions), not executable code. The skill instructs the executing agent to use the Agent tool. Claude Code does support multiple Agent tool calls in a single message. The skill must be explicit about this ("launch all 3 in a single message with multiple Agent tool calls") — vague language like "run in parallel" could be misinterpreted.

**Edge case: Category B and C are much smaller than Category A.**
Category A has 6 dimensions, Category B has 1, Category C has 2. Categories B and C will finish much faster. This is actually fine for progressive presentation — the user sees quick results from B and C while A is still running. No correction needed, but the skill should not assume a specific completion order.

**Edge case: What if a category subagent fails or returns empty findings?**
The skill should instruct the orchestrator to handle empty findings gracefully (report "no issues found in this category") and to report errors without blocking the other categories. Add a note to step 3.

**Risk: The critique subagent prompt needs to be specific about receiving ONLY its category's findings.**
The current monolithic critique receives the full draft report. In the new structure, each critique subagent must receive only its category's findings. The prompt template in step 4 must be explicit: "You are critiquing ONLY the following findings from [Category X]. You do not have access to findings from other categories." This prevents cross-category contamination of the critique.

**Risk: Severity grouping in the final report requires merging across categories.**
The current report groups by severity. When 3 categories produce findings independently, the compile step must re-sort all findings by severity, not by category. The compile step (step 5) must be explicit about this merge logic.

**Vagueness fix: "Progressive presentation" needs concrete instructions.**
The skill should instruct the orchestrator to present a formatted summary to the user after each category+critique pair completes, using a consistent template (e.g., "Category A — Code quality: N findings (X critical, Y high, ...)"). Not just "present findings" — specify the format.

## Problems to fix
(none)

## Progress

### NO-GO cycle 1 — 19-10-2026
- Review: NO-GO — README.md not updated to reflect parallel pipeline restructure (factual documentation error within the same branch)
- Acceptance: PASS — all 11 criteria (AT-P1 through AT-P10, AT-DOC1) satisfied
