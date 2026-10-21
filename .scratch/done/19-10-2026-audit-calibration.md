# audit-calibration

## Status
to-ship

## Worktree path
none

## Goal
Improves audit output quality by adding explicit severity criteria with mandatory evidence requirements, a cross-cutting execution trace pass to catch cross-file bugs that parallel categories miss, and a cross-category calibration pass to normalize severity ratings across the full report.

## Acceptance Tests
1. The skill defines explicit severity criteria (Critical/High/Medium/Low) with concrete evidence requirements for each level
2. Critical findings require an execution trace; High findings require file:line evidence — critique/calibration subagents must downgrade findings that lack required evidence
3. A cross-cutting execution trace subagent runs after the 3 category subagents return, focused on cross-file interaction bugs (implicit dependencies, order-of-operations, mock-masked bugs)
4. The cross-cutting pass receives the list of already-found findings to avoid duplication
5. A calibration subagent runs after all critiques + cross-cutting pass, receives ALL findings, and normalizes severity across categories — it can downgrade/escalate but cannot add new findings
6. The final report includes a "Calibration" section documenting severity adjustments
7. The YAML frontmatter description reflects any step count changes
8. Both skills/ and .claude/skills/ copies are in sync
9. A design spec documents the rationale for these additions
10. All existing tests pass (tests/run-all.sh)

## Plan

### Phase 1: Design spec (docs/buildit/specs/2026-10-19-audit-calibration.md)
Write the design spec documenting:
- Severity criteria definitions (Critical/High/Medium/Low) with evidence requirements
- Why evidence requirements exist (prevents severity inflation — a common problem in AI-generated audits)
- Cross-cutting execution trace pass: rationale (parallel categories are blind to cross-file interaction bugs), scope (implicit dependencies, order-of-operations, mock-masked bugs), positioning (after category critiques, before calibration)
- Calibration pass: rationale (parallel critique subagents cannot see each other's severity baselines), rules (can downgrade/escalate, cannot add findings), positioning (final pass before report compilation)
- How these interact with the existing pipeline: severity criteria inform both critique and calibration; execution trace feeds into calibration alongside category findings

### Phase 2: Modify SKILL.md — add severity criteria section
Insert a severity criteria reference section between the current step 2 (early write) and step 3 (launch subagents). This section defines the 4 severity levels with evidence requirements. It will be referenced by category subagents, critique subagents, the execution trace subagent, and the calibration subagent.

Location: add as a new subsection within the existing step 3 preamble or as a standalone section before step 3. The criteria must be visible to all downstream subagents via their prompts.

### Phase 3: Modify SKILL.md — add execution trace subagent (new step 4b)
After step 4 (per-category critique + progressive presentation), add a new step that:
- Launches a cross-cutting execution trace subagent
- The subagent receives: AUDIT_SCOPE + the list of all already-found findings (to avoid duplication)
- Focus areas: implicit dependencies between files, order-of-operations issues, mock-masked bugs, cross-file type mismatches
- Returns structured findings in the same format as category subagents
- The findings from this pass feed into the calibration step

### Phase 4: Modify SKILL.md — add calibration subagent (new step 4c)
After the execution trace subagent returns, add a calibration step that:
- Receives ALL findings (from 3 categories after critique + execution trace pass)
- Applies severity criteria uniformly — compares findings cross-category
- Can downgrade or escalate severity but CANNOT add new findings
- Returns a list of severity adjustments with rationale
- These adjustments are applied before the final report compilation

### Phase 5: Modify SKILL.md — update final report format (step 5)
Update the report template to include:
- A "Calibration" section documenting severity adjustments (which findings changed, from what to what, why)
- Ensure the severity criteria definitions are referenced in the report header

### Phase 6: Update YAML frontmatter
Update the frontmatter description to reflect the new step count and mention calibration/execution trace.

### Phase 7: Sync to .claude/skills/
Copy the updated SKILL.md from skills/ to .claude/skills/.

### Phase 8: Update existing tests + add new assertions
Add test assertions in tests/test-buildit-project-audit.sh for:
- Severity criteria are defined (Critical/High/Medium/Low with evidence requirements)
- Execution trace subagent exists and receives existing findings
- Calibration subagent exists, receives all findings, cannot add new findings
- Calibration section in report template
- Frontmatter description updated

### Phase 9: Update README.md
Update the buildit-project-audit section in README.md to reflect the new steps (execution trace, calibration).

### Phase 10: Run tests
Run tests/run-all.sh to verify all tests pass including new assertions.

### Self-critique corrections

**Risk 1 — Step numbering complexity.** The current SKILL.md uses steps 0–6. Adding execution trace and calibration as new steps will require careful renumbering. The insertion point matters: execution trace must run AFTER all 3 critique subagents complete (so after current step 4), and calibration AFTER the execution trace. Rather than inserting as "4b/4c", renumber to clean integer steps. This means: current step 5 (compile report) becomes step 7, current step 6 (present results) becomes step 8.

**Risk 2 — Severity criteria placement.** The criteria must be available to ALL subagents (category, critique, execution trace, calibration). Embedding them inline in the skill would create a long section. Better approach: define them as a clearly delineated subsection within the existing step 3 preamble, so they are naturally included in the prompt context when subagent instructions are written. Reference them by internal anchor ("see Severity Criteria above") in subsequent steps.

**Risk 3 — Execution trace subagent timing.** The current step 4 uses progressive presentation — each category is critiqued and presented as it finishes. The execution trace subagent needs ALL category findings, so it must wait for all 3 to complete. This creates a synchronization point. The plan must make this explicit: execution trace launches only after all 3 category+critique pairs have returned.

**Risk 4 — Calibration "cannot add" constraint enforcement.** This is a prompt instruction, not a code guard. The skill must make this constraint extremely explicit in the calibration subagent prompt to minimize the risk of the agent violating it. Use bold/caps emphasis.

**Risk 5 — Test assertion specificity.** The existing tests use regex patterns. The new assertions must be specific enough to catch real omissions without being brittle. Target key phrases: "execution trace", "calibration", "cannot add", severity level names with evidence requirements.

**Risk 6 — Critique subagents must also enforce evidence requirements.** AT-2 says "critique/calibration subagents must downgrade findings that lack required evidence." This means the critique subagent prompt (step 4) must be updated to reference the severity criteria and enforce evidence-based downgrading. This is not just about adding new steps — it modifies existing step 4.

## Progress
- 19-10-2026: TDD build complete. 24 new test assertions added (all pass). Full suite: 280/280 pass.
  - Phase 1: Design spec written (docs/buildit/specs/2026-10-19-audit-calibration.md)
  - Phase 2: Severity criteria section added as step 3
  - Phase 3: Cross-cutting execution trace subagent added as step 6
  - Phase 4: Calibration subagent added as step 7
  - Phase 5: Report template updated with Calibration section
  - Phase 6: Frontmatter description updated
  - Phase 7: skills/ and .claude/skills/ in sync (hardlinked)
  - Phase 8: Test assertions added to tests/test-buildit-project-audit.sh
  - Phase 9: README.md updated with new steps and spec references
  - Craft-principles self-review: no DRY/KISS/YAGNI violations found
