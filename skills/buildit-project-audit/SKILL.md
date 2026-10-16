---
name: buildit-project-audit
description: Use when auditing codebase health — evaluates code quality, architecture, and documentation across 9 dimensions with independent critique. Accepts optional scope argument.
---

# Project Audit

Audits the codebase for code quality, architecture health, guideline compliance, and documentation gaps. Scope is determined either by an explicit argument or via hotspot analysis in a subagent. Findings are critiqued by an independent subagent before the report is finalized. Output is a `.scratch/DD-MM-YYYY-audit-issues.md` file.

**Boundary with `buildit-project-bootstrap`:** bootstrap handles project setup and configuration scaffolding (generating workflow files, detecting the stack, creating `.buildit/config.md`). This skill handles ongoing code health assessment — it reads the existing codebase and guidelines, evaluates quality, and produces actionable findings. Bootstrap sets up the project; audit examines it.

## When to use

- Periodic health check on the codebase (e.g. end of sprint, quarterly review)
- Before a major refactoring — to identify the highest-impact areas
- After shipping a batch of features — to catch accumulated drift or quality degradation
- On-demand assessment of a specific file, directory, or concern area
- When onboarding to an unfamiliar codebase — to get a structured overview of its health

Do NOT use for project setup or configuration — use `buildit-project-bootstrap` instead.

## Steps

### 0. Detect environment paths

Determine your operating mode from your agent identity:
- You are a **Claude / Claude Code** agent → **Claude mode**: `<rules-file>` = `.claude/CLAUDE.md`
- You are any **other agent** (Copilot, generic) → **Generic mode**: `<rules-file>` = `.agents/guidelines/project-rules.md`

In all cases: `<guidelines-dir>` = `.buildit/guidelines/`

### 0b. Prerequisite check

If `.scratch/shared-context.md` does not exist, stop with:
> "Shared context file not found — run `/buildit-project-bootstrap` to initialize the project."

---

### 1. Determine audit scope

- If a scope argument was provided (file path, directory, question, or keyword), verify it exists if it is a file or directory path. If the path does not exist, stop with: "Scope target `[path]` does not exist." Otherwise, use it directly as the scope. Store as `AUDIT_SCOPE`.

- If no argument was provided, launch a subagent for hotspot analysis:
  - Git churn: `git log --format=format: --name-only | sort | uniq -c | sort -rn | head -20` to find most-changed files
  - Complexity heuristics: file length, function count, nesting depth for top churn files
  - Cap the hotspot list to the top 10 files and group them by concern area before returning
  - Fallback: if fewer than 5 files appear in the churn results (e.g. new repo with little history), fall back to scanning the full `skills/` directory (or `src/` if present)
  - Return a prioritized list of files/areas to audit
  - Store the result as `AUDIT_SCOPE`

---

### 2. Run the audit

Evaluate the scoped files/area against 9 dimensions organized in 3 categories:

**Category A — Code quality (the 6 validate dimensions):**

1. **Correctness** — does the code do what its name/docs claim?
2. **Performance** — unnecessary costly operations?
3. **Security** — injection vectors, data exposure?
4. **Style** — project conventions respected? (read `<guidelines-dir>/team-practices.md`)
5. **Test coverage** — edge cases tested? Missing test files?
6. **Craft principles** — DRY, KISS, YAGNI respected? (see `<guidelines-dir>/craft-principles.md` — do NOT duplicate definitions, reference by path only)

**Category B — Architecture health:**

7. **Coupling & cohesion** — are modules appropriately independent? Dependency structure healthy?

**Category C — Project health:**

8. **Documentation gaps** — missing or outdated docs, README sections, design specs for non-obvious choices
9. **Config/setup health** — build configs, CI setup, dependency freshness, gitignore completeness

For each finding: severity (Critical / High / Medium / Low), dimension, location (file:line when applicable), description, proposed fix.

---

### 3. Generate draft report

Write findings to `.scratch/DD-MM-YYYY-audit-issues.md` following this format:

```markdown
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

## Medium — [theme]
...

## Low — [theme]
...

## Summary
| Priority | Count | Key themes |
|----------|-------|-----------|
```

This follows the pattern established by `docs/buildit/reviews/`.

---

### 4. Independent critique (subagent)

Launch a separate subagent that:
- Receives the draft report content
- Receives access to the same source files listed in `AUDIT_SCOPE`
- For each finding, challenges: false positive risk, severity accuracy, actionability, completeness
- Identifies at least one gap in coverage (areas in scope not covered by any finding)
- Returns a structured critique with verdict per finding (agree / challenge / escalate / downgrade) and any new findings

The critique subagent must NOT be the same agent that authored the draft — this is enforced by launching it as a fresh subagent with only the report and file access, not the audit reasoning context.

The critique prompt must be adversarial: require the subagent to challenge at least the severity rating of each finding and explicitly look for missed issues. A rubber-stamp critique has no value.

---

### 5. Incorporate critique and finalize

For each critique item:
- **Accept** — modify the finding (adjust severity, reword, add detail)
- **Reject** — keep the original finding, add rationale for rejection
- **Add** — new finding surfaced by the critique

Update `.scratch/DD-MM-YYYY-audit-issues.md` with the final version.

Add a "Critique integration" section at the bottom documenting what changed:

```markdown
## Critique integration
- Finding N: [accepted/rejected] — [reason]
- New finding added: [title] — surfaced by critique
```

---

### 6. Present results

Present the final report path and a summary table.

## End of skill

> "Audit complete. Report written to `.scratch/DD-MM-YYYY-audit-issues.md`."
> "This is a standalone assessment — no status transition. Use the findings to plan fixes via `/buildit-feature-start` or `/buildit-feature-run`."

> If critique led to changes: "The independent critique modified N findings and added M new ones — see the 'Critique integration' section for details."
