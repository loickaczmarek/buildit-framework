#!/usr/bin/env bash
# Structural tests for the buildit-feature-run skill.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL="skills/buildit-feature-run/SKILL.md"
DESIGN_SPEC="docs/buildit/specs/2026-09-08-buildit-feature-run-design.md"

# AT-1: Collects worktree/name/desc/ATs before launching any subagent
require_text "AT-1: collects inputs before subagents" "$SKILL" 'Collect'
require_regex "AT-1b: collects worktree info" "$SKILL" '(worktree|name|description|acceptance).*(collect|ask|[Bb]efore)|([Cc]ollect|[Aa]sk|[Bb]efore).*(worktree|name|description|acceptance)'

# AT-2: Each phase (start, build, validate, ship) runs in a subagent
require_regex "AT-2: start phase in subagent" "$SKILL" 'subagent.*start|start.*subagent'
require_regex "AT-2b: build phase in subagent" "$SKILL" 'subagent.*build|build.*subagent'
require_regex "AT-2c: validate phase in subagent" "$SKILL" 'subagent.*validate|validate.*subagent'
require_regex "AT-2d: ship phase in subagent" "$SKILL" 'subagent.*ship|ship.*subagent'

# AT-3: Reads tracking file status between phases
require_regex "AT-3: reads status between phases" "$SKILL" '([Rr]ead|[Cc]heck|[Ii]nspect).*(status|tracking)|status.*([Rr]ead|[Cc]heck)'

# AT-4: Stops and warns if tracking file not found after start
require_regex "AT-4: halts when tracking file not found" "$SKILL" '(not found|missing).*(stop|warn|abort|halt)|tracking.*(not found|missing)'

# AT-5: Worktree path detected via git worktree list
require_text "AT-5: detects worktree via git worktree list" "$SKILL" 'git worktree list'

# AT-6: --max-cycles N parameter accepted (default 3)
require_text "AT-6: --max-cycles parameter present" "$SKILL" '--max-cycles'
require_regex "AT-6b: default N=3 documented" "$SKILL" '(default|défaut).*(3|N=3)'

# AT-7: On GO + PASS, launches ship and reminds push/PR are manual
require_regex "AT-7: ship launched on GO+PASS" "$SKILL" '(GO|go).*(ship|PASS)'
require_regex "AT-7b: push and PR remain manual" "$SKILL" '(push|PR).*(manual|manuels?)'

# AT-8: Accepts optional feature name passed to subagents
require_regex "AT-8: accepts optional feature name argument" "$SKILL" '\[feature-name\]'

# AT-9: README updated with buildit-feature-run in diagram and skills list
require_text "AT-9: README diagram includes buildit-feature-run" "README.md" 'buildit-feature-run'

# AT-10: Design spec documenting non-obvious choices exists
require_file "$DESIGN_SPEC"

# AT-11: Each subagent prompt block contains autonomy instruction (project directory scope + relative paths)
require_regex "AT-11: autonomy instruction present in subagent prompts" "$SKILL" \
  'project directory.*relative paths|relative paths.*project directory|[Aa]utonomy.*project'

# AT-12: Path-scoping restriction (do not cd outside project root) present in skill
require_regex "AT-12: path-scoping restriction present" "$SKILL" \
  '[Dd]o not cd outside|outside.*project.*permission|paths outside.*require'

# --- Early permission trigger (acceptance tests) ---

# AT-13: The first file-write operation happens before any subagent is launched.
# The early write step must appear between "Collect inputs" (step 1) and the start subagent.
# We verify the skill contains a step that writes to shared-context.md BEFORE the start subagent step.
require_regex "AT-13: early write step exists before start subagent" "$SKILL" \
  '[Ee]arly.*[Ww]rite|[Tt]rigger.*[Ww]rite.*[Pp]ermission|[Pp]ermission.*[Tt]rigger'

# Verify that the early write step references shared-context.md
require_regex "AT-13b: early write targets shared-context.md" "$SKILL" \
  'shared-context\.md'

# Verify structural ordering: the early write step number is between collect inputs and start subagent
# The early write step must be numbered lower than the start subagent step.
# We check that a step heading with "permission" or "early write" appears before the start subagent heading.
EARLY_WRITE_LINE=$(grep -n -iE '###.*([Ee]arly.*[Ww]rite|[Pp]ermission.*[Tt]rigger|[Tt]rigger.*[Pp]ermission)' "$SKILL" 2>/dev/null | head -1 | cut -d: -f1 || true)
START_SUBAGENT_LINE=$(grep -n -iE '###.*[Ss]ubagent.*start|###.*start.*[Ss]ubagent' "$SKILL" 2>/dev/null | head -1 | cut -d: -f1 || true)
if [[ -n "$EARLY_WRITE_LINE" && -n "$START_SUBAGENT_LINE" && "$EARLY_WRITE_LINE" -lt "$START_SUBAGENT_LINE" ]]; then
  ok "AT-13c: early write step appears before start subagent step"
else
  fail "AT-13c: early write step must appear before start subagent step (early=$EARLY_WRITE_LINE, start=$START_SUBAGENT_LINE)"
fi

# AT-14: The early write does not create orphan files (writes to existing file, not a new file)
# The step must explicitly write to an existing file (shared-context.md), not create a new one.
require_regex "AT-14: no orphan files — writes to existing shared-context.md" "$SKILL" \
  '[Rr]ead.*shared-context|shared-context.*[Ee]xist|[Ww]rite.*shared-context|[Mm]erge readiness'

# AT-15: The start subagent prompt includes instruction to skip step 5 (shared-context update)
# to avoid duplicate merge readiness entries.
require_regex "AT-15: start subagent told to skip step 5" "$SKILL" \
  '[Ss]kip.*step 5|[Ss]kip.*shared-context|[Ss]hared-context.*already done|[Ss]tep 5.*skip'

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
