---
name: buildit-project-audit
description: Use when auditing codebase health — evaluates code quality, architecture, and documentation across 9 dimensions via parallel category subagents with per-category critique. Accepts optional scope argument.
---

# Project Audit

Audits the codebase for code quality, architecture health, guideline compliance, and documentation gaps. Scope is determined either by an explicit argument or via hotspot analysis in a subagent. The audit runs as 3 parallel category subagents (code quality, architecture health, project health). Each category is critiqued independently by a dedicated critique subagent upon completion. Findings are presented progressively to the user as each category+critique pair finishes, then compiled into the final report. Output is a `.scratch/DD-MM-YYYY-audit-issues.md` file.

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

### 2. Early write permission trigger

Before launching any subagent, write a placeholder header to `.scratch/DD-MM-YYYY-audit-issues.md`:

```markdown
# Audit — DD-MM-YYYY

## Scope
[pending — audit in progress]
```

This surfaces the file-write permission prompt early at session start rather than midway through a subagent (per team-practices guideline on orchestrator-level permission trigger).

---

### 3. Launch 3 parallel category subagents

Launch all 3 category subagents in a single message with multiple Agent tool calls. Each subagent receives `AUDIT_SCOPE` and returns structured findings (severity, dimension, location, description, proposed fix).

**Category A subagent — Code quality (the 6 validate dimensions):**

Receives `AUDIT_SCOPE` and `<guidelines-dir>` paths. Evaluates:

1. **Correctness** — does the code do what its name/docs claim?
2. **Performance** — unnecessary costly operations?
3. **Security** — injection vectors, data exposure?
4. **Style** — project conventions respected? (read `<guidelines-dir>/team-practices.md`)
5. **Test coverage** — edge cases tested? Missing test files?
6. **Craft principles** — DRY, KISS, YAGNI respected? (see `<guidelines-dir>/craft-principles.md` — do NOT duplicate definitions, reference by path only)

**Category B subagent — Architecture health:**

Receives `AUDIT_SCOPE`. Evaluates:

7. **Coupling & cohesion** — are modules appropriately independent? Dependency structure healthy?

**Category C subagent — Project health:**

Receives `AUDIT_SCOPE` and `<rules-file>`. Evaluates:

8. **Documentation gaps** — missing or outdated docs, README sections, design specs for non-obvious choices
9. **Config/setup health** — build configs, CI setup, dependency freshness, gitignore completeness

**Error handling:** if a category subagent fails or returns no findings, report "No issues found in [Category X]" and continue — do not block the other categories.

---

### 4. Per-category critique + progressive presentation

As each category subagent returns, process it immediately:

**a. Launch a critique subagent for that category.** The critique subagent receives ONLY the findings from that category — not findings from other categories, not the audit reasoning context. You are critiquing ONLY the findings from [Category X].

The critique prompt must be adversarial: require the subagent to challenge at least the severity rating of each finding and explicitly look for missed issues in that category's scope. A rubber-stamp critique has no value.

For each finding, the critique subagent challenges: false positive risk, severity accuracy, actionability, completeness. It identifies at least one gap in coverage (areas in scope not covered by any finding in this category). Returns a structured critique with verdict per finding (agree / challenge / escalate / downgrade) and any new findings.

The critique subagent must NOT be the same agent that authored the findings — this is enforced by launching it as a fresh subagent with only the category findings and file access.

**b. Incorporate the critique.** For each critique item:
- **Accept** — modify the finding (adjust severity, reword, add detail)
- **Reject** — keep the original finding, add rationale for rejection
- **Add** — new finding surfaced by the critique

**c. Present the critiqued findings to the user immediately** (progressive output). Use a consistent template:

> **Category [A/B/C] — [name]: N findings (X critical, Y high, Z medium, W low)**

Followed by the finding details for that category.

This step repeats for each of the 3 categories as they complete. Order of completion is non-deterministic — do not wait for all categories before presenting results from a completed one.

---

### 5. Compile final report

After all 3 category+critique pairs are complete, merge all findings into `.scratch/DD-MM-YYYY-audit-issues.md`. Group by severity (Critical > High > Medium > Low), not by category. Follow this format:

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

## Critique integration
### Category A — Code quality
- Finding N: [accepted/rejected] — [reason]
- New finding added: [title] — surfaced by critique

### Category B — Architecture health
- ...

### Category C — Project health
- ...
```

This follows the pattern established by `docs/buildit/reviews/`.

---

### 6. Present results

Present the final report path and a summary table.

## End of skill

> "Audit complete. Report written to `.scratch/DD-MM-YYYY-audit-issues.md`."
> "This is a standalone assessment — no status transition. Use the findings to plan fixes via `/buildit-feature-start` or `/buildit-feature-run`."

> If critique led to changes: "The independent critique modified N findings and added M new ones — see the 'Critique integration' section for details."
