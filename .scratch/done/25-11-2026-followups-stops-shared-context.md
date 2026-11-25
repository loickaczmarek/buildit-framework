# followups-stops-shared-context

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Fix the three residues left by the two previous features (shared-context-local-state, simplify-stops-legacy-harness): a wording conflict in buildit-feature-ship, two skills that do not yet handle a missing `.scratch/shared-context.md` (now gitignored local state that a fresh clone does not have), and remaining duplicate copies of the Claude Code `&&` / allow-rules explanation.

## Acceptance Tests
1. buildit-feature-ship "Running as a subagent" section no longer says "the status stays `to-ship`"; its wording agrees with the Deliberate stop procedure (step 2: never change the status, leave it as found).
2. buildit-project-audit no longer stops when `.scratch/shared-context.md` is absent: its prerequisite check (step 0b) is removed or rewritten so a missing file is treated as empty (nothing to read), and any later reference to the file is consistent with that.
3. buildit-feature-discover states explicitly, where it reads `.scratch/shared-context.md` (phase 1), that a missing file is treated as empty (no constraints, decisions or in-progress branches to consider).
4. The full Claude Code `&&` / allow-rules explanation exists once, in the README section "settings.json permission file (Claude mode only)". `.buildit/guidelines/language-framework.md` keeps only the authoring rule (do not repeat this harness detail in skills) plus a pointer to that README section; `docs/buildit/specs/2026-11-24-worktree-mode-design.md` replaces its explanation with a pointer to the same README section.
5. README descriptions of buildit-project-audit and buildit-feature-discover reflect AT2–AT3 where they mention shared-context; tests are added or updated (section-scoped, `tests/lib/assertions.sh` helpers, content-assertion convention in README "Running tests"); `bash tests/run-all.sh` passes.

## Plan

Context: skills live in `skills/` (`.claude/skills` is a symlink to `../skills`, so one edit covers both deployments). Work directly on `fix/audit`. Never stage `.scratch/plan/`, `.scratch/audits/`, `.scratch/24-11-2026-audit-issues.md`.

### Failing tests first (TDD)

T1 — `tests/test-buildit-feature-ship.sh` (AT1), scoped to `SUB=$(section "$SKILL" '## Running as a subagent' | normalize)`:
- Replace line 67 (`in_text ... 'status stays \`to-ship\`'`) with:
  - `absent_in_text "AT-FU-1: subagent rule no longer says the status stays to-ship" "$SUB" 'status stays'`
  - `in_text "AT-FU-1: subagent rule — status left as found" "$SUB" '<chosen phrase, e.g. never change the status>'`
  - Keep the existing do-not-commit / do-not-move assertions.
- Also assert the Deliberate stop procedure step 2 still contains `Never change the status` (section `## Deliberate stops`), so both sides are pinned.

T2 — `tests/test-buildit-project-audit.sh` (AT2):
- Replace AT-13 (lines 56–58, whole-file `require_text shared-context.md` + generic `not found` regex) with:
  - `require_absent "AT-FU-2: no shared-context prerequisite stop" "$SKILL" 'Shared context file not found'`
  - `require_absent "AT-FU-2: no Prerequisite check step" "$SKILL" '^### [0-9]+[a-z]?\. Prerequisite check'`
  - `require_absent "AT-FU-2: audit never requires shared-context.md" "$SKILL" 'shared-context\.md` does not exist, stop'`
- `tests/test-cross-skill-contracts.sh` lines 110–115: the "audit still needs shared-context.md" loop asserts the opposite of AT2 → remove it, and add audit to the `require_absent ... 'Shared context file not found'` loop (AT-SCL-3 list). Update the comment. Check whether `PRE_MSG` is used elsewhere; delete it if not (YAGNI).

T3 — `tests/test-buildit-feature-discover.sh` (AT3): scope to the phase 1 section (find the exact heading holding "1. Read `.scratch/shared-context.md`"; use `section "$SKILL" '<phase 1 heading>'`), then
  - `in_text "AT-FU-3: discover phase 1 treats a missing shared-context.md as empty" "$P1" 'If `.scratch/shared-context.md` does not exist, treat it as empty'` — reuse the exact phrase `ABSENT_EMPTY` used by build/validate/ship (cross-skill vocabulary consistency).
  - `in_text_re` for `in-progress branches` in the same section.
  - Also add discover to the AT-SCL-3 `ABSENT_EMPTY` loop in test-cross-skill-contracts.sh (one consistent contract) — optional if it makes the skill-specific test redundant; keep the skill-specific section-scoped one, add discover to the cross-skill list as well (both cheap, different scopes: section vs file).

T4 — AT4 tests (put in `tests/test-readme.sh`, the README/doc owner, or a section in test-cross-skill-contracts.sh — choose test-readme.sh since README is the single source):
  - README section `### settings.json permission file (Claude mode only)` contains `checks each \`&&\` subcommand against the allow rules separately` (pins the full explanation's location).
  - Count across README + `.buildit/guidelines/language-framework.md` + `docs/buildit/specs/2026-11-24-worktree-mode-design.md` + `skills/*/SKILL.md` of a distinctive phrase of the explanation (e.g. regex `subcommand` / `each .&&. subcommand`) == 1, and that one is in the README section.
  - language-framework.md: the `**Claude Code permission matching**` bullet (use `grep` on the bullet line) contains a pointer `#settingsjson-permission-file-claude-mode-only` and the authoring rule (e.g. `do not repeat`), and does NOT contain `subcommand`, `navigation hygiene` or `<root>/../x`.
  - worktree spec: the paragraph (line 36 today) contains the README anchor `#settingsjson-permission-file-claude-mode-only` (or the README section title) and no `subcommand`.
  - Also assert "navigation hygiene" appears once across these files (second distinctive part of the explanation).

T5 — README (AT5) in `tests/test-readme.sh`, scoped with `section README.md '### \`buildit-project-audit\`'` and `### \`buildit-feature-discover\``:
  - audit section: absent `checks for \`.scratch/shared-context.md\``; no mention implying a requirement.
  - discover section: contains `missing` / `treated as empty` wording near `shared-context.md`.

Run `bash tests/run-all.sh` → confirm the new assertions FAIL (and only they).

### Implementation

I1 — `skills/buildit-feature-ship/SKILL.md` "Running as a subagent": replace "— the status stays `to-ship` —" with "never change the status (leave it as found) —" or simply drop the clause and rely on "apply the Deliberate stop procedure", but keep an explicit phrase matching T1. Target sentence: "…blocks instead: do not commit, do not move the tracking file, never change the status (leave it as found) — and apply the Deliberate stop procedure with reason `blocked — <precise reason>`." Rephrase cleanly so punctuation reads well.

I2 — `skills/buildit-project-audit/SKILL.md`: delete `### 0b. Prerequisite check` and its body (lines 47–50 + the following `---` separator only if it becomes doubled — check layout). Audit never reads shared-context.md elsewhere (grep confirmed only line 49), so nothing else is inconsistent. Re-grep after edit: `grep -n shared-context skills/buildit-project-audit/SKILL.md` should return nothing (or only consistent mentions).

I3 — `skills/buildit-feature-discover/SKILL.md` phase 1 step 1: add "If `.scratch/shared-context.md` does not exist, treat it as empty: there are no constraints, decisions or in-progress branches to consider." Also check line 88/126 references (they are conditional "if a constraint from shared-context applies" → consistent with empty; no change).

I4 — `.buildit/guidelines/language-framework.md` line 87: rewrite bullet to: "**Claude Code permission matching**: harness detail for humans, not an agent instruction — do not repeat it in skills (bootstrap's settings template, step 2b, and run's Subagent autonomy block only point to it). Explained once in the README: [settings.json permission file (Claude mode only)](../../README.md#settingsjson-permission-file-claude-mode-only)." Verify relative link path from `.buildit/guidelines/` → `../../README.md`.
   `docs/buildit/specs/2026-11-24-worktree-mode-design.md` line 36: replace with "Claude Code allow rules for the chained command (`cd <worktree-path> && <test command>`): see the README section [settings.json permission file (Claude mode only)](../../../README.md#settingsjson-permission-file-claude-mode-only); bootstrap points to it and run's Subagent autonomy block does not repeat it." Keep the fact that the template includes `Bash(cd */.worktrees/*)` only if it's not the explanation — simplest: pointer only. Line 28 (`cd <worktree-path> && <test command>`) is the design statement, not the explanation → keep.
   README line 227 stays the single full explanation; lines 187 and 611 are already pointers → keep.

I5 — README:
  - audit section step 1: "Detects agent identity (Claude vs other agent)" — drop "and checks for `.scratch/shared-context.md`".
  - discover section step 2: "Reads `shared-context.md` (a missing file is treated as empty), guidelines, …".

I6 — Run `bash tests/run-all.sh`; all green. Stage by explicit path: skills/buildit-feature-ship/SKILL.md, skills/buildit-project-audit/SKILL.md, skills/buildit-feature-discover/SKILL.md, .buildit/guidelines/language-framework.md, docs/buildit/specs/2026-11-24-worktree-mode-design.md, README.md, tests/test-buildit-feature-ship.sh, tests/test-buildit-project-audit.sh, tests/test-buildit-feature-discover.sh, tests/test-cross-skill-contracts.sh, tests/test-readme.sh. Confirm `git status --porcelain` shows only the three unrelated untracked items plus this tracking file.

### Self-critic (corrections applied above)
- Assumption: `.claude/skills` is a symlink to `skills/` — verified (`ls -la`), so no dual copy to sync. The discover test file has a `SKILL_SRC`/`SKILL_DEPLOYED` check; editing via `skills/` keeps them identical.
- Edge: test-cross-skill-contracts.sh line 110–115 actively asserts audit HAS the prerequisite stop → would fail after I2; explicitly included in T2. Also test-buildit-project-audit.sh AT-13 matches loosely (`not found` regex may still pass from the "Scope target … does not exist" sentence) — so it would not catch the regression; replaced with precise absent checks.
- Edge: removing `### 0b.` may leave numbering 0 → 1 — fine; check no other text says "step 0b" in audit or README (grep showed none).
- Edge: AT4 "exists once" — the phrase `checks each \`&&\` subcommand` must not remain in language-framework or the spec; README lines 187/611 use different wording (pointers) → they won't break a count on `subcommand`. Verify `subcommand` is not used in any other skill (grep before asserting the count; scope the count to the four documented locations + skills/).
- Risk: the tracked `.scratch/done/` archives may contain the old text; exclude `.scratch/` from any count.
- Vague step clarified: exact pointer anchor `#settingsjson-permission-file-claude-mode-only` (already used in README lines 187/611 — proven anchor).
- Consistency: reuse the `ABSENT_EMPTY` phrase already shared by build/validate/ship for discover (and phrase audit as simply not depending on the file — audit has nothing to read, so no "treat as empty" sentence is needed; AT2 allows removal).
- Ship test currently has `'status stays \`to-ship\`'` as a positive assertion — must be inverted in T1, or it will fail after I1 (expected red→green order: write the new test first, see it fail).

Plan validated by the agent after self-critic (no human available, inputs confirmed by the caller).

## Progress
