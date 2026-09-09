# bootstrap-autonomy-setup

## Status
to-ship

## Goal
Extend `buildit-project-bootstrap` with two additions:
1. An instruction-layer path guard at the top of the skill, stating that all file reads, writes, and shell commands must execute within the project root, and that external practices (Confluence, Notion, URLs) are fetched via web tools, not filesystem access.
2. A step 2b that detects autonomy settings for the active tool mode and offers to create them when absent:
   - **Claude mode**: check `.claude/settings.json`; if absent, ask the user before creating it with project-scoped defaults (scoped cd via `pwd`, plus git, npm, yarn, pnpm, python3, make, docker, grep, find, ls, cat, chmod).
   - **Generic/Copilot mode**: check `~/.config/github-copilot/cli/permissions-config.json` for an entry matching the current project path, report status, generate nothing.
   - The detected status appears as an "Autonomy settings" line in the step 5 diagnostic.
   - Generated files use the absolute project path detected via `pwd` at runtime — never hardcoded.

## Acceptance Tests
- [ ] skills/buildit-project-bootstrap/SKILL.md contains an explicit instruction-layer path guard stating that all file reads, writes, and shell commands must execute within the project root, and that external practices (Confluence, Notion, URLs) are fetched via web tools, not filesystem access
- [ ] skills/buildit-project-bootstrap/SKILL.md contains step 2b (or equivalent numbered step) that checks for autonomy settings for the detected tool mode found/absent
- [ ] When settings are absent (Claude mode), step 2b asks the user before continuing: "Autonomy settings missing — do you want to create .claude/settings.json with project-scoped defaults?"
- [ ] When settings are present (Claude mode), step 2b reports found and does NOT modify the existing file
- [ ] In Generic/Copilot mode, step 2b checks the Copilot config dir for a project-path entry, reports status, and generates no file
- [ ] The generated .claude/settings.json template in the skill includes: scoped cd using pwd-detected absolute path, plus git, npm, yarn, pnpm, python3, make, docker, grep, find, ls, cat, chmod
- [ ] The generated settings do NOT contain Bash(cd *) (broad, unscoped)
- [ ] The step 5 diagnostic includes an "Autonomy settings" line
- [ ] tests/test-buildit-project-bootstrap.sh asserts: path guard present, step 2b present, Claude-mode .claude/settings.json check present, offer-to-create prompt present, broad Bash(cd *) absent from the template
- [ ] Dual-deployment parity: symlink diff = 0

## Plan

### 1. Write failing tests first (TDD)

Add a `require_absent` helper to `tests/lib/assertions.sh` (checks that a regex is NOT present in a file). Then update `tests/test-buildit-project-bootstrap.sh`:
- **AT-4**: path guard present — `require_regex` for "project root" AND `require_regex` for "web tool" (matches "web tools") in `SKILL.md`
- **AT-5**: step 2b present — `require_regex` for `2b` (literal step label) in `SKILL.md`
- **AT-6**: Claude-mode `.claude/settings.json` check present — `require_text` for `.claude/settings.json` in `SKILL.md`
- **AT-7**: offer-to-create prompt present — `require_text` for "Autonomy settings missing" in `SKILL.md`
- **AT-8**: broad `Bash(cd *)` absent from the template — `require_absent` for the regex `Bash\(cd \*\)` in `SKILL.md`

Run tests to confirm they fail before modifying the skill.

### 2. Add instruction-layer path guard to SKILL.md

Insert a `## Instruction-layer constraints` section at the very top of the skill body (after the frontmatter and heading, before `## When to use`). Content:

```
> **Path guard — mandatory for all steps:**
> All file reads, writes, and shell commands must execute within the project root (the directory containing this skill's CLAUDE.md or `.buildit/`). Do not navigate outside the project root.
> External practices (Confluence pages, Notion docs, URLs) must be fetched via web tools (WebFetch / WebSearch), never via filesystem access.
```

### 3. Add step 2b to SKILL.md

Insert after "### 2. Detect workflow configuration files". Use `~~~` fences for the outer code block and ` ``` ` fences for the nested JSON to avoid Markdown nesting collisions (matching the existing skill style). The step heading must be exactly `### 2b. Detect autonomy settings` so the test regex `2b` matches.

Key rules in the step content:
- Run `pwd` to detect the project root (never hardcode).
- Claude mode absent branch: ask with the exact string "Autonomy settings missing — do you want to create `.claude/settings.json` with project-scoped defaults?"
- Claude mode present branch: report found, do NOT modify.
- Generic/Copilot mode: read `~/.config/github-copilot/cli/permissions-config.json`, check for project-path entry, report status, generate nothing.
- Template uses `Bash(cd <project-root>*)` — NOT `Bash(cd *)` — for the scoped cd permission.

### 4. Update step 5 diagnostic in SKILL.md

In the diagnostic template block under `### 5. Analyse and present the full diagnostic`, add an "Autonomy settings" line under the `**Environment**` section:

```
- Autonomy settings: [found / absent / skipped]
```

### 5. Mirror changes to `.claude/skills/buildit-project-bootstrap/SKILL.md`

Copy the updated `skills/buildit-project-bootstrap/SKILL.md` to `.claude/skills/buildit-project-bootstrap/SKILL.md` to maintain dual-deployment parity. Verify with `diff`.

### 6. Run tests to confirm all pass

Run `bash tests/test-buildit-project-bootstrap.sh` from the project root. All 8+ assertions must pass.

## Ship note

The build agent set status to `to-validate` without staging the modified files. Before running `/buildit-feature-ship`, stage the following files:
- `skills/buildit-project-bootstrap/SKILL.md`
- `tests/lib/assertions.sh`
- `tests/test-buildit-project-bootstrap.sh`
- `.scratch/09-09-2026-bootstrap-autonomy-setup.md`

## Progress
