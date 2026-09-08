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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
