# simplify-stops-legacy-harness

## Status
to-ship

## Branch
fix/audit

## Worktree path
none

## Goal
Reduce accidental complexity in the cycle skills on three independent fronts.

(a) The `## Last error` protocol: today build, validate and ship each clear a stale `## Last error` at start AND buildit-feature-run clears it before each phase (double mechanism); the "write a `## Last error` section … single line … replacing any existing section" instruction is restated at every stop (~7 times); ship signals a block through two channels (the file and a `SHIP BLOCKED:` final message). Decision taken by the user: buildit-feature-run is the only clearer; phases only write; each writer skill defines its deliberate-stop procedure once; ship uses the file only.

(b) Legacy fallbacks: remove the "tracking file without `## Branch`" fallbacks and the `.claude/guidelines/` → `.buildit/guidelines/` migration note outside bootstrap. Keep the git < 2.30 fallbacks (user decision).

(c) Harness details in skills: the Claude Code `&&`/allow-rules explanation is human documentation, not agent instruction — remove it from the autonomy block sent to every phase subagent and from bootstrap's per-pattern rationale, keeping it once in the README.

## Acceptance Tests
1. `buildit-feature-run` is the only skill that clears `## Last error`: the "remove it (it describes a previous run)" instructions are gone from build step 1, validate step 1 and ship step 0; run keeps its single "Clear a stale Last error" definition applied before build, validate and ship.
2. `buildit-feature-build`, `buildit-feature-validate` and `buildit-feature-ship` each define a deliberate-stop procedure exactly once (write a `## Last error` section with the single line `<skill-name>: <reason>`, replacing any existing one; keep/restore the status the stop specifies); each individual stop references that procedure with only its reason and status, instead of restating the write instruction.
3. Ship no longer emits `SHIP BLOCKED:`: every blocked or deliberate stop after a tracking file is selected writes `## Last error` only; the "Running as a subagent" section keeps the no-commit / no-move / status-stays-`to-ship` rules. buildit-feature-run's "Unexpected state after ship" message reports the `## Last error` line only (no `SHIP BLOCKED:` alternative). When ship stops before selecting a tracking file, run's failed-check report is sufficient.
4. The tracking-file `## Branch` legacy fallbacks are removed from buildit-feature-run (`SHIP_REF`) and buildit-feature-ship (feature branch). In ship, a tracking file without `## Branch` is a deliberate stop (using the procedure from AT2); run reads `SHIP_REF` from `## Branch` only.
5. The guidelines migration note (`.claude/guidelines/` or `.agents/guidelines/` found instead of `.buildit/guidelines/`) and its `## Last error` stop are removed from buildit-feature-validate and buildit-feature-ship; buildit-project-bootstrap keeps its migration logic. The git < 2.30 fallbacks in validate and ship are kept unchanged.
6. The sentence explaining that Claude Code checks each `&&` subcommand against allow rules is removed from buildit-feature-run's Subagent autonomy block (the worktree instructions — run tests with the worktree as working directory, use `git -C <worktree-path>` — stay), and the README's copy of that block matches. buildit-project-bootstrap keeps the settings.json template and its create/audit behaviour but replaces the per-pattern rationale with a pointer to the README section "settings.json permission file (Claude mode only)". In the README, the `&&` / allow-rule explanation appears once, in that section; other places point to it.
7. README (tracking file `## Last error` description, status lifecycle table, ship description, autonomy section) and bootstrap's tracking-file / Last error description reflect AT1–AT6; cross-skill contract tests, per-skill tests and README tests are updated or added (section-scoped, `tests/lib/assertions.sh` helpers, content-assertion convention); `bash tests/run-all.sh` passes.

Derived documentation tests (team-practices "Documentation requirements" — skill modification, interface of the stop signal changes):
- D1. `.buildit/guidelines/team-practices.md` tracking-file "Last error:" line stays identical to bootstrap's template line (existing contract test) and states feature-run as the only clearer.
- D2. Design specs that describe the removed behaviour are realigned: `docs/buildit/specs/2026-11-24-buildit-feature-run-design.md` (step 6 no longer quotes `SHIP BLOCKED:`; run is the only clearer) and `docs/buildit/specs/2026-11-24-subagent-isolation-design.md` ("No human behind a subagent": ship writes `## Last error`, no `SHIP BLOCKED:`). No new spec file: the single-clearer rule is a simplification, recorded in the existing run design spec.

## Plan

Repository rules: edit `skills/<name>/SKILL.md` only (`.claude/skills` is a tracked symlink to `../skills`). Skills in English. Stage by explicit path; never stage `.scratch/plan/`, `.scratch/audits/`, `.scratch/24-11-2026-audit-issues.md`.

### Step 1 — failing tests first (TDD)
Update tests so they describe the target state and fail on the current skills:

1. `tests/test-cross-skill-contracts.sh`, AT-7 block (lines ~241–319):
   - Replace the three `in_text … "$CLEAR"` assertions (ship step 0, validate step 1, build step 1) with `absent_in_text` assertions: no "If the tracking file has a `## Last error` section, remove it" and no "it describes a previous run" in build, validate, ship (whole file, so it cannot move elsewhere).
   - Assert run still defines `**Clear a stale Last error:**` once in "Subagent selection and workflow isolation" and applies the reference before 5.2, 5.4 and 6 (existing assertions — keep).
   - New: for each writer skill (build, validate, ship), the procedure heading `**Deliberate stop procedure**` appears exactly once (`count_outside_fences`), and its block (`named_block`) contains `with the single line \`<skill>: <reason>\``, `replacing any existing \`## Last error\` section` and the status rule.
   - New: the write instruction `\`## Last error\` section to the tracking file with the single line` appears exactly once per writer skill (count = 1, i.e. only inside the procedure). Replace the current WRITER_RE loop accordingly (it currently enumerates per-stop writers).
   - Each stop references the procedure with its reason: validate status guard (`reason \`status is <status>, expected to-validate\``), validate base branch (`reason \`base branch <base-branch> not found locally\``, status `to-validate`), build unrelated files (`reason \`unrelated files block validation — <paths>\``, entry status), ship base branch, ship subagent block (`reason \`blocked — <precise reason>\``), ship missing `## Branch`. Assert each reason appears in the expected step section next to the reference text "Deliberate stop procedure".
   - Remove the ship 0a assertions (migration note) and the `SHIP BLOCKED` assertions; add `absent_in_text` for `SHIP BLOCKED` across every `skills/*/SKILL.md` and README.md.
   - Run verify message: `absent_in_text` for `SHIP BLOCKED:` in the "Verify ship" section; keep `\`## Last error\` line of the tracking file`.
   - Ship discovery stop: replace the SHIP BLOCKED-after-rule assertion with: step 0 states that a discovery stop writes no `## Last error` (no tracking file selected) — keep `there is no \`## Last error\` to write`-style anchor, reworded as needed.
   - README lifecycle table: ship row has `## Last error` and no `SHIP BLOCKED`; no "migration note" in the ship row.
   - Bootstrap/team-practices Last error line: drop "replaces"-per-writer checks that no longer fit; assert it says feature-run is the only clearer (e.g. contains `only feature-run clears it` / `Clearer: feature-run only`) and does not mention "when they start" / "ship step 0" / "migration note".
2. `tests/test-buildit-feature-ship.sh`:
   - AT-SV-2b → `require_absent 'SHIP BLOCKED'`; AT-SV-2c keep `buildit-feature-ship: blocked — <precise reason>` only if the reason format survives as `reason \`blocked — <precise reason>\`` (adapt anchor).
   - AT-SV-2f → absent clear at start.
   - AT-SV-README → README ship section documents `## Last error`, no `SHIP BLOCKED`.
   - AT-BR-4 legacy → invert: step 0 has no `branch --show-current` fallback and no "legacy"; missing `## Branch` → deliberate stop with reason `no ## Branch in the tracking file` (exact wording decided at build; the test anchors on it).
   - New: no migration note in ship (`absent_in_text` `.claude/guidelines/` and `migration required` in ship SKILL.md); git < 2.30 fallback text still present (`require_text` on the existing fallback line).
   - "Running as a subagent" section keeps: do not commit, do not move the tracking file, status stays `to-ship`.
3. `tests/test-buildit-feature-validate.sh`: line 133 invert (no clear at step 1); add: no migration note (`absent` `.claude/guidelines/`, `.agents/guidelines/` in the section `### 0`); git < 2.30 fallback kept (`require_text 'Fallback for git < 2.30'`).
4. `tests/test-buildit-feature-build.sh`: no clear at step 1; unrelated-files stop references the procedure.
5. `tests/test-buildit-feature-run.sh`: SHIP_REF read from `## Branch` only — `absent_in_text` "Legacy"/`branch --show-current` in the "Record the pre-ship state" section; autonomy block contains no `&&` subcommand / allow-rule sentence but still contains `Run test and script commands with the worktree as working directory` and `git -C <worktree-path>`.
6. `tests/test-buildit-project-bootstrap.sh` AT-TB-3 (lines ~105–112): invert the "each `&&` subcommand" requirement for run and bootstrap → absent; bootstrap keeps the template + create/audit behaviour (existing assertions) and has a pointer to the README section "settings.json permission file (Claude mode only)"; bootstrap still contains its migration logic (`.claude/guidelines/`). Check which files the loop at line ~107 iterates (README probably among them — README keeps it).
7. `tests/test-readme.sh`: AT-R14 (autonomy block equality) keeps working; new: the `&&`/allow-rule sentence (`each \`&&\` subcommand`) appears exactly once in README (`count_outside_fences` + the README autonomy block is fenced, so also check the fenced block lacks it) and inside section `### settings.json permission file (Claude mode only)`; the "Subagent autonomy instruction" section points to that section. README `## Last error` tracking description: "cleared by feature-run before each phase" and no "when build or validate starts".
8. Run `bash tests/run-all.sh` — confirm the new assertions FAIL and record the failing list.

### Step 2 — (a) Last error protocol
1. **build** (`skills/buildit-feature-build/SKILL.md`): delete the clear sentence in step 1. Add one `**Deliberate stop procedure**` block (placed before `## Steps`, e.g. in a short "Deliberate stops" section after "When to use"): bold heading followed by a contiguous list (no blank line) — 1) write a `## Last error` section to the tracking file with the single line `buildit-feature-build: <reason>`, replacing any existing `## Last error` section; 2) set the status the stop specifies (or leave it unchanged when none is given); 3) stop with the stop's message. Rewrite step 5.2's stop as: "restore the entry status and apply the Deliberate stop procedure with reason `unrelated files block validation — <paths>`, then stop with: …".
2. **validate**: delete the clear sentence in step 1. Add the procedure block (same shape, `buildit-feature-validate: <reason>`). Status guard → "apply the Deliberate stop procedure with reason `status is <status>, expected to-validate` (status unchanged)". 2c → "restore `to-validate` … reason `base branch <base-branch> not found locally`".
3. **ship**: delete the step 0 clear sentence. Replace "Running as a subagent" + "Deliberate stops" paragraphs: keep no commit / no move / status stays `to-ship`; any wait-for-confirmation step as a subagent applies the Deliberate stop procedure with reason `blocked — <precise reason>`; define the procedure block once (`buildit-feature-ship: <reason>`, status stays as found — `to-ship` normally; ship never changes the status on a stop). Drop every `SHIP BLOCKED:` mention (lines 19, 21, 34, 60, 70, 199). Discovery-rule stop as subagent: "no tracking file is selected, so nothing is written — the stop message is the final message; buildit-feature-run reports its failed checks". End of skill: "If blocked: nothing committed, reason recorded in `## Last error`."
4. **run**: keep the single "Clear a stale Last error" definition (update wording only if it still says phases also clear). Step 6 launch prompt: "follow its "Running as a subagent" rule instead of waiting" (drop "(blocked signal)" wording if it implies the final message). Unexpected-state message: "[ — ship reported: [`## Last error` line of the tracking file]]".

### Step 3 — (b) legacy fallbacks
1. ship step 0 **Feature branch**: delete the legacy fallback; if the `## Branch` heading is absent or empty → Deliberate stop procedure with reason `no ## Branch in the tracking file` and message "The tracking file has no `## Branch` — add the feature branch under `## Branch` (contract in `buildit-feature-start` step 3), then re-run `/buildit-feature-ship`." Order: this stop must come after the Last error clear removal and after selection (it is). Check that it happens before any write (step 1 onward).
2. run step 6 `SHIP_REF`: "`## Branch` value of the tracking file found at step 4". Remove the legacy and detached-HEAD `HEAD` fallback. If `## Branch` is missing, ship's own stop will record it; run should then not compute `git rev-parse` on an empty ref → state: "if `## Branch` is absent or empty, stop with: "Tracking file has no `## Branch` — …"" before launching ship (simplest, avoids `git rev-parse ''`). Decide at build; keep it to one sentence.
3. validate 0a and ship 0a: remove the **Migration note** paragraphs (and ship's `## Last error` stop). Leave bootstrap's migration logic untouched. Leave `Fallback for git < 2.30` lines untouched in validate and ship (grep both before/after to confirm byte-identical).
4. grep all skills + README for remaining "Legacy tracking file" / "without `## Branch`" / "Migration note" outside bootstrap.

### Step 4 — (c) harness details
1. run "Subagent autonomy block": delete the final sentence "Claude Code checks each `&&` subcommand … (e.g. `Bash(bash *)`)." Keep the rest verbatim.
2. README "Subagent autonomy instruction" fenced block: same deletion (AT-R14 equality). Add one sentence after the block: "Why `cd <worktree-path> && …` needs two allow rules: see [settings.json permission file (Claude mode only)](#…)".
3. bootstrap: replace the `Note:` paragraph (per-pattern rationale, `&&` sentence, security-boundary remark) with one line: "Rationale for each pattern (the `cd` patterns, chained `&&` commands, why the allowlist is not a security boundary): README section "settings.json permission file (Claude mode only)"." Also trim the audit list's per-rule justifications? AT6 says "replaces the per-pattern rationale" — the audit list (`— cover the cd part of cd /abs/path && ...`) is rationale too: keep the list of essential rules (it's behaviour), drop the dash explanations or shorten them to plain names. Keep the template and create/audit flow.
4. README settings.json section keeps the full explanation (the single home of the `&&` text). grep README for other `&&`-allow-rule restatements and replace with pointers.

### Step 5 — docs
1. README: `## Last error` template line ("written by a phase that stops deliberately …; cleared only by feature-run before each phase; reported by feature-run"); lifecycle table ship row ("deliberate stop or block (no `## Branch`, base branch not found, subagent block) | status stays `to-ship`, reason in `## Last error`"); remove "migration note"; ship description line 567 ("records the reason in `## Last error`", no `SHIP BLOCKED`); validate base-branch line 522 check.
2. bootstrap template `Last error:` line and team-practices `Last error:` line — identical text: writers: build (unrelated-files stop, restores the entry status), validate (status guard, base branch not found), ship (missing `## Branch`, base branch not found, subagent block); each writer replaces any existing section through its Deliberate stop procedure. Clearer: feature-run only, before launching each phase. feature-run reports it instead of "possible subagent failure".
3. Design specs (D2).

### Step 6 — verify and hand over
1. `bash tests/run-all.sh` green; `diff -q` skills vs `.claude/skills` sanity check.
2. Final greps: `SHIP BLOCKED` (0 hits in skills/README/docs/guidelines except `.scratch/done`), `describes a previous run` (0), `Legacy tracking file` (0), `each \`&&\` subcommand` (README only, once).
3. Stage by explicit path: the edited `skills/*/SKILL.md`, `README.md`, `.buildit/guidelines/team-practices.md`, `docs/buildit/specs/…`, `tests/*.sh`. `git status --porcelain` check; status → `to-validate`.

### Self-critique (corrections integrated above)
- **Standalone phases now leave stale lines.** Phases no longer clear at start, so a standalone `/buildit-feature-build` that succeeds after an earlier stop keeps the old `## Last error`. Accepted by the user's decision (run is the only consumer and clears before each launch). Document it in the README `## Last error` line ("a stale line may remain after a standalone run; feature-run clears it before each phase") so readers are not surprised. Do not add a phase-side clear back.
- **Writers "replacing any existing section"** remains necessary (standalone re-runs), so it stays inside each procedure.
- **Procedure shape vs. contract test.** Wording differs per skill (skill name, status rule for ship), so it is not a verbatim cross-skill block; the test checks presence-once and the required clauses rather than identity. Do not register it in the identical-block contract list.
- **Ship status rule on stops.** The status-mismatch path (selected file not `to-ship`, subagent) must leave the status unchanged, not force `to-ship`; procedure says "leave the status as found" and the Running-as-a-subagent section keeps "leave the status `to-ship`" for the normal case — make both consistent: "ship never changes the status when it stops".
- **Run without `## Branch`.** `git rev-parse` on an empty `SHIP_REF` would error before ship runs; run must stop itself (one sentence) rather than rely on ship. Keep the message pointing at the tracking file.
- **Existing assertions referencing removed text** (AT-7 WRITER_RE loop, AT-SV-2b, AT-BR-4, AT-TB-3, test-skills-invariants worktree-variant check) — enumerate with `grep -n` before editing to avoid leaving tests that pass vacuously; `require_absent` on a pattern must use a pattern that currently exists (verify red first).
- **README anchor link** for the settings section: GitHub slug of "settings.json permission file (Claude mode only)" is `#settingsjson-permission-file-claude-mode-only`; verify by convention or use plain section name text to avoid a broken anchor.
- **`test-skills-invariants.sh` line 61** forbids the `cd */.worktrees/* && *` variant — unaffected, keep.
- **Bootstrap test loop (AT-TB-3 line ~107)** may include README; README must still say "each `&&` subcommand" there — keep README, drop run/bootstrap from that loop.
- **Risk: over-trimming bootstrap.** The audit list is behaviour (which rules to check); only the explanations go.

## Progress
### Build — 25-11-2026
- Red: 78 new/inverted assertions failed on the current skills (procedure heading absent, phase clears present, SHIP BLOCKED present, legacy ## Branch fallbacks, migration notes, && rationale in run/bootstrap, README duplicates); suite was 1274 passed / 78 failed.
- Green: `bash tests/run-all.sh` → 1352 passed, 0 failed.
- (a) build/validate/ship each have a `## Deliberate stops` section with one `**Deliberate stop procedure**`; every stop references it with `reason \`…\``. Phase-side clears removed; run stays the only clearer. Ship has no `SHIP BLOCKED:`; discovery stop writes nothing (run's failed checks report it).
- (b) ship: missing `## Branch` → deliberate stop with reason `no ## Branch in the tracking file`; run stops before ship when `## Branch` is missing (avoids `git rev-parse ''`). Migration notes removed from validate/ship; git < 2.30 fallback lines untouched (no diff lines).
- (c) `&&`/allow-rule explanation removed from run's autonomy block (and README copy) and bootstrap (pointer to README section; audit list keeps rule names only). README keeps it once in the settings.json section; worktree-mode paragraph and autonomy section point there. language-framework.md "Claude Code permission matching" updated accordingly.
- Extra test adjustments: test-buildit-worktree AT-7 inverted (run no longer names `Bash(cd */.worktrees/*)`); bootstrap AT-TB-3 "run uses Bash(cd */.worktrees/*)" inverted. Bootstrap migration anchor is its `.agents/guidelines/` legacy removal (bootstrap has no `.claude/guidelines/` logic).
- Docs: team-practices + bootstrap Last error line identical ("Clearer: feature-run only"); team-practices drops the `SHIP BLOCKED:` example; specs (run design, subagent isolation, worktree mode) realigned.

- Validate 25-11-2026: staging guard OK (only `.scratch/` entries untracked, ignored); `bash tests/run-all.sh` 1352 passed, 0 failed; base branch `main` (no `.buildit/config.md`, default). Review GO on the staged diff (branch commits belong to earlier features). Acceptance AT1–AT7, D1, D2 PASS. Non-blocking notes: ship "Running as a subagent" says "the status stays `to-ship`", while the status-mismatch path (selected file not `to-ship`) leaves the status as found — the procedure step 2 ("never change the status") governs, but the wording could say "unchanged"; the `&&`/allow-rule explanation also remains in `language-framework.md` and the worktree-mode spec (outside the README scope of AT6, acceptable as guideline/spec context). Autonomous decision: validated without a human.

### Ship — 25-11-2026
- Readiness: OK (only this branch in Merge readiness; no API or constraint entries). shared-context cleaned (own row removed); nothing to migrate.
- Retro: (1) Slowdown — inverting many existing assertions (AT-7 writer loop, AT-SV-2b, AT-BR-4, AT-TB-3, worktree AT-7) before the new ones could fail cleanly; the plan's pre-enumeration via grep kept it bounded. (2) No missing configuration: the section-scoped test convention and the explicit-path staging rule covered the work. (3) The plan was precise; one residual wording nit from validate (ship "Running as a subagent" says "status stays `to-ship`" while the procedure says "never change the status") is left as a follow-up, not a config gap.
