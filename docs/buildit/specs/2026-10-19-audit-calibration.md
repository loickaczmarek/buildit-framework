# Design Spec: Audit Calibration

**Date:** 2026-10-19
**Skill:** buildit-project-audit
**Status:** Implemented

## Context

The parallel audit pipeline (3 category subagents + per-category critique) improved wall-clock time and critique focus. However, two quality gaps remained:

1. **Severity inflation** — AI-generated audits tend to rate findings as Critical or High without concrete evidence. A finding marked Critical but lacking an execution trace showing actual breakage is indistinguishable from speculation.
2. **Cross-file blind spots** — each category subagent examines files in isolation. Bugs that emerge from the interaction between files (implicit dependencies, order-of-operations, mock-masked bugs) fall through the cracks because no single category owns them.
3. **Severity inconsistency across categories** — critique subagents run independently. A "High" in Category A may be calibrated differently than a "High" in Category C because the critique agents have no shared baseline.

## Decision: Severity criteria with evidence requirements

Define four severity levels with mandatory evidence types:

| Level | Definition | Required evidence |
|-------|-----------|-------------------|
| **Critical** | Breaks core functionality or creates a security/data-loss risk in production | Execution trace showing the failure path |
| **High** | Significant bug or design flaw that will cause problems under normal use | file:line reference with concrete scenario |
| **Medium** | Quality issue that degrades maintainability or developer experience | file:line reference |
| **Low** | Cosmetic, stylistic, or minor improvement opportunity | Description sufficient |

**Why evidence requirements exist:** Without them, severity becomes a subjective label. Requiring an execution trace for Critical findings forces the auditor to demonstrate that the failure path is real, not hypothetical. This prevents the common AI audit failure mode of rating speculative issues as critical.

**Enforcement:** Critique subagents and the calibration subagent must downgrade findings that lack the required evidence for their claimed severity level. A finding rated Critical without an execution trace is downgraded to High (or lower if it also lacks file:line evidence).

## Decision: Cross-cutting execution trace pass

A dedicated subagent runs after all 3 category+critique pairs complete. It focuses exclusively on cross-file interaction bugs that parallel category subagents miss.

**Scope:**
- Implicit dependencies between files (file A assumes file B provides X, but B changed)
- Order-of-operations issues (initialization sequences, lifecycle hooks)
- Mock-masked bugs (tests pass because mocks hide a broken integration)
- Cross-file type mismatches (interface contract violations not caught by types)

**Why a separate pass:** Category subagents are scoped to their domain. A code quality subagent evaluating `auth.js` will not notice that `router.js` calls an auth function that was renamed. This class of bugs only appears when examining file interactions, which requires a cross-cutting view.

**Positioning:** After all category critiques complete (synchronization point), before calibration. This ensures the execution trace findings are included in the calibration normalization.

**Duplication avoidance:** The execution trace subagent receives the list of already-found findings so it can skip issues already covered by category subagents.

## Decision: Calibration pass

A final subagent receives ALL findings (from categories after critique + execution trace) and normalizes severity ratings.

**Rules:**
- Can downgrade or escalate severity
- CANNOT add new findings (the audit phase is closed; calibration is normalization only)
- Must apply the severity criteria uniformly — a finding rated High in Category A should meet the same evidence bar as a High in Category C
- Returns a list of adjustments with rationale

**Why calibration exists:** Critique subagents run independently and cannot see each other's severity baselines. A critique agent for Category A may accept a "High" finding that Category C's critique agent would have challenged. The calibration pass provides a single agent with full visibility to normalize.

**Positioning:** Final pass before report compilation. The calibration adjustments are applied before findings are sorted by severity in the final report.

## Pipeline summary

```
Step 1: Determine scope
Step 2: Early write permission trigger
Step 3: Severity criteria (reference section)
Step 4: Launch 3 parallel category subagents
Step 5: Per-category critique + progressive presentation (with evidence-based downgrading)
Step 6: Cross-cutting execution trace subagent
Step 7: Calibration subagent
Step 8: Compile final report (includes Calibration section)
Step 9: Present results
```

## Interactions with existing architecture

- **Severity criteria** are defined once and referenced by all downstream subagents (category, critique, execution trace, calibration) via their prompts.
- **Per-category critique** (step 5) is modified to also enforce evidence-based downgrading against the severity criteria.
- **Final report format** gains a "Calibration" section documenting severity adjustments.
- **Step numbering** shifts: the previous steps 5 (compile) and 6 (present) become steps 8 and 9 respectively.
