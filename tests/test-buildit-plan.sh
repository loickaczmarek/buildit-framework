#!/usr/bin/env bash
# Structural tests for the buildit-plan skill.
# Each test maps to one acceptance criterion from the tracking file.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL_SRC="skills/buildit-plan/SKILL.md"
SKILL_DEPLOYED=".claude/skills/buildit-plan/SKILL.md"

# AT-1: Accepts any structured document as input (PRD, specs, user stories, bullet points)
require_regex "AT-1: accepts structured documents — PRD" "$SKILL_SRC" 'PRD'
require_regex "AT-1: accepts structured documents — specs" "$SKILL_SRC" '[Ss]pecs'
require_regex "AT-1: accepts structured documents — user stories" "$SKILL_SRC" 'user stories'
require_regex "AT-1: accepts structured documents — bullet points" "$SKILL_SRC" 'bullet points'

# AT-2: Accepts ad-hoc request and flat task list without epic grouping
require_regex "AT-2: accepts ad-hoc requests" "$SKILL_SRC" 'ad-hoc'
require_regex "AT-2: flat task list for few tasks" "$SKILL_SRC" 'flat'
require_regex "AT-2: fewer than 3 tasks threshold" "$SKILL_SRC" 'fewer than 3'

# AT-3: Creates plan.md with source, epic index, progress
require_text "AT-3: plan.md creation" "$SKILL_SRC" 'plan.md'
require_regex "AT-3: source reference in plan" "$SKILL_SRC" '## Source'
require_regex "AT-3: epic index" "$SKILL_SRC" '## Epics'
require_regex "AT-3: progress counters" "$SKILL_SRC" '[Pp]rogress'

# AT-4: Task file structure with status, priority, readiness, needs-scoping
require_regex "AT-4: task file naming" "$SKILL_SRC" 'task-\{name\}'
require_text "AT-4: task status field" "$SKILL_SRC" '## Status'
require_text "AT-4: task priority field" "$SKILL_SRC" '## Priority'
require_text "AT-4: task readiness field" "$SKILL_SRC" '## Readiness'
require_text "AT-4: needs-scoping value" "$SKILL_SRC" 'needs-scoping'

# AT-5: Fast path and coaching path
require_regex "AT-5: fast path offered" "$SKILL_SRC" '[Ff]ast path'
require_regex "AT-5: coaching path offered" "$SKILL_SRC" '[Cc]oaching path'

# AT-6: needs-scoping triggers discover suggestion
require_text "AT-6: needs-scoping triggers discover" "$SKILL_SRC" 'buildit-feature-discover'

# AT-7: Resume detection and coaching mode
require_regex "AT-7: resume detects .scratch/plan/" "$SKILL_SRC" '\.scratch/plan/'
require_regex "AT-7: resume reads existing plan" "$SKILL_SRC" '[Rr]esume'
require_regex "AT-7: coaching mode on resume — ask before modifying" "$SKILL_SRC" 'ask before'

# AT-8: .scratch/done/ cleanup > 7 days with confirmation
require_regex "AT-8: done directory cleanup" "$SKILL_SRC" '\.scratch/done/'
require_regex "AT-8: 7 day threshold" "$SKILL_SRC" '7 day'
require_regex "AT-8: confirmation before deletion" "$SKILL_SRC" 'confirmation'

# AT-9: Completed epic cleanup proposal
require_regex "AT-9: completed epic cleanup" "$SKILL_SRC" 'completed'
require_regex "AT-9: cleanup proposal" "$SKILL_SRC" '(cleanup|[Rr]emov)'

# AT-10: Progress counter sync from task statuses
require_regex "AT-10: progress counters computed from task statuses" "$SKILL_SRC" '(computed|re-sync|recomput)'
require_regex "AT-10: X/Y done counter format" "$SKILL_SRC" 'X/Y done'

# AT-11: Handoff with actionable tasks and next step suggestions
require_regex "AT-11: handoff lists actionable tasks" "$SKILL_SRC" '(handoff|[Nn]ext step|ready for implementation)'
require_text "AT-11: suggests buildit-feature-run" "$SKILL_SRC" 'buildit-feature-run'

# Dual-deployment check: both files must exist and match
require_file "$SKILL_SRC"
require_file "$SKILL_DEPLOYED"

if [[ -f "$SKILL_SRC" && -f "$SKILL_DEPLOYED" ]]; then
  if diff -q "$SKILL_SRC" "$SKILL_DEPLOYED" > /dev/null 2>&1; then
    ok "deployed copy matches source"
  else
    fail "deployed copy differs from source"
  fi
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
