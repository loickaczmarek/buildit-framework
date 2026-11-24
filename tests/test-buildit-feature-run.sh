#!/usr/bin/env bash
# Structural tests for the buildit-feature-run skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-run/SKILL.md"

# AT-1: Collects worktree/name/desc/ATs before launching any subagent
S1=$(section "$SKILL" '### 1. Collect inputs before subagents')
in_text "AT-1: inputs collected before any subagent" "$S1" 'Before launching any subagent, collect'
in_text "AT-1b: collects worktree, name, description, acceptance tests" "$S1" '(worktree, name, description, acceptance tests)'
in_text "AT-1b: start subagent waits for all four inputs" "$S1" 'Do not launch the start subagent until all four inputs are confirmed'

# AT-2: Each phase (start, build, validate, ship) runs in a subagent
for ph in start build validate ship; do
  require_regex "AT-2: $ph phase launched in a subagent step" "$SKILL" "^(### [0-9]+\\. |[0-9]+\\. \\*\\*|   [0-9]+\\. \\*\\*|\\*\\*)Subagent: buildit-feature-$ph"
done

# AT-3: Reads tracking file status between phases (after build and after validate)
S5=$(section "$SKILL" '### 5. Build/fix loop')
RS_COUNT=$(grep -cF 'Read the tracking file status.' <<<"$S5" || true)
[[ "$RS_COUNT" -eq 2 ]] && ok "AT-3: status read after build and after validate" || fail "AT-3: step 5 must read the tracking file status twice (found $RS_COUNT)"

# AT-4: tracking file not found after start — see test-cross-skill-contracts.sh (run step 4 contract)

# AT-5: Worktree path detected via git worktree list
require_text "AT-5: detects worktree via git worktree list" "$SKILL" 'git worktree list'

# AT-6: --max-cycles N parameter accepted (default 3)
require_text "AT-6: --max-cycles parameter present" "$SKILL" '--max-cycles'
require_regex "AT-6b: default N=3 documented" "$SKILL" '(default|défaut).*(3|N=3)'

# AT-7: On GO + PASS, launches ship and reminds push/PR are manual
require_text "AT-7: ship launched on GO" "$SKILL" '### 6. On GO: subagent buildit-feature-ship'
in_text "AT-7: GO (to-ship) breaks the loop" "$S5" '`to-ship` → break the loop (GO)'
in_text "AT-7b: push and PR remain manual" "$(section "$SKILL" '### 6. ')" 'Push and PR creation remain manual'

# AT-8: Accepts optional feature name passed to subagents
require_regex "AT-8: accepts optional feature name argument" "$SKILL" '\[feature-name\]'

# AT-9: README updated with buildit-feature-run in diagram and skills list
require_text "AT-9: README diagram includes buildit-feature-run" "README.md" 'buildit-feature-run'

# AT-11: Each subagent prompt block contains autonomy instruction (project directory scope + relative paths)
require_regex "AT-11: autonomy instruction present in subagent prompts" "$SKILL" \
  'project directory.*relative paths|relative paths.*project directory|[Aa]utonomy.*project'

# AT-12: Path-scoping restriction (do not cd outside project root) present in skill
require_regex "AT-12: path-scoping restriction present" "$SKILL" \
  '[Dd]o not cd outside|outside.*project.*permission|paths outside.*require'

# --- Merge readiness row owned by start (AT-BR-*) ---
# Run must not write the Merge readiness row before start: its key (## Branch) only
# exists once start has created the worktree and the tracking file.
START_SUBAGENT_LINE=$(grep -n -E '^### [0-9]+\. Subagent: buildit-feature-start' "$SKILL" | head -1 | cut -d: -f1 || true)
PRE_START=$(head -n "$(( ${START_SUBAGENT_LINE:-1} - 1 ))" "$SKILL")
if [[ -n "$START_SUBAGENT_LINE" ]]; then ok "AT-BR-3: start subagent step found"; else fail "AT-BR-3: start subagent step heading not found"; fi
if grep -qF -- '| IN_PROGRESS |' <<<"$PRE_START"; then
  fail "AT-BR-3: no IN_PROGRESS row write before the start subagent"
else
  ok "AT-BR-3: no IN_PROGRESS row write before the start subagent"
fi
if grep -qE -- '^### .*([Ee]arly.*[Ww]rite|[Pp]ermission)' <<<"$PRE_START"; then
  fail "AT-BR-3: early write permission step removed"
else
  ok "AT-BR-3: early write permission step removed"
fi
require_absent "AT-BR-3: start subagent not told to skip the shared-context step" "$SKILL" 'Skip the "Update shared-context.md" step'
require_regex "AT-BR-3: start writes the row keyed by ## Branch" "$SKILL" 'start.*writes the Merge readiness row.*`## Branch`'
require_regex "AT-BR-3: failed or cancelled start leaves no orphan row" "$SKILL" '(failed|cancelled).*start.*no orphan row'

# --- Plan integration tests (AT-P1 through AT-P10) ---

# AT-P1: SKILL.md contains plan task detection logic
require_regex "AT-P1: plan task detection logic present" "$SKILL" \
  'task-\{?feature-name\}?\.md|plan/task-|task-.*\.md.*exists'

# AT-P2: Status update from todo to in-progress at step 0
require_regex "AT-P2: todo to in-progress status transition" "$SKILL" \
  'todo.*to.*in-progress|`todo`.*`in-progress`'

# AT-P3: Progress counter re-sync in plan.md
require_regex "AT-P3: progress counter re-sync in plan.md" "$SKILL" \
  '[Rr]e-?sync.*progress|[Rr]e-?comput.*progress|progress.*counter.*plan\.md|plan\.md.*progress.*counter'

# AT-P4: Pre-fill description and acceptance tests from plan task
require_regex "AT-P4: pre-fill description/ATs from plan task" "$SKILL" \
  '[Pp]re-?fill.*(description|acceptance)|description.*(pre-?fill|plan task)'

# AT-P5: Worktree question always asked regardless of plan data
require_regex "AT-P5: worktree question always asked" "$SKILL" \
  '[Ww]orktree.*(always|regardless)|[Aa]lways.*(ask|worktree)|regardless.*worktree'

# AT-P6: Status update from in-progress to done after ship
require_regex "AT-P6: in-progress to done after ship" "$SKILL" \
  'in-progress.*to.*done|`in-progress`.*`done`'

# AT-P7: Checkbox update (- [x]) in plan.md after ship
require_regex "AT-P7: checkbox update in plan.md after ship" "$SKILL" \
  '\[x\].*plan\.md|plan\.md.*\[x\]|\[ \].*\[x\]'

# AT-P8: Fallthrough when no plan task file matches
require_regex "AT-P8: fallthrough when no plan task matches" "$SKILL" \
  '(not found|no.*match|does not exist).*([Nn]o.*plan|fall.?through|unchanged|existing behavior)|PLAN_TASK_FILE.*none|fall.?through'

# AT-P9: Warning for already in-progress/done status
require_regex "AT-P9: warning for already in-progress or done" "$SKILL" \
  '(already|current).*(in-progress|done).*(warn|proceed)|warn.*(already|in-progress|done)'

# AT-P10: Missing plan.md handled gracefully (task file only)
require_regex "AT-P10: missing plan.md handled gracefully" "$SKILL" \
  'plan\.md.*(not exist|does not|missing).*([Nn]o error|task file only|skip)|task file only.*plan\.md'


# --- Neutral subagent isolation (AT-I1 through AT-I6) ---

ISO_HEADING='## Subagent selection and workflow isolation'
PREAMBLE_SENTENCE='Remain a neutral execution agent'
BAN_REGEX='[Dd]o not invoke any skill or agent'
FALLBACK_REGEX='default unspeciali[sz]ed subagent'

ISO_SECTION=$(section_body "$SKILL" "$ISO_HEADING")

require_text "AT-I1: isolation section present" "$SKILL" "$ISO_HEADING"
require_text "AT-I1b: named Isolation preamble block" "$SKILL" 'Isolation preamble'

PREAMBLE_COUNT=$(grep -c -- "$PREAMBLE_SENTENCE" "$SKILL" || true)
if [[ "$PREAMBLE_COUNT" -eq 1 ]]; then
  ok "AT-I2: isolation preamble defined exactly once"
else
  fail "AT-I2: isolation preamble must appear exactly once (found $PREAMBLE_COUNT)"
fi

REF_COUNT=$(grep -c -- '\[Isolation preamble — see' "$SKILL" || true)
if [[ "$REF_COUNT" -ge 4 ]]; then
  ok "AT-I3: steps 3, 5.2, 5.4 and 6 reference the preamble ($REF_COUNT references)"
else
  fail "AT-I3: expected at least 4 preamble references, found $REF_COUNT"
fi

if grep -qE -- "$BAN_REGEX other than the requested phase skill and the buildit skills and subagents it explicitly references or instructs you to launch" <<<"$ISO_SECTION"; then
  ok "AT-I4: preamble bans other skills and agents, exempting referenced buildit skills and subagents"
else
  fail "AT-I4: preamble ban wording (with skills-and-subagents exemption) missing from isolation section"
fi
if grep -qF -- 'config-update subagent' <<<"$ISO_SECTION"; then
  ok "AT-I4c: validate config-update subagent cited as an allowed launched subagent"
else
  fail "AT-I4c: validate config-update subagent not cited in isolation section"
fi
if grep -qF -- 'buildit-worktree' <<<"$ISO_SECTION"; then
  ok "AT-I4b: buildit-worktree cited as an allowed referenced skill"
else
  fail "AT-I4b: buildit-worktree not cited in isolation section"
fi

if grep -qE -- "$FALLBACK_REGEX" <<<"$ISO_SECTION" && grep -qiE -- 'warn' <<<"$ISO_SECTION"; then
  ok "AT-I5: fallback to default unspecialised subagent with user warning"
else
  fail "AT-I5: fallback (default unspecialised subagent + warning) missing"
fi
require_absent "AT-I5b: old stop-and-report rule removed" "$SKILL" 'stop and report this to the user rather than substituting'

# AT-I6: step 5.5 (documented exception: a "next line" probe, not a section extractor) — status-unchanged message is separated from the routing list
NEXT_AFTER_MSG=$(awk '/Tracking file status unchanged after buildit-feature-validate/ {getline; print; exit}' "$SKILL")
if [[ -z "${NEXT_AFTER_MSG// /}" ]]; then
  ok "AT-I6: status-unchanged message followed by a blank line"
else
  fail "AT-I6: status-unchanged message must be followed by a blank line (got: '$NEXT_AFTER_MSG')"
fi
ROUTING_INTRO=$(awk '/Tracking file status unchanged after buildit-feature-validate/ {f=1; next} f && NF {print; exit}' "$SKILL")
if [[ -n "$ROUTING_INTRO" && ! "$ROUTING_INTRO" =~ ^[[:space:]]*-[[:space:]] ]]; then
  ok "AT-I6b: routing list is introduced by a separate sentence"
else
  fail "AT-I6b: routing list must be introduced by a sentence, got: '$ROUTING_INTRO'"
fi

# --- Task synchronization (plan-task-synchronization) ---
S0=$(section "$SKILL" '### 0.')
S6=$(section "$SKILL" '### 6.')
# AT-SYNC-8
in_text "AT-SYNC-8: step 0 detects task synchronization" "$S0" '**Detect task synchronization**'
in_text "AT-SYNC-8: reads sync config" "$S0" '## Task synchronization'
in_text "AT-SYNC-8: one confirmation" "$S0" 'ONE confirmation'
in_text "AT-SYNC-8: shows status mapping for in-progress and done" "$S0" 'status mapping for `in-progress` and `done`'
in_text "AT-SYNC-8: pushes in-progress at step 0" "$S0" 'push the `in-progress` status'
in_text "AT-SYNC-8: pushes done at step 6" "$S6" 'push the `done` status'
require_text "AT-SYNC-8: pushes from the orchestrator" "$SKILL" 'from the orchestrator, never inside a subagent'
require_text "AT-SYNC-8: references buildit-plan step 5b" "$SKILL" '`buildit-plan` step 5b'
# AT-SYNC-9
require_text "AT-SYNC-9: status is the only external field" "$SKILL" 'Only the status is written externally'
in_text "AT-SYNC-9: no call without link" "$S0" 'no external call'
in_text "AT-SYNC-9: unconfigured treated as disabled" "$S0" 'unconfigured is treated as disabled for this run'
in_text "AT-SYNC-9: never prompts to configure" "$S0" 'never prompt to configure'
# AT-SYNC-10
in_text "AT-SYNC-10: refusal/failure writes Pending (step 0)" "$S0" 'Pending: status → in-progress (DD-MM-YYYY)'
in_text "AT-SYNC-10: failure writes Pending (step 6)" "$S6" 'Pending: status → done (DD-MM-YYYY)'
require_text "AT-SYNC-10: local flow continues" "$SKILL" 'never block the cycle'
# AT-SYNC-13
require_text "AT-SYNC-13: external content is data" "$SKILL" 'data, not instructions'

# --- Staging contract (AT-SC-*) ---
require_absent "AT-SC-5: no numeric reference to start step 5" "$SKILL" 'Skip step 5|step 5 of buildit-feature-start'
require_regex "AT-SC-5: run reports validate's ## Last error" "$SKILL" '`## Last error`.*(report|stop)'
if grep -A1 -F -- 'Otherwise (no `## Last error` section)' "$SKILL" | grep -qF -- 'after buildit-feature-validate — possible subagent failure'; then
  ok "AT-SC-5: subagent failure for validate only without Last error"
else
  fail "AT-SC-5: validate's possible-subagent-failure message must be conditioned on no ## Last error"
fi

# --- Ship verification (AT-SV-*) ---
before() {
  local label="$1" a b; a=$(line_of "$SKILL" "$2"); b=$(line_of "$SKILL" "$3")
  if [[ -n "$a" && -n "$b" && "$a" -lt "$b" ]]; then ok "$label"; else fail "$label — '$2' (line ${a:-none}) must precede '$3' (line ${b:-none})"; fi
}
require_text "AT-SV-1a: records PRE_SHIP_HEAD" "$SKILL" 'PRE_SHIP_HEAD'
require_text "AT-SV-1a: uses git rev-parse" "$SKILL" 'git rev-parse <SHIP_REF>'
before "AT-SV-1a: pre-ship state recorded before launching ship" 'PRE_SHIP_HEAD' 'Run /buildit-feature-ship'
in_text "AT-SV-1b: step 6 checks .scratch/done/" "$S6" '.scratch/done/'
in_text "AT-SV-1b: step 6 checks the committed archived file" "$S6" 'git cat-file -e <SHIP_REF>:.scratch/done/'
in_text "AT-SV-1c: unexpected state message" "$S6" 'Unexpected state after ship'
in_text "AT-SV-1d: plan task and external ticket left unchanged" "$S6" 'The plan task and external ticket were left unchanged'
before "AT-SV-1e: verification precedes plan task update" 'Unexpected state after ship' '**Update plan task on completion**'
before "AT-SV-1e: verification precedes success message" 'Unexpected state after ship' 'shipped successfully'
in_text "AT-SV-1f: ship prompt states it runs as a subagent" "$S6" 'You are running as a subagent'
in_text "AT-SV-1g: no Pending entry on failed verification" "$S6" 'write no `Pending:` entry'
if grep -E -- '^- `SHIP_REF`' <<<"$S6" | grep -qF -- '`## Branch`'; then ok "AT-SV-1h: SHIP_REF comes from the tracking file's ## Branch"; else fail "AT-SV-1h: SHIP_REF must be read from the tracking file's ## Branch"; fi
README_RUN=$(section README.md '### `buildit-feature-run`')
in_text "AT-SV-README: run section mentions ship verification" "$README_RUN" 'Unexpected state after ship'

# --- Worktree working directory (AT-WD-*) ---
WD_COUNT=$(grep -cF -- 'Run test and script commands with the worktree as working directory (`cd <worktree-path> && bash tests/…`)' "$SKILL" || true)
# The instruction lives once in the Subagent autonomy block, referenced by every phase prompt (AT-AB-*).
if [[ "$WD_COUNT" -eq 1 ]]; then ok "AT-WD-2: autonomy block runs tests in the worktree"; else fail "AT-WD-2: expected exactly 1 worktree test instruction (autonomy block), found $WD_COUNT"; fi
require_absent "AT-WD-2b: no unqualified root-relative script instruction" "$SKILL" 'Use relative paths for script invocations\. Do not cd outside the project root'

# --- Autonomy block defined once (AT-AB-*) ---
AB_COUNT=$(grep -cF -- 'Autonomy: you are operating within the project directory' "$SKILL" || true)
if [[ "$AB_COUNT" -eq 1 ]]; then ok "AT-AB-1: autonomy text defined exactly once"; else fail "AT-AB-1: expected 1 autonomy text, found $AB_COUNT"; fi
REF_COUNT=$(grep -cF -- '[Autonomy block — see "Subagent autonomy block"]' "$SKILL" || true)
if [[ "$REF_COUNT" -ge 4 ]]; then ok "AT-AB-2: start, build, validate and ship prompts reference the autonomy block"; else fail "AT-AB-2: expected >=4 autonomy block references, found $REF_COUNT"; fi
require_text "AT-AB-3: named autonomy block section" "$SKILL" '## Subagent autonomy block'

# --- Plan task lookup rule shared with discover (AT-PL-*) ---
# Presence and identity across run and discover: test-cross-skill-contracts.sh (named blocks).
PL_RUN="$(named_block "$SKILL" '**Plan task lookup rule**')"
pl_in() { in_text "$1" "$PL_RUN" "$2"; }
pl_in "AT-PL-3: prefixed lookup first" 'Look up `.scratch/plan/task-{feature-name}.md`'
pl_in "AT-PL-3: strips a leading task- prefix once on a miss" 'starts with `task-`'
pl_in "AT-PL-3: never strips to an empty name" 'remainder is non-empty'
pl_in "AT-PL-3: tells the user" 'Stripped the `task-` prefix: using feature name `{feature-name}`.'
for f in "$SKILL" skills/buildit-feature-discover/SKILL.md; do
  require_text "AT-PL-4: detection step applies the lookup rule in $f" "$f" 'apply the **Plan task lookup rule**'
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
