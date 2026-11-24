# task-mode-detection-single-source

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Audit 24-11-2026 finding #11. Skills use incompatible mode-detection methods: `ls .claude/` (team-practices guideline, run, plan, discover) vs agent identity (validate, ship, audit, bootstrap). In a dual-deployment repo `.claude/` always exists, so the directory method always answers Claude.

Scoped design: standardise on agent identity everywhere — no persistence in `.buildit/config.md`. The mode describes which agent is running (it decides which rules file and skills directory that agent reads), so identity is the correct signal and needs no fallback.
- Define one `**Operating mode rule**` block (bold heading + contiguous list, no blank line inside — same convention as the `**Tracking file discovery rule**`) in `.buildit/guidelines/team-practices.md` (section "Path and mode conventions", replacing the current `ls .claude/` paragraph; keep the resource table) and copy it verbatim into every skill that detects the mode: buildit-feature-discover, buildit-feature-run, buildit-plan, buildit-feature-validate, buildit-feature-ship, buildit-project-audit, buildit-project-bootstrap (all under `skills/`; `.claude/skills` is a tracked symlink to `../skills`). Each skill keeps its own variable mapping (`SKILLS_DIR`, `MODE`, `<rules-file>`) after the block.
- The rule sets `MODE` to `claude` / `generic` and names the rules file and skills directory per mode, and states never to infer the mode from the presence of `.claude/` or `.agents/`.
- Bootstrap keeps its confirmation prompt; a switched answer applies only to the kit bootstrap generates in that run (e.g. a Generic kit for Copilot teammates). It is not persisted — every other skill applies the rule for the agent that runs it. Bootstrap says so explicitly.
- `.buildit/guidelines/language-framework.md` anti-pattern line ("Hardcoding agent-specific paths") no longer suggests checking for a `.claude/` directory; it points to the Operating mode rule in team-practices.
- README: the `MODE` definition in the run section ("`claude` if `.claude/` directory exists...") and every other mention describe agent identity. Edit in place; README headings must stay unique (tests/test-readme.sh AT-R9).
- New `tests/test-mode-detection.sh` (picked up by tests/run-all.sh): copies byte-identical (guideline + 7 skills, heading to first blank line), and no skill/guideline/README uses `ls .claude/` or a "`.claude/` directory exists" mode check.

## Acceptance Tests
- AT-1: `.buildit/guidelines/team-practices.md` defines an `**Operating mode rule**` block based on agent identity, and the block is copied byte-identically into discover, run, plan, validate, ship, audit and bootstrap.
- AT-2: mode is not persisted (scoping decision); bootstrap states that a switched confirmation applies only to the kit it generates in that run and that other skills apply the rule for the running agent.
- AT-3: README describes mode detection as agent identity everywhere (no "`.claude/` directory exists" definition of `MODE`).
- AT-4: `tests/test-mode-detection.sh` fails if any skill, guideline or README uses `ls .claude/` or a directory-existence mode check, or if a copy of the rule diverges; `bash tests/run-all.sh` passes.

Contracts to keep intact: Config value rule wording (tests/test-config-parsing-boundary.sh), Tracking file discovery rule block (tests/test-tracking-file-discovery.sh), run's Subagent autonomy block defined once, existing tests grepping "Claude mode"/"Generic mode" (test-buildit-project-audit.sh AT-12, test-buildit-project-bootstrap.sh AT-2).

## Plan

### Step 1 — Failing test first: `tests/test-mode-detection.sh`
Model on `tests/test-tracking-file-discovery.sh` (source `lib/assertions.sh`, same `extract_rule` awk: heading line exactly `**Operating mode rule**` to first blank line).
- `GUIDELINE=.buildit/guidelines/team-practices.md`; `SKILLS=(discover run plan validate ship audit bootstrap)` mapped to `skills/buildit-*/SKILL.md`.
- AT-1: reference = guideline copy; assert non-empty in guideline and in each of the 7 skills, and byte-identical to the guideline copy. Content checks on the reference (`grep -F`): `agent identity` (or "identity of the agent"), `` `MODE` = `claude` ``, `` `MODE` = `generic` ``, `.claude/CLAUDE.md`, `.agents/guidelines/project-rules.md`, `.claude/skills/`, `.agents/skills/`, a "never infer ... presence of `.claude/` or `.agents/`" phrase, and the non-persistence phrase (`never persisted`).
- AT-1 (heading occurrence): heading appears exactly once per file (avoid a stale second copy).
- AT-2: bootstrap contains a phrase stating the switched answer applies only to the kit generated in this run (e.g. grep `only to the kit` ) and that other skills apply the rule for the agent that runs them; `.buildit/config.md` gains no mode heading: assert no `## Operating mode`/`## Mode` heading is written by bootstrap's config template (grep `^## (Operating )?[Mm]ode$` in bootstrap SKILL.md → must be absent).
- AT-3 / AT-4 forbidden patterns over `skills/*/SKILL.md`, `.buildit/guidelines/*.md`, `README.md`: `ls .claude/`, `` `.claude/` directory exists ``, `check for a `.claude/` directory` → each must match zero files (use `grep -lF`, report offending files). Do NOT forbid the bare word "directory exists" (bootstrap §3 "Ask whether a practices directory exists" is unrelated).
- README positive check: the `MODE` bullet mentions agent identity (grep `**`MODE`**` line contains `identity`).
- Run it: must fail now (red). `tests/run-all.sh` globs `test-*.sh`, so no registration needed.

### Step 2 — Guideline (`.buildit/guidelines/team-practices.md`, "Path and mode conventions")
Replace the "**Operating mode detection.**" paragraph + 2 bullets with a short intro sentence, a blank line, then the block (draft, finalise wording at build time; must not itself contain any forbidden pattern):
```
**Operating mode rule**
- The mode is the identity of the agent running this skill, never a property of the repository: a Claude / Claude Code agent → **Claude mode** (`MODE` = `claude`); any other agent (Copilot, generic) → **Generic mode** (`MODE` = `generic`).
- Claude mode: rules file `.claude/CLAUDE.md`, skills directory `.claude/skills/`. Generic mode: rules file `.agents/guidelines/project-rules.md`, skills directory `.agents/skills/`.
- Never infer the mode from the presence of `.claude/` or `.agents/`: a dual-deployment repository contains both, so a directory check always answers Claude.
- The mode is never persisted (not in `.buildit/config.md` or any other file): every skill applies this rule for the agent that runs it.
```
Keep the resource table right after (blank line first). Also mention in the existing "Rules shared between independently deployed skills" paragraph? Not required — leave it (optional: add the Operating mode rule as second example; skip, YAGNI).

### Step 3 — Copy the block into the 7 skills, keep local mappings after it
- discover (Phase 1, line ~41): replace "Detect your operating mode: / - Run `ls .claude/`..." with the block, blank line, then "Set `SKILLS_DIR` to the skills directory of your mode (`.claude/skills/` or `.agents/skills/`)."
- run ("**Detect operating mode**", line ~59): replace the `ls` sentence with the block, blank line, then "Store the result as `MODE` (`claude` or `generic`)." Keep "Use `PROJECT_ROOT` and `MODE` in the Subagent autonomy block." Do not touch the Subagent autonomy block (defined once).
- plan (step 0, line ~18): replace with block, blank line, then keep the "Claude mode"/"Generic mode" usage the rest of the skill relies on (check later references to mode in plan and keep them consistent).
- validate, ship, audit, bootstrap: replace "Determine your operating mode from your agent identity:" + 2 bullets with the block, blank line, then "`<rules-file>` = the rules file of your mode." (keep "In all cases: `<guidelines-dir>` = `.buildit/guidelines/`").
- bootstrap additionally: after the confirmation prompt, add: "A switched answer applies only to the kit this run generates (e.g. a Generic kit for Copilot teammates); it is not persisted — every other skill applies the Operating mode rule for the agent that runs it." Keep the prompt text unchanged.
- Verify each skill still contains "Claude mode" and "Generic mode" (the block does) — existing tests AT-12/AT-2.

### Step 4 — `.buildit/guidelines/language-framework.md` line ~75
Replace "If agent identity is relevant, detect it first (e.g. check for a `.claude/` directory) and store the result in a variable" with "If the mode is relevant, determine it with the `**Operating mode rule**` (agent identity, `.buildit/guidelines/team-practices.md`) and store the result in a variable".

### Step 5 — README
- Line ~174: `**`MODE`**` — `claude` when the running agent is Claude / Claude Code, `generic` for any other agent (Operating mode rule: agent identity, never the presence of `.claude/`).
- Line ~364 (plan): "Detects mode (Claude vs generic)" → "Detects mode from agent identity (Claude vs generic)".
- Line ~320 (bootstrap): append that a switched answer applies only to the kit generated in that run, not persisted.
- Check discover's README section and any other "mode" mention for consistency. No heading changes (AT-R9).

### Step 6 — Verify
`bash tests/test-mode-detection.sh` green, then `bash tests/run-all.sh` all green (watch test-tracking-file-discovery, test-config-parsing-boundary, test-buildit-feature-run Subagent autonomy count, test-readme AT-R9, test-skills-invariants).
Stage all touched files by explicit path before `to-validate`.

## Self-critique
- **Assumption: one block can be byte-identical across guideline and skills.** The guideline speaks of "this skill" generically — fine since the wording "the agent running this skill" reads correctly in both. Decision: guideline copy is the reference (it is the single source the description names).
- **Risk: the rule's own "never infer from the presence of `.claude/`" sentence tripping the forbidden-pattern scan.** Forbidden patterns are exact strings (`ls .claude/`, "`.claude/` directory exists", "check for a `.claude/` directory"); the block wording must avoid all three. Test covers it automatically (the block lives in scanned files).
- **Risk: bootstrap §135 "practices directory exists" false positive** — patterns are scoped to `.claude/`, so no hit.
- **Edge: `.claude/skills` is a symlink to `../skills`** — scan only `skills/*/SKILL.md` to avoid double counting; never edit through the symlink path separately.
- **Edge: the awk extractor stops at the first blank line** — the block must have no blank line inside, and the line after the block must be blank (otherwise the local mapping would be absorbed and copies would diverge). Each skill: block, blank line, mapping.
- **Edge: block inside a list/indented context** — awk compares `$0 == h`, so the heading must be at column 0 in every file (check plan/discover where it sits under a step).
- **Risk: other tests grep the old wording** (e.g. "Determine your operating mode from your agent identity" or `ls .claude/`). Checked: only AT-12/AT-2 regexes for "Claude mode"/"Generic mode", both still satisfied. Re-run full suite to be sure.
- **Risk: run's Subagent autonomy block** — untouched; the README example `(mode: [MODE])` stays valid since `MODE` is still `claude`/`generic`.
- **Bootstrap generated kit**: bootstrap may emit a team-practices guideline template for target projects; grep showed no `ls .claude/` in bootstrap, so nothing to propagate. If bootstrap copies `.buildit/guidelines/team-practices.md` content, the new block travels with it.
- **Vague step tightened**: AT-2 "not persisted" is tested via the rule phrase `never persisted` plus absence of a mode heading in bootstrap's `.buildit/config.md` template.

## Decisions
- No worktree (caller instruction): work directly on `fix/audit`.
- Reference copy for byte-identity = the guideline block in team-practices.md.
- Forbidden-pattern set extended with "check for a `.claude/` directory" (the language-framework phrasing) so AT-4's "directory-existence mode check" covers it.
- Block wording finalised: "identity of the agent running this skill" (reads correctly in both the guideline and the skills); "nor in any other file" for non-persistence.
- Guideline intro paragraph renamed "**Operating mode.**" (was "Operating mode detection.") and lists the 7 skills holding copies plus the guarding test.
- Local mappings after the block: discover "Set `SKILLS_DIR` to the skills directory of your mode."; run "Store the result as `MODE` (`claude` or `generic`)."; validate/ship/audit/bootstrap "`<rules-file>` = the rules file of your mode."; plan needs no mapping (only refers to mode in step 0).
- Bootstrap: non-persistence sentence appended to the existing "Use the confirmed mode..." line; prompt text unchanged.
- No shared-context Decisions entry: the copy-a-rule-verbatim convention already exists in team-practices.
- No "Operating mode rule" example added to the "Rules shared between independently deployed skills" paragraph (not required, YAGNI).

## Progress
- Step 1: tests/test-mode-detection.sh written, red (31 failures).
- Steps 2-5: guideline block, 7 skill copies, language-framework anti-pattern, README (MODE bullet, bootstrap step 1, plan step 1) updated.
- Step 6: test-mode-detection 32/32; `bash tests/run-all.sh` 828 passed, 0 failed. Feature files staged by explicit path.
