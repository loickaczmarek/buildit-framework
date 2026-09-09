# update-docs

## Status
to-ship

## Goal
Update and clean up framework documentation — remove obsolete docs in docs/, elevate bootstrap → discover (optional) → run as the primary workflow in the README, keep start → build → validate → ship well documented, add autonomy configuration documentation, document the --max-cycles parameter with configuration guidance.

## Acceptance Tests
1. Le README met en avant le flux `bootstrap → discover (optional) → run` comme workflow principal (mis en avant visuellement avant le flux détaillé)
2. Dans `docs/`, seules les documentations utiles et à jour existent — les docs obsolètes sont supprimées
3. Le titre du README reflète bien "buildit workflow" (pas juste "Skills — Multi-Agent Workflow")
4. Il existe une documentation sur la configuration d'autonomie (paramètre autonomy dans les subagents, settings.json)
5. Le nombre de cycles (`--max-cycles`) est documenté avec la configuration, y compris comment le personnaliser

## Plan

### Audit (read-only, before any edit)

1. Confirm `docs/superpowers/specs/2026-08-03-bootstrap-mode-confirmation-design.md` does NOT exist (dangling README reference).
2. Confirm `docs/buildit/specs/2026-09-08-buildit-feature-run-design.md` exists and is referenced — keep it.
3. Read the full README.md to understand current section order.

### Step 1 — Update README title (AT 3)

Change line 1 from:
  `# Skills — Multi-Agent Workflow v2`
to:
  `# buildit — Multi-Agent Development Workflow`

Update the opening paragraph to reflect the framework name and its dual-path nature (automated via `run`, manual via the 5-skill sequence).

### Step 2 — Promote `bootstrap → discover (optional) → run` as primary workflow (AT 1)

Restructure README with this heading hierarchy:
- `## Quick start` — the automated path as a code block diagram, placed FIRST
- `## Manual flow` — the existing detailed diagram with 🔄 CLEAR CONTEXT markers, for complex features

`## Quick start` block content (exact code block):
```
[buildit-project-bootstrap]  ← once per project
        │
        ▼
[buildit-feature-discover]  (optional) ← scope vague feature → structured brief
        │
        ▼
[buildit-feature-run]  ← full cycle unattended (start → build → validate → ship)
   supports --max-cycles N (default 3)
   (push + PR remain manual)
```

Follow with one sentence: "For complex features where mid-cycle human judgement is needed, use the manual flow below."

`## Manual flow` then contains the existing diagram unchanged (buildit-feature-start → buildit-feature-build → buildit-feature-validate → buildit-feature-ship with 🔄 CLEAR CONTEXT markers).

### Step 3 — docs/ cleanup (AT 2)

Remove the dangling reference from the README References section:
  - Delete line: `- Bootstrap mode confirmation design: docs/superpowers/specs/2026-08-03-bootstrap-mode-confirmation-design.md`

No file in docs/ needs to be deleted (only one file exists and it's valid).
Verify: `find docs/ -type f` — if only the buildit spec exists, docs/ is already clean.

### Step 4 — Autonomy configuration documentation (AT 4)

Add a new section `## Autonomy configuration` to the README, placed between the Manual flow section and the Skills reference section. Two sub-topics:

**4a — Subagent autonomy instruction block**
Explain that `buildit-feature-run` passes an autonomy instruction to each phase subagent:
- Tells the subagent the absolute `PROJECT_ROOT` path
- Tells the subagent its `MODE` (Claude vs Generic)
- Grants permission to execute bash, python3, and cd commands within the project directory
- Forbids navigation outside the project root

Show the template used in subagent prompts (from the skill source):
> "Autonomy: you are operating within the project directory `[PROJECT_ROOT]` (mode: [MODE]). Execute bash, python3, and cd commands freely within this directory and its subdirectories. Use relative paths for script invocations. Do not cd outside the project root — paths outside require explicit user permission."

**4b — settings.json permission file (Claude mode)**
- Mode detection: if `.claude/` directory exists at project root → Claude mode; otherwise Generic mode
- In Claude mode, a `.claude/settings.json` allowlist reduces per-command permission prompts during automated runs
- Show the full JSON template (matching what bootstrap generates)
- Explain the two cd patterns: `Bash(cd <project-root>*)` for absolute paths + `Bash(cd ./*)` for relative subdirectory navigation; `Bash(cd *)` is intentionally excluded (too broad)
- Note: run `/buildit-project-bootstrap` to auto-generate this file if absent

### Step 5 — `--max-cycles` configuration guidance (AT 5)

Extend the `buildit-feature-run` section in the README (or add a sub-section `### Configuration`) covering:

- Default: `--max-cycles 3` — mirrors the warning threshold in `buildit-feature-validate`
- Override: pass `--max-cycles N` (e.g. `--max-cycles 5` for complex features, `--max-cycles 1` for quick iterations)
- Validation: N < 1 → orchestrator warns and resets to 3
- When cycles are exhausted: orchestrator stops with an explanation; user resumes manually with `/buildit-feature-build` + `/buildit-feature-validate`
- Guidance: simple features → 1–2 cycles expected; complex features with broad acceptance tests → allow 3–5

### Step 6 — Verify and finalize

- `find docs/ -type f` — confirm no stale files remain
- Re-read README in full to verify section order, no broken references, consistent formatting

## Progress
<!-- filled during build -->

## Problems to fix
<!-- filled by feature-validate on NO-GO/FAIL -->
