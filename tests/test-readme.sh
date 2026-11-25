#!/usr/bin/env bash
# Structural tests for README.md — factual accuracy and documentation sections.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

README="README.md"

in_section_i() { # label, text, case-insensitive regex
  if grep -qiE -- "$3" <<<"$2"; then ok "$1"; else fail "$1 — regex not found in section: '$3'"; fi
}

# AT-R1: no reference to the deleted feature-run design spec
require_absent "AT-R1: no reference to deleted feature-run design spec" "$README" '2026-09-08-buildit-feature-run-design\.md'

# AT-R2: skill count matches skills/ directories, internal skill noted
N=$(find skills -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
require_text "AT-R2: README states $N skills" "$README" "$N skills"
require_regex "AT-R2: README notes the internal skill" "$README" "$N skills \\([0-9]+ user-facing \\+ the internal \`buildit-worktree\`\\)"

# AT-R3: Project configuration section
CONFIG=$(section "$README" '## Project configuration' '## ')
if [[ -n "$CONFIG" ]]; then ok "AT-R3: Project configuration section exists"; else fail "AT-R3: Project configuration section missing"; fi
for key in '## Test command' '## Base branch' '## Task synchronization' '## Synchronization method' '## Synchronization tag'; do
  in_text "AT-R3: Project configuration documents $key" "$CONFIG" "$key"
done
in_section_i "AT-R3: unconfigured is not the same as disabled" "$CONFIG" 'unconfigured, not disabled|unconfigured is not (the same as )?disabled'
in_section_i "AT-R3: bans secrets" "$CONFIG" 'secret'
in_text "AT-R3: example file" "$CONFIG" '```markdown'

# AT-R4: Plan files section
PLAN_FILES=$(section "$README" '## Plan files' '## ')
if [[ -n "$PLAN_FILES" ]]; then ok "AT-R4: Plan files section exists"; else fail "AT-R4: Plan files section missing"; fi
for p in 'plan.md' 'task-{name}.md' 'todo' 'in-progress' 'done' 'Readiness' '## Synchronization' 'Link:' 'Pending:' 'buildit-feature-run' 'buildit-feature-discover' 'buildit-plan'; do
  in_text "AT-R4: Plan files section mentions $p" "$PLAN_FILES" "$p"
done
for sk in buildit-plan buildit-feature-discover buildit-feature-run; do
  RS=$(section "$README" "### \`$sk\`" '---')
  in_text "AT-R4: $sk section points to Plan files" "$RS" '(#plan-files)'
done

# AT-R5: buildit-worktree inside the skills list under an Internal subheading
SKILLS=$(section "$README" '## Skills' '## ')
if grep -qE -- '^(#+ |\*\*)Internal' <<<"$SKILLS" && grep -qF -- '### `buildit-worktree`' <<<"$SKILLS"; then
  ok "AT-R5: buildit-worktree listed in Skills under an Internal subheading"
else
  fail "AT-R5: buildit-worktree must sit in the Skills section under an Internal subheading"
fi
require_absent "AT-R5: no stray (internal) heading outside the skills list" "$README" '^### `buildit-worktree` \(internal\)'
require_absent "AT-R5: Manual flow skills is not a ### heading" "$README" '^### Manual flow skills'

# AT-R6: manual-flow diagram loop border aligned in a single column
MANUAL=$(section "$README" '## Manual flow' '## ')
if python3 -I - "$MANUAL" <<'PY'
import sys, unicodedata
def width(text):  # display columns: wide/fullwidth chars (e.g. emoji) take 2
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in text)
lines = sys.argv[1].splitlines()
start = next(i for i, l in enumerate(lines) if '◄' in l)
end = next(i for i, l in enumerate(lines) if '┘' in l)
cols = {width(l.rstrip()) for l in lines[start:end + 1]}
sys.exit(0 if len(cols) == 1 else 1)
PY
then ok "AT-R6: manual-flow loop border aligned"; else fail "AT-R6: manual-flow loop border misaligned"; fi

# AT-R7: Running tests part
TESTS=$(section "$README" '## Running tests' '## ')
in_text "AT-R7: Running tests documents run-all" "$TESTS" 'bash tests/run-all.sh'
in_text "AT-R7: Running tests documents assertions helper" "$TESTS" 'tests/lib/assertions.sh'
in_section_i "AT-R7: Running tests documents content-assertion convention" "$TESTS" 'content.assertion'

# AT-R8: validate and ship descriptions reflect staged diff, base branch, staging guard
VALIDATE=$(section "$README" '### `buildit-feature-validate`' '---')
in_text "AT-R8: validate mentions staged diff" "$VALIDATE" '--cached --merge-base'
in_text "AT-R8: validate mentions base branch" "$VALIDATE" 'Base branch'
in_section_i "AT-R8: validate mentions staging guard" "$VALIDATE" 'staging guard'
SHIP=$(section "$README" '### `buildit-feature-ship`' '---')
in_text "AT-R8: ship mentions staged diff" "$SHIP" '--cached --merge-base'
in_text "AT-R8: ship mentions base branch" "$SHIP" 'Base branch'

# Plan handoffs use the bare name; the manual flow does not track the plan task (audit #12, #13)
require_absent "AT-R10: no [task-name] placeholder" "$README" '\[task-name\]'
MANUAL=$(section "$README" '## Manual flow (advanced)')
DISCOVER=$(section "$README" '### `buildit-feature-discover`' '---')
for sec in MANUAL DISCOVER; do
  if grep -qF -- 'does not track plan status' <<<"${!sec}"; then ok "AT-R11: $sec section says the manual path does not track the plan task"; else fail "AT-R11: $sec section misses the manual-path plan note"; fi
done

# --- Audit 24-11-2026 #23: README statements paired with the current skills -------
RUN_SKILL="skills/buildit-feature-run/SKILL.md"
TRACKING=$(section "$README" '## Tracking file structure' '## ')
for h in '## Branch' '## Last error'; do
  in_text "AT-R12: tracking file structure shows $h" "$TRACKING" "$h"
done
absent_in_text "AT-R12: Problems to fix is not cleared at the start of the next cycle" "$TRACKING" 'cleared at the start of the next cycle'
in_text "AT-R12: Problems to fix is cleared by build when it sets to-validate" "$(normalize <<<"$TRACKING")" 'cleared by `buildit-feature-build` when it sets `to-validate`'
in_text_re "AT-R12: status table shows validate restoring to-validate on a deliberate stop" "$TRACKING" 'validate.*stop.*`validating` → `to-validate`.*`## Last error`'

require_absent "AT-R13: no READY status in README" "$README" '\bREADY\b'
require_absent "AT-R13: no Waiting for column or dependency check in README" "$README" '[Ww]aiting for'

# The README copy of run's Subagent autonomy block is the same text, whitespace aside.
RUN_BLOCK=$(section "$RUN_SKILL" '## Subagent autonomy block' | grep -E '^> ' | sed -E 's/^> "?//; s/"$//' | normalize)
README_BLOCK=$(fenced_block "$README" 'Autonomy: you are operating' | normalize)
if [[ -n "$RUN_BLOCK" && "$RUN_BLOCK" == "$README_BLOCK" ]]; then ok "AT-R14: README autonomy block matches run's Subagent autonomy block"; else fail "AT-R14: README autonomy block differs from run's Subagent autonomy block"; fi
# The && / allow-rule explanation lives once, in the settings.json section; other places point to it.
same "AT-R14b: README explains && subcommand matching once" "$(grep -cF -- 'each `&&` subcommand' "$README" || true)" 1
same "AT-R14b: README states the chained-command rule once" "$(grep -cF -- 'chained command needs' "$README" || true)" 1
SETTINGS=$(section "$README" '### settings.json permission file (Claude mode only)')
in_text "AT-R14b: the explanation is in the settings.json section" "$SETTINGS" 'each `&&` subcommand'
absent_in_text "AT-R14b: the README autonomy block carries no allow-rule explanation" "$README_BLOCK" 'subcommand|allow rules'
in_text "AT-R14b: autonomy instruction points to the settings.json section" "$(section "$README" '### Subagent autonomy instruction')" 'settings.json permission file (Claude mode only)'
# AT-FU-4: the full && / allow-rule explanation exists once across docs, guidelines and skills.
FU_DOCS=("$README" .buildit/guidelines/*.md skills/*/SKILL.md)
for phrase in 'subcommand' 'navigation hygiene'; do
  same "AT-FU-4: '$phrase' appears once across README, guidelines and skills" "$(cat "${FU_DOCS[@]}" | grep -c -- "$phrase" || true)" 1
  in_text "AT-FU-4: '$phrase' lives in the README settings.json section" "$SETTINGS" "$phrase"
done
LF_BULLET=$(grep -F -- '**Claude Code permission matching**' .buildit/guidelines/language-framework.md || true)
in_text "AT-FU-4: language-framework bullet points to the README section" "$LF_BULLET" '../../README.md#settingsjson-permission-file-claude-mode-only'
in_text "AT-FU-4: language-framework bullet keeps the authoring rule" "$LF_BULLET" 'do not repeat it in skills'
absent_in_text "AT-FU-4: language-framework bullet carries no explanation" "$LF_BULLET" 'subcommand|navigation hygiene|<root>/\.\./x'
# AT-FU-5: README audit and discover sections reflect that shared-context.md may be missing.
absent_in_text "AT-FU-5: README audit section no longer checks for shared-context.md" "$(section "$README" '### `buildit-project-audit`')" 'shared-context'
in_text "AT-FU-5: README discover section treats a missing shared-context.md as empty" "$(section "$README" '### `buildit-feature-discover`' | normalize)" 'Reads `shared-context.md` (a missing file is treated as empty)'
LE_TPL=$(grep -F -- '[optional — one line written by a phase that stops deliberately' <<<"$TRACKING" || true)
in_text "AT-R12b: Last error is cleared only by feature-run" "$LE_TPL" 'cleared only by `buildit-feature-run` before each phase'
absent_in_text "AT-R12b: Last error is no longer cleared by phases" "$LE_TPL" 'when build or validate starts|ship step 0'

BOOT=$(section "$README" '### `buildit-project-bootstrap`' '---')
in_text "AT-R15: bootstrap section documents base branch detection (4f)" "$BOOT" 'origin/HEAD'
RUN_R=$(section "$README" '### `buildit-feature-run`' '---')
in_text "AT-R16: run section says start writes the Merge readiness row (run step 2)" "$(normalize <<<"$RUN_R")" 'writes nothing to `.scratch/shared-context.md` before start'
in_text "AT-R16: run section documents ship verification" "$RUN_R" 'Unexpected state after ship'
in_text "AT-R17: validate NO-GO says 5a stages its config edits" "$(normalize <<<"$VALIDATE")" 'stages each touched file'
WT=$(section "$README" '### `buildit-worktree`' '---')
in_text "AT-R18: worktree section says tests run in the worktree" "$(normalize <<<"$WT")" 'run the test command with the worktree as working directory'
DISCOVER_END=$(grep -F '**Ends with:**' <<<"$DISCOVER" || true)
absent_in_text "AT-R19: discover Ends with uses no [feature-name] placeholder" "$DISCOVER_END" '\[feature-name\]'
in_text "AT-R20: Running tests mentions the cross-skill contract test" "$TESTS" 'tests/test-cross-skill-contracts.sh'
in_text "AT-R20: Running tests mentions section-scoped helpers" "$TESTS" 'section'
in_text "AT-R20: Running tests mentions the CI workflow" "$TESTS" '.github/workflows/tests.yml'

# --- Audit 24-11-2026 #27, #28, #30: hygiene ------------------------------------------
if [[ ! -e scripts/test_docs.sh ]]; then ok "AT-R21: dead scripts/test_docs.sh removed"; else fail "AT-R21: scripts/test_docs.sh must be deleted"; fi
CI=".github/workflows/tests.yml"
require_file "$CI"
require_regex "AT-R22: CI runs on push" "$CI" '^[[:space:]]*push:'
require_regex "AT-R22: CI runs on pull_request" "$CI" '^[[:space:]]*pull_request:'
require_text "AT-R22: CI runs the full suite" "$CI" 'bash tests/run-all.sh'
require_regex "AT-R22: CI push limited to main" "$CI" '^[[:space:]]*branches: \[main\]'
require_regex "AT-R22: CI cancels superseded runs" "$CI" '^[[:space:]]*cancel-in-progress: true'
require_regex "AT-R22: CI job has a timeout" "$CI" '^[[:space:]]*timeout-minutes: [0-9]+'
# Design specs and historical reviews were removed: .scratch/done/, guidelines and commits carry the WHY
if [[ ! -e docs/buildit ]]; then ok "AT-R23: docs/buildit/ removed"; else fail "AT-R23: docs/buildit/ must not exist"; fi
require_absent "AT-R23: README references no docs/buildit/ file" "$README" 'docs/buildit/'
require_absent "AT-R23: README has no References section" "$README" '^## References'
# Checks migrated from the deleted scripts/test_docs.sh
require_regex "AT-R24: README title starts with '# buildit'" "$README" '^# buildit'
in_text "AT-R24: --max-cycles default 3 documented" "$RUN_R" 'Default | `--max-cycles 3`'

# --- shared-context.md is local, untracked state (AT-SCL-6) ---
PAR=$(section "$README" '## Parallel coordination' | normalize)
for w in 'local, untracked' 'single machine' 'gitignored'; do in_text "AT-SCL-6: Parallel coordination says '$w'" "$PAR" "$w"; done
absent_in_text "AT-SCL-6: no closing-commit cleanup claim" "$PAR" "Cleanup happens in each feature's closing commit"
in_text "AT-SCL-6: one-time migration note for the untracking merge" "$PAR" 'move it aside before merging'
START_R=$(section "$README" '### `buildit-feature-start`' '---' | normalize)
in_text "AT-SCL-6: start creates shared-context.md from the template when absent" "$START_R" 'Creates `.scratch/shared-context.md` from the 4-section template if absent'
absent_in_text "AT-SCL-6: start no longer points to bootstrap" "$START_R" 'otherwise points to `/buildit-project-bootstrap`'
WTN=$(normalize <<<"$WT")
absent_in_text "AT-SCL-6: worktree paragraph drops the worktree copy removals" "$WTN" "worktree's own copy"
in_text "AT-SCL-6: worktree paragraph says shared-context.md is never committed" "$WTN" '`shared-context.md` is never committed'
in_text "AT-SCL-6: bootstrap section says it gitignores shared-context.md" "$(normalize <<<"$BOOT")" 'gitignores `.scratch/shared-context.md`'
require_absent "AT-SCL-6: README never mentions update-index" "$README" 'update-index'

# AT-R9: each skill heading and each top-level section appears exactly once
# (a duplicated block left two contradicting ship sections in the README)
for d in skills/*/; do
  sk=$(basename "$d")
  n=$(count_outside_fences "$README" "### \`$sk\`")
  if [[ "$n" -eq 1 ]]; then ok "AT-R9: ### \`$sk\` appears once"; else fail "AT-R9: ### \`$sk\` must appear exactly once (found $n)"; fi
done
while IFS= read -r h; do
  n=$(count_outside_fences "$README" "$h")
  if [[ "$n" -eq 1 ]]; then ok "AT-R9: '$h' appears once"; else fail "AT-R9: '$h' must appear exactly once (found $n)"; fi
done < <(lines_outside_fences "$README" '^## ' | sort -u)
n=$(grep -c '^\*\*Manual flow skills\*\*' "$README" || true)
if [[ "$n" -eq 1 ]]; then ok "AT-R9: Manual flow skills block appears once"; else fail "AT-R9: Manual flow skills block must appear exactly once (found $n)"; fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
