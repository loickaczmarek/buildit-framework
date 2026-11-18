# neutral-subagent-isolation

## Status
to-ship

## Worktree path
none

## Goal
Generalise and harden the neutral-subagent rule introduced by the uncommitted Copilot patch on `skills/buildit-feature-run/SKILL.md`, so that delegated subagents run only the workflow they were given — no persona agent or unrelated skill may take over.

1. **buildit-feature-run** — fix the patch: restore the double-quoted `description`; fix the step 5.5 layout so the "status unchanged" message is separate from the to-ship/to-fix routing list; define the isolation preamble ONCE as a named block in the "Subagent selection and workflow isolation" section and reference it from steps 3, 5.2, 5.4 and 6; strengthen the preamble with an explicit ban (no skill or agent other than the requested phase skill and the buildit skills it explicitly references, e.g. buildit-worktree); replace "stop if unavailable" with a fallback (if `general-purpose` does not exist, use the harness's default unspecialised subagent, keep the preamble, warn the user).
2. **buildit-project-audit** — add the same section, adapted to the audit (task-specific instructions — category, critique, trace, calibration, hotspot — instead of "phase skill"). All subagents use `general-purpose` with the preamble and the same fallback.
3. **buildit-feature-validate §5a** — the config-update subagent uses `general-purpose`, the preamble, and the fallback.
4. Each skill defines its preamble once (no include mechanism; each skill stays self-contained).

## Acceptance Tests
- [x] AT1: tests/test-quote-skill-descriptions.sh passes again (AT1/AT3 on buildit-feature-run).
- [x] AT2: buildit-feature-run contains the isolation preamble exactly once; steps 3, 5.2, 5.4 and 6 reference it instead of repeating it.
- [x] AT3: The preamble in buildit-feature-run explicitly forbids invoking skills or agents other than the phase skill and the buildit skills it references.
- [x] AT4: buildit-feature-run describes the fallback (default unspecialised subagent + preamble + user warning); the "stop and report" rule is removed.
- [x] AT5: In buildit-feature-run step 5.5, the "status unchanged" message is separated from the to-ship / to-fix / other routing list.
- [x] AT6: buildit-project-audit has a "Subagent selection and workflow isolation" section covering every subagent type it launches (hotspot, category ×3, critique, execution trace, calibration), with the preamble defined once and the fallback.
- [x] AT7: buildit-feature-validate §5a requires general-purpose, includes the isolation preamble in the subagent instructions, and describes the fallback.
- [x] AT8: No skill hardcodes .claude/ paths; dual deployment holds (.claude/skills → skills/ symlink).
- [x] AT9: Content-assertion tests added to test-buildit-feature-run.sh, test-buildit-project-audit.sh and test-buildit-feature-validate.sh; tests/run-all.sh passes.

## Risks
- Portability of the `general-purpose` agent name across harnesses (mitigated by the fallback).
- The ban is a prompt instruction only — wording must be firm and unambiguous.
- The ban must not block buildit-worktree (invoked by buildit-feature-start) or buildit phase handoffs.
- Count references in the audit skill (description, intro, README) must be updated if subagent counts change.

## Plan

### Step 1 — Failing tests first (TDD)
Add content assertions (using `require_text` / `require_regex` / `require_absent` from `tests/lib/assertions.sh`; for "exactly once" use a `grep -c` check with `ok`/`fail`):

**tests/test-buildit-feature-run.sh**
- Section heading `## Subagent selection and workflow isolation` present.
- A named preamble block marker present (e.g. heading/label `Isolation preamble`), and the preamble's distinctive sentence (`Remain a neutral execution agent`) appears exactly once (`grep -c` == 1).
- Preamble contains the ban: regex matching `[Dd]o not invoke any skill or agent other than` + mention of `buildit skills it explicitly references`.
- Preamble/section mentions `buildit-worktree` as allowed example.
- Fallback: regex `default unspecialised subagent` (accept `unspecialized` too) + `warn` the user.
- `require_absent` for the old rule text `stop and report this to the user rather than substituting`.
- Steps 3, 5.2, 5.4, 6 reference the preamble: at least 4 occurrences of the reference phrase (e.g. `[isolation preamble]` placeholder or "Isolation preamble (see") — `grep -c` ≥ 4.
- Step 5.5 layout: the line `Tracking file status unchanged after buildit-feature-validate` must NOT be immediately followed by a `- \`to-ship\`` line (check with awk: the line after the message line, ignoring nothing, must be blank) — i.e. the blockquote is followed by a blank line and an introductory sentence before the routing list.

**tests/test-buildit-project-audit.sh**
- Section heading `## Subagent selection and workflow isolation` present.
- Mentions `general-purpose`.
- Preamble marker present; distinctive sentence present exactly once.
- Ban wording present (`Do not invoke any skill or agent`).
- Section covers each subagent type: `hotspot`, `category`, `critique`, `execution trace`, `calibration` — checked within the section (extract section with awk between the heading and the next `## ` heading, then grep each term).
- Fallback wording (`default unspecialised|unspecialized subagent`, `warn`).

**tests/test-buildit-feature-validate.sh**
- §5a (extract between `### 5a.` and `### 5b.`) mentions `general-purpose`, contains the preamble's distinctive sentence, contains ban wording, and fallback wording.

Run the three test scripts + test-quote-skill-descriptions.sh and confirm they FAIL before implementation.

### Step 2 — buildit-feature-run
1. Restore `description: "..."` (double quotes, identical text to main). Verify `git diff main -- skills/buildit-feature-run/SKILL.md` shows no frontmatter change.
2. Rewrite the "Subagent selection and workflow isolation" section:
   - Agent selection: always pass `general-purpose` as the agent-type parameter for every phase subagent (start, build/fix, validate, ship).
   - **Fallback** (replaces "stop and report"): if `general-purpose` is not available in the harness, use the harness's default unspecialised subagent (never a specialised persona agent), still include the isolation preamble, and warn the user once: "`general-purpose` agent not available — using the default unspecialised subagent with the isolation preamble."
   - **Isolation preamble** — defined ONCE as a named block (label: `Isolation preamble`), prepended verbatim as the first line(s) of every phase subagent prompt:
     > "Remain a neutral execution agent: the requested buildit phase skill defines your role, procedure, and expected output. Execute that skill without adopting an additional persona or substituting another workflow. Do not invoke any skill or agent other than the requested phase skill and the buildit skills it explicitly references (e.g. `buildit-worktree`). Continue to follow the repository's shared project rules and guidelines."
   - Note that the ban does not block the phase skill's own explicitly referenced buildit skills (e.g. buildit-feature-start → buildit-worktree).
3. Steps 3, 5.2, 5.4, 6: replace the repeated preamble sentence with a placeholder line `> "[Isolation preamble — see "Subagent selection and workflow isolation"]` followed by the phase-specific prompt lines. Keep "Launch a fresh `general-purpose` subagent (or the fallback — see ...)".
4. Step 5.5: move the "status unchanged" blockquote back above the routing list and add a blank line + intro sentence ("Otherwise, route on the status:") before the `- to-ship` / `- to-fix` / `- Anything else` list.
5. Keep the other Copilot formatting changes (blank lines before blockquotes) — they are harmless.

### Step 3 — buildit-project-audit
1. Add `## Subagent selection and workflow isolation` section before `## Steps` (or right after the mode determination block — check exact structure first so it is not inside a numbered step).
2. Content: every subagent launched by this skill — hotspot analysis (step 1), the 3 category subagents (step 4), per-category critique subagents (step 5), cross-cutting execution trace (step 6), calibration (step 7) — is launched with agent type `general-purpose`, same fallback as feature-run (default unspecialised subagent + preamble + warn user).
3. Preamble defined once, adapted:
   > "Remain a neutral execution agent: the task-specific instructions below (hotspot analysis, category audit, critique, execution trace, or calibration) define your role, procedure, and expected output. Execute only those instructions without adopting an additional persona or substituting another workflow. Do not invoke any skill or agent. Continue to follow the repository's shared project rules and guidelines."
   Note: audit subagents reference no buildit skill, so the ban is absolute ("Do not invoke any skill or agent") — wording must still match the test regex `Do not invoke any skill or agent`.
4. In each step that launches a subagent, add a short reference: "(`general-purpose`, prefixed with the isolation preamble — see "Subagent selection and workflow isolation")". Keep it short to avoid bloat; at minimum steps 1, 4, 5a, 6, 7.
5. Counts: no subagent count changes → description, intro and README unchanged. Verify.

### Step 4 — buildit-feature-validate §5a
1. "Launch a `general-purpose` subagent" + fallback sentence (default unspecialised subagent, keep preamble, warn the user).
2. Prepend the preamble (defined once in this skill, inside §5a, since it is the only subagent) to the subagent instructions blockquote:
   > "Remain a neutral execution agent: these instructions define your role, procedure, and expected output. Execute only this configuration-update task without adopting an additional persona or substituting another workflow. Do not invoke any skill or agent. Continue to follow the repository's shared project rules and guidelines."

### Step 5 — Verify
- Run the three skill tests + `tests/test-quote-skill-descriptions.sh` + `tests/run-all.sh` — all green.
- `grep -rn '\.claude/' skills/` — confirm no new hardcoded `.claude/` paths introduced by this feature (pre-existing references in mode-determination blocks are allowed; compare with `git diff main...HEAD` + working tree).
- `ls -la .claude/skills` → symlink to `../skills` still in place.
- Check README for any text describing subagent selection that would now be inaccurate (README line ~144 "Each subagent receives this block") — add a one-line mention of the isolation preamble only if the README already documents subagent prompt content (it does for the autonomy block → add a short note).
- `git status`: stage all modified files before `to-validate`.

## Self-critique (applied to the plan above)
- **Assumption — "exactly once" test is fragile:** the preamble's distinctive sentence must not reappear in the reference placeholders. Placeholders use a different phrase (`[Isolation preamble — see ...]`), so `grep -c 'Remain a neutral execution agent'` == 1 is a reliable check.
- **Assumption — `general-purpose` exists everywhere:** it does not (Copilot, other harnesses). Fallback covers it; also the wording "agent-type parameter of the delegation tool" stays harness-neutral (no Claude-only tool names like `Agent` hardcoded in the new section).
- **Edge case — ban vs. buildit-worktree:** buildit-feature-start invokes buildit-worktree; build may hand off to other buildit skills only via the orchestrator, not inside the subagent. The ban explicitly allows "the buildit skills it explicitly references", so start→worktree stays legal. Ship's retro/plan steps reference no other skill invocation — check ship SKILL.md for any explicit skill reference before finalising wording.
- **Edge case — audit hotspot is optional:** hotspot subagent only runs when no scope argument is given; the section must still list it.
- **Edge case — step 5.5 test:** markdown blockquote immediately followed by list lines would merge visually; the awk check verifies a blank line + non-list line follows the message. Ensure step 5.3's similar structure (build) is unaffected.
- **Vague step tightened:** "reference it from steps" → concrete placeholder text defined above, so tests can count it (≥ 4 in feature-run).
- **Risk — description mismatch:** test-quote-skill-descriptions AT2/AT3 compare `.claude/skills` vs `skills/`; since `.claude/skills` is a symlink both resolve to the same file, but AT3 may check YAML validity — restoring the exact original line from `main` is safest (`git show main:skills/buildit-feature-run/SKILL.md | sed -n 3p`).
- **Risk — test-skills-invariants.sh** may enforce constraints (line counts, forbidden words, `.claude/` paths). Read it before editing to avoid regressions.
- **Risk — preamble in the orchestrator's own launch prompt:** this feature's run is being executed with the old Copilot preamble wording; no conflict, just ensure new wording is a superset.

## Progress

- 18-11-2026 build: failing tests added (feature-run AT-I1..I6, audit AT-I1..I5, validate AT-I1..I4) and confirmed red; implemented feature-run (quoted description restored, preamble defined once + 4 references, ban, fallback, step 5.5 layout), audit isolation section + step references, validate §5a; README "Subagent isolation" note. tests/run-all.sh: 397 passed, 0 failed. No new hardcoded .claude/ paths; .claude/skills symlink intact.

- 18-11-2026 fix cycle: widened feature-run preamble exemption to "buildit skills and subagents it explicitly references or instructs you to launch" (cites buildit-worktree + validate §5a config-update subagent); clarifying sentence, README "Subagent isolation" and shared-context decision aligned; AT-I4 regex tightened + AT-I4c added (red then green); section comment fixed to AT-I1..I6. tests/run-all.sh: 398 passed, 0 failed.

### NO-GO cycle 2 — 18-11-2026
- Review: NO-GO — feature-run isolation preamble bans agents not exempted, contradicting buildit-feature-validate §5a which mandates launching a config-update subagent.
- Acceptance: PASS — AT1–AT9 all satisfied (tests/run-all.sh 397 passed, 0 failed).
