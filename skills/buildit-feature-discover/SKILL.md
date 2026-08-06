---
name: buildit-feature-discover
description: Use before buildit-feature-start when the feature needs scoping — analyses project context, asks targeted functional questions, and produces a structured brief (name + description + acceptance tests + risks) ready for /buildit-feature-start. Accepts optional feature name: /buildit-feature-discover [feature-name].
---

# Feature Discover

Scopes a feature before implementation: context analysis, functional exploration, and brief generation.

## When to use

Before `/buildit-feature-start`, when the feature idea is vague or needs validation against project conventions. If the brief is already clear (name + description + acceptance tests), skip this skill and invoke `/buildit-feature-start` directly.

## Steps

### 0. Short-circuit if brief is already clear

If a `feature-name` was provided as argument and the user has also supplied a description and acceptance tests, skip to Phase 4 — Brief generation.

Otherwise, continue with Phase 1.

---

### Phase 1 — Project context analysis

Determine your operating mode from your agent identity:
- You are a **Claude / Claude Code** agent → `<skills-dir>` = `.claude/skills/`
- You are any **other agent** (Copilot, generic) → `<skills-dir>` = `.agents/skills/`

Use `<skills-dir>` as shorthand for this path in all steps below.

1. Read `.scratch/shared-context.md`:
   - Note active constraints and architecture decisions that could impact the new feature.

2. Read `.buildit/guidelines/team-practices.md` and `.buildit/guidelines/language-framework.md`:
   - Extract naming conventions, skill file format, expected patterns.

3. Scan existing skills: `ls <skills-dir>` and read the first few lines (name, description) of each `SKILL.md`:
   - Identify potential overlaps with the feature being explored.
   - Note dominant patterns to carry into the brief.

4. Ask the user:
   > "Do you have any external documentation to share before we begin (specs, user stories, design doc)?"
   - **Yes** → integrate the provided documentation into the following steps.
   - **No** → continue without.

---

### Phase 2 — Functional exploration

Based on what Phase 1 revealed, ask the user targeted questions. Cover at minimum:

- **Problem**: what problem does this skill solve? What friction disappears with this skill?
- **Users**: who invokes this skill and in what context?
- **Expected behaviour**: what happens step by step when the skill is successfully invoked?
- **Success criteria**: how will you know the skill is working correctly?

Add contextual questions based on Phase 1 findings:
- If a similar skill exists → "How does this skill differ from `[skill-name]`?"
- If a constraint from `shared-context.md` applies → "Does this scope respect the constraint `[constraint]`?"
- If the scope seems large → signal it and propose to split before continuing.

---

### Phase 3 — Technical translation

From the context analysis and functional answers:

1. Identify which files and components will be affected (skill directories, guidelines, shared-context, docs specs).
2. Anchor the technical description in the patterns and conventions detected in Phase 1 (guideline rules, existing skill patterns).
3. Surface actionable risks:
   - Non-trivial dependencies (e.g. relies on a skill that may change)
   - Large impact surface (touches core workflow, multiple skills)
   - Ambiguous acceptance tests
   - Scope too wide for a single feature

---

### Phase 4 — Brief generation

Produce a structured brief in markdown:

~~~markdown
## Brief: [feature-name]

**Name:** [feature-name] (kebab-case)
**Description:** [technical description anchored in project conventions]

**Acceptance tests:**
- [ ] [verifiable criterion 1]
- [ ] [verifiable criterion 2]
...

**Risks & Constraints:**
- [risk 1 — estimated impact]
- [constraint from shared-context or guidelines]
~~~

---

### Phase 5 — Validation & handoff

Present the brief to the user for review.

- On correction → iterate only on the contested sections.
- On validation → display:

> "Run `/buildit-feature-start [feature-name]` — the brief above is your input for the information-gathering step of the start skill."

## End of skill

> "Brief validated. Run `/buildit-feature-start [feature-name]` to start the implementation."
