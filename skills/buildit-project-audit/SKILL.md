---
name: buildit-project-audit
description: "Use when auditing codebase health — evaluates code quality, architecture, and documentation across 9 dimensions via parallel category subagents with per-category critique, cross-cutting execution trace, and calibration pass. Accepts optional scope argument."
---

# Project Audit

Audits the codebase for code quality, architecture health, guideline compliance, and documentation gaps. Scope is determined either by an explicit argument or via hotspot analysis in a subagent. The audit runs as 3 parallel category subagents (code quality, architecture health, project health). Each category is critiqued independently by a dedicated critique subagent upon completion, with findings presented progressively. After all categories complete, a cross-cutting execution trace subagent catches cross-file interaction bugs, then a calibration subagent normalizes severity ratings across the full report. Output is a `.scratch/audits/DD-MM-YYYY-audit-issues.md` file.

**Boundary with `buildit-project-bootstrap`:** bootstrap handles project setup and configuration scaffolding (generating workflow files, detecting the stack, creating `.buildit/config.md`). This skill handles ongoing code health assessment — it reads the existing codebase and guidelines, evaluates quality, and produces actionable findings. Bootstrap sets up the project; audit examines it.

## When to use

- Periodic health check on the codebase (e.g. end of sprint, quarterly review)
- Before a major refactoring — to identify the highest-impact areas
- After shipping a batch of features — to catch accumulated drift or quality degradation
- On-demand assessment of a specific file, directory, or concern area
- When onboarding to an unfamiliar codebase — to get a structured overview of its health

Do NOT use for project setup or configuration — use `buildit-project-bootstrap` instead.

## Subagent selection and workflow isolation

Every subagent this skill launches — hotspot analysis (step 1, only when no scope argument is given), the 3 category subagents (step 4), the per-category critique subagents (step 5), the cross-cutting execution trace subagent (step 6), and the calibration subagent (step 7) — is launched with the neutral `general-purpose` agent selected in the delegation tool's agent-type parameter.

**Fallback:** if `general-purpose` is not available in the harness, use the harness's default unspecialised subagent — never a specialised persona agent — still prepend the isolation preamble, and warn the user once:
> "`general-purpose` agent not available — using the default unspecialised subagent with the isolation preamble."

**Isolation preamble** — prepend this block verbatim as the first line of every subagent prompt, followed by the task-specific instructions from the relevant step:

> "Remain a neutral execution agent: the task-specific instructions below (hotspot analysis, category audit, critique, execution trace, or calibration) define your role, procedure, and expected output. Execute only those instructions without adopting an additional persona or substituting another workflow. Do not invoke any skill or agent. Continue to follow the repository's shared project rules and guidelines."

## Steps

### 0. Detect environment paths

**Operating mode rule**
- The mode is the identity of the agent running this skill, never a property of the repository: a Claude / Claude Code agent → **Claude mode** (`MODE` = `claude`); any other agent (Copilot, generic) → **Generic mode** (`MODE` = `generic`).
- Claude mode: rules file `.claude/CLAUDE.md`, skills directory `.claude/skills/`. Generic mode: rules file `.agents/guidelines/project-rules.md`, skills directory `.agents/skills/`.
- Never infer the mode from the presence of `.claude/` or `.agents/`: a dual-deployment repository contains both directories, so such a check always answers Claude.
- The mode is never persisted (not in `.buildit/config.md` nor in any other file): every skill applies this rule for the agent that runs it.

`<rules-file>` = the rules file of your mode.

In all cases: `<guidelines-dir>` = `.buildit/guidelines/`

### 0b. Prerequisite check

If `.scratch/shared-context.md` does not exist, stop with:
> "Shared context file not found — run `/buildit-project-bootstrap` to initialize the project."

---

### 1. Determine audit scope

- If a scope argument was provided (file path, directory, question, or keyword), verify it exists if it is a file or directory path. If the path does not exist, stop with: "Scope target `[path]` does not exist." Otherwise, use it directly as the scope. Store as `AUDIT_SCOPE`.

- If no argument was provided, launch a subagent for hotspot analysis (`general-purpose` + isolation preamble — see "Subagent selection and workflow isolation"):
  - Git churn: `git log --format=format: --name-only | sort | uniq -c | sort -rn | head -20` to find most-changed files
  - Complexity heuristics: file length, function count, nesting depth for top churn files
  - Cap the hotspot list to the top 10 files and group them by concern area before returning
  - Fallback: if fewer than 5 files appear in the churn results (e.g. new repo with little history), fall back to scanning the source directories detected from the repository layout (whichever of `src/`, `lib/`, `app/`, `packages/`, `skills/`, ... exist, from the build manifest or the top-level tree), excluding `.scratch/`, documentation, vendored and generated directories
  - Return a prioritized list of files/areas to audit
  - Store the result as `AUDIT_SCOPE`

---

### 2. Early write permission trigger

Before launching any subagent, create `.scratch/audits/` if missing and write a placeholder header to `.scratch/audits/DD-MM-YYYY-audit-issues.md`:

```markdown
# Audit — DD-MM-YYYY

## Scope
[pending — audit in progress]
```

This surfaces the file-write permission prompt early at session start rather than midway through a subagent (per team-practices guideline on orchestrator-level permission trigger).

---

### 3. Severity Criteria

All subagents (category, critique, execution trace, calibration) use these severity levels and evidence requirements. Findings that lack the required evidence for their claimed severity level must be downgraded.

| Level | Definition | Evidence required |
|-------|-----------|-------------------|
| **Critical** | Breaks core functionality or creates a security/data-loss risk in production | Execution trace showing the failure path |
| **High** | Significant bug or design flaw that will cause problems under normal use | file:line reference with concrete scenario |
| **Medium** | Quality issue that degrades maintainability or developer experience | file:line reference |
| **Low** | Cosmetic, stylistic, or minor improvement opportunity | Description sufficient |

**Enforcement rule:** critique subagents and the calibration subagent must downgrade findings that lack the required evidence. A Critical finding without an execution trace is downgraded to High. A High finding without a file:line reference is downgraded to Medium.

---

### 4. Launch 3 parallel category subagents

Launch all 3 category subagents in a single message with multiple Agent tool calls. Each subagent (`general-purpose` + isolation preamble — see "Subagent selection and workflow isolation") receives `AUDIT_SCOPE` and returns structured findings (severity, dimension, location, description, proposed fix).

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

### 5. Per-category critique + progressive presentation

As each category subagent returns, process it immediately:

**a. Launch a critique subagent for that category** (`general-purpose` + isolation preamble — see "Subagent selection and workflow isolation"). The critique subagent receives ONLY the findings from that category — not findings from other categories, not the audit reasoning context. You are critiquing ONLY the findings from [Category X].

The critique prompt must be adversarial: require the subagent to challenge at least the severity rating of each finding and explicitly look for missed issues in that category's scope. A rubber-stamp critique has no value.

For each finding, the critique subagent challenges: false positive risk, severity accuracy, actionability, completeness. It enforces the severity criteria (see step 3): any finding that lacks the required evidence for its claimed severity level must be downgraded — a Critical without an execution trace becomes High, a High without a file:line reference becomes Medium. It identifies at least one gap in coverage (areas in scope not covered by any finding in this category). Returns a structured critique with verdict per finding (agree / challenge / escalate / downgrade) and any new findings.

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

### 6. Cross-cutting execution trace subagent

After all 3 category+critique pairs have completed, launch a cross-cutting execution trace subagent (`general-purpose` + isolation preamble — see "Subagent selection and workflow isolation"). This subagent catches cross-file interaction bugs that parallel category subagents miss because each category examines files in isolation.

The execution trace subagent receives:
- `AUDIT_SCOPE`
- The list of all already-found findings (from steps 4–5) to avoid duplication

**Focus areas:**
- Implicit dependencies between files (file A assumes file B provides X, but B changed)
- Order-of-operations issues (initialization sequences, lifecycle hooks)
- Mock-masked bugs (tests pass because mocks hide a broken integration)
- Cross-file type mismatches (interface contract violations not caught by types)

Returns structured findings in the same format as category subagents (severity, dimension, location, description, proposed fix). Severity must comply with the severity criteria in step 3.

**Error handling:** if the execution trace subagent fails or returns no findings, report "No cross-cutting issues found" and continue.

---

### 7. Calibration subagent

After the execution trace subagent returns, launch a calibration subagent (`general-purpose` + isolation preamble — see "Subagent selection and workflow isolation"). This subagent normalizes severity ratings across the full set of findings.

The calibration subagent receives ALL findings — from the 3 categories (after critique) plus the execution trace pass.

**Rules:**
- Can downgrade or escalate severity ratings
- **CANNOT add new findings** — the audit phase is closed; calibration is normalization only
- Must apply the severity criteria (step 3) uniformly across categories
- Must compare findings cross-category: a "High" in Category A should meet the same evidence bar as a "High" in Category C

Returns a list of severity adjustments, each with: finding reference, original severity, new severity, rationale.

**Error handling:** if the calibration subagent fails, use the uncalibrated findings and note "Calibration skipped" in the report.

---

### 8. Compile final report

After all category+critique pairs, execution trace, and calibration are complete, merge all findings into `.scratch/audits/DD-MM-YYYY-audit-issues.md`. Apply calibration severity adjustments before grouping. Group by severity (Critical > High > Medium > Low), not by category. Follow this format:

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

## Calibration
| Finding | Original severity | Adjusted severity | Rationale |
|---------|------------------|-------------------|-----------|
| Finding N | High | Medium | Lacks file:line evidence |
```

This follows the pattern established by `docs/buildit/reviews/`.

---

### 9. Present results

Present the final report path and a summary table.

## End of skill

> "Audit complete. Report written to `.scratch/audits/DD-MM-YYYY-audit-issues.md`."
> "This is a standalone assessment — no status transition. Use the findings to plan fixes via `/buildit-feature-start` or `/buildit-feature-run`."

> If critique led to changes: "The independent critique modified N findings and added M new ones — see the 'Critique integration' section for details."
