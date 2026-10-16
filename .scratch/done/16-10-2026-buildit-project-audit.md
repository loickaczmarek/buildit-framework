# buildit-project-audit

## Status
to-ship

## Worktree path
none

## Goal
Audits the codebase for code quality, architecture health, guideline compliance, and documentation gaps. Scope is determined either by explicit parameter or via hotspot analysis in a subagent. Findings are self-critiqued by an independent subagent before the report is finalized. Output is a `.scratch/DD-MM-YYYY-audit-issues.md` file.

## Acceptance Tests
- [ ] Skill file follows the canonical structure (frontmatter, When to use, Steps with numbered headings)
- [ ] Dual-deployment: `skills/buildit-project-audit/SKILL.md` and `.claude/skills/buildit-project-audit/SKILL.md` identical
- [ ] Accepts optional scope argument (file, directory, question, or keyword); when absent, launches a subagent for hotspot analysis (git churn + complexity heuristics)
- [ ] Audit evaluates against the 6 validate dimensions (Correctness, Performance, Security, Style, Test coverage, Craft principles) — references `craft-principles.md` by path, does not duplicate definitions
- [ ] Audit also evaluates: architecture (coupling, cohesion, dependency structure), documentation gaps, config/setup health
- [ ] Draft report is generated in `.scratch/DD-MM-YYYY-audit-issues.md` following tracking file conventions
- [ ] Draft report is critiqued by an independent subagent (not the audit author) — checking for false positives, missed issues, severity accuracy, and actionability
- [ ] Critique findings are incorporated into the final report before presentation
- [ ] Skill references guidelines by path (no DRY violation — no inline copies of craft principle definitions)
- [ ] Clear boundary with `buildit-project-bootstrap`: bootstrap handles project setup/config scaffolding; audit handles ongoing code health assessment
- [ ] README.md updated with the new skill in the skills list/overview
- [ ] Environment detection at step 0 (Claude mode vs Generic mode) following team-practices convention
- [ ] Prerequisite check for `shared-context.md` existence

## Plan

### 1. Create the SKILL.md file

Create `skills/buildit-project-audit/SKILL.md` following the canonical structure from `language-framework.md`:

**Frontmatter:**
- `name: buildit-project-audit`
- `description:` one-line trigger description explaining it audits codebase health across quality, architecture, and documentation dimensions. Mention optional scope argument.

**Sections:**
- `# Project Audit` — short description
- `## When to use` — trigger conditions: periodic health check, before major refactoring, after sprint/batch of features, on-demand codebase assessment. Explicitly distinguish from `buildit-project-bootstrap` (setup/config scaffolding vs. ongoing health assessment).
- `## Steps` — numbered headings

**Step 0 — Detect environment paths:**
Follow team-practices convention for mode detection (Claude mode vs Generic mode). Set `<rules-file>` and `<guidelines-dir>`.

**Step 0b — Prerequisite check:**
Guard for `.scratch/shared-context.md` existence.

**Step 1 — Determine audit scope:**
- If a scope argument was provided (file path, directory, question, or keyword), use it directly as the scope. Store as `AUDIT_SCOPE`.
- If no argument, launch a subagent for hotspot analysis:
  - Git churn: `git log --format=format: --name-only | sort | uniq -c | sort -rn | head -20` to find most-changed files
  - Complexity heuristics: file length, function count, nesting depth for top churn files
  - Return a prioritized list of files/areas to audit
  - Store the result as `AUDIT_SCOPE`

**Step 2 — Run the audit:**
Evaluate the scoped files/area against 9 dimensions organized in 3 categories:

Category A — Code quality (the 6 validate dimensions):
1. Correctness — does the code do what its name/docs claim?
2. Performance — unnecessary costly operations?
3. Security — injection vectors, data exposure?
4. Style — project conventions respected? (read `<guidelines-dir>/team-practices.md`)
5. Test coverage — edge cases tested?
6. Craft principles — DRY, KISS, YAGNI respected? (see `<guidelines-dir>/craft-principles.md` — do NOT duplicate definitions)

Category B — Architecture health:
7. Coupling & cohesion — are modules appropriately independent? Dependency structure healthy?

Category C — Project health:
8. Documentation gaps — missing or outdated docs, README sections, design specs for non-obvious choices
9. Config/setup health — build configs, CI setup, dependency freshness, gitignore completeness

For each finding: severity (Critical / High / Medium / Low), dimension, location (file:line), description, proposed fix.

**Step 3 — Generate draft report:**
Write findings to `.scratch/DD-MM-YYYY-audit-issues.md` in the tracking-file-adjacent format:
```
# Audit — DD-MM-YYYY
## Scope
[what was audited and why]
## Critical — [theme]
### N. Finding title
**Dimension:** ...
**Location:** ...
**Description:** ...
**Proposed fix:** ...
## High — [theme]
...
## Summary
| Priority | Count | Key themes |
```
This follows the pattern established by `docs/buildit/reviews/2026-10-14-skills-audit.md`.

**Step 4 — Independent critique (subagent):**
Launch a separate subagent that:
- Receives the draft report content
- Receives access to the same source files
- Evaluates each finding for: false positive risk, severity accuracy, actionability, completeness
- Identifies missed issues (areas in scope not covered by any finding)
- Returns a structured critique

The critique subagent must NOT be the same agent that authored the draft — this is enforced by launching it as a fresh subagent with only the report and file access, not the audit reasoning context.

**Step 5 — Incorporate critique and finalize:**
- For each critique item: accept (modify finding), reject (add rationale), or add (new finding from critique)
- Update `.scratch/DD-MM-YYYY-audit-issues.md` with the final version
- Add a "Critique integration" section at the bottom documenting what changed

**Step 6 (End of skill):**
Present the final report path and a summary. No status transition (this is not a feature lifecycle skill).

### 2. Write tests

Create `tests/test-buildit-project-audit.sh` following the test harness conventions:
- Source `tests/lib/assertions.sh`
- Test canonical structure (frontmatter name, description, ## Steps, ## End of skill)
- Test the 6 validate dimensions are referenced
- Test architecture, documentation gaps, config health are referenced
- Test craft-principles reference by path (not inline definition)
- Test subagent mention for hotspot analysis
- Test subagent mention for critique
- Test `.scratch/` report output reference
- Test scope argument handling
- Test environment detection (Claude mode / Generic mode)
- Test prerequisite check for `shared-context.md`
- Test clear boundary language distinguishing from bootstrap

### 3. Update `test-skills-invariants.sh`

Add `buildit-project-audit` to the `SKILLS` array so the cross-skill invariants cover this new skill.

Note: do NOT add it to the `WRITERS` array — this skill reads `shared-context.md` but does not write to it.

### 4. Create dual-deployment copy

Copy `skills/buildit-project-audit/SKILL.md` to `.claude/skills/buildit-project-audit/SKILL.md` — byte-identical.

### 5. Update README.md

Add a `### buildit-project-audit` section in the Skills area of `README.md`, following the existing format:
- Trigger, When to use, What it does, Ends with
- Position it logically: after `buildit-project-bootstrap` (both are project-level, not feature-level)

### Self-critique corrections

**Risk: hotspot subagent scope may be too broad.** The hotspot analysis (git churn + complexity) could return files across many unrelated areas, making the audit unfocused. Mitigation: cap the hotspot list to top 10 files and let the auditor group them by concern area before diving in. Add this cap instruction to step 1.

**Risk: critique subagent may rubber-stamp.** If the critique prompt is too vague, the subagent may simply agree with every finding. Mitigation: the critique prompt must explicitly require the subagent to challenge at least the severity rating of each finding and look for at least one gap in coverage. Add adversarial framing to the prompt.

**Risk: confusion with `buildit-project-bootstrap` scope.** Both operate at the project level. The SKILL.md must explicitly state that bootstrap handles setup/config scaffolding while audit handles ongoing code health assessment. The "When to use" section must make this unambiguous.

**Risk: report format divergence from existing audit.** The existing `docs/buildit/reviews/2026-10-14-skills-audit.md` established a de facto format. The new skill should produce reports in a compatible format to avoid confusion. Verify the template matches.

**Edge case: scope argument is a file that does not exist.** Add a guard in step 1: if the scope argument is a file/directory path, verify it exists before proceeding.

**Edge case: no git history (new repo).** The hotspot analysis relies on `git log`. If the repo has no commits or very few, the churn analysis produces nothing useful. Add a fallback: if fewer than 5 files appear in churn, fall back to scanning the full `skills/` directory (or `src/` if present).

## Progress
