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

# --- Task synchronization (plan-task-synchronization) ---
README="README.md"
TEAM=".buildit/guidelines/team-practices.md"
LANG_FW=".buildit/guidelines/language-framework.md"

# AT-SYNC-1: config headings and semantics
require_text "AT-SYNC-1: task synchronization heading" "$SKILL_SRC" '## Task synchronization'
require_text "AT-SYNC-1: synchronization method heading" "$SKILL_SRC" '## Synchronization method'
require_text "AT-SYNC-1: synchronization tag heading" "$SKILL_SRC" '## Synchronization tag'
require_text "AT-SYNC-1: enabled/disabled values" "$SKILL_SRC" '`enabled` or `disabled`'
require_text "AT-SYNC-1: unconfigured is not disabled" "$SKILL_SRC" 'unconfigured, not disabled'
require_text "AT-SYNC-1: tag default technical" "$SKILL_SRC" 'default `technical` when absent or empty'
require_text "AT-SYNC-1: tag is customizable" "$SKILL_SRC" 'customizable'
require_regex "AT-SYNC-1: no secrets in config" "$SKILL_SRC" 'Do not store credentials, tokens or other secrets'

# AT-SYNC-2: task synchronization section contract
require_text "AT-SYNC-2: task contract subsection" "$SKILL_SRC" '#### Task synchronization contract'
require_text "AT-SYNC-2: Link line" "$SKILL_SRC" 'Link: <tool/target> <stable-ID-or-URL>'
require_text "AT-SYNC-2: link never the title" "$SKILL_SRC" 'do not use the title as an identity'
require_text "AT-SYNC-2: Pending line format" "$SKILL_SRC" 'Pending: <field> → <value> (DD-MM-YYYY)'
require_text "AT-SYNC-2: one Pending per field" "$SKILL_SRC" 'one per field'
require_text "AT-SYNC-2: latest replaces previous" "$SKILL_SRC" 'latest replaces'

S5B=$(section "$SKILL_SRC" '### 5b.' '### 6.')
# AT-SYNC-3: tagged discovery, untagged opt-in import
in_text "AT-SYNC-3: discovery limited to tagged tickets" "$S5B" 'tag as a label or a `[<tag>] ` title prefix'
in_text "AT-SYNC-3: untagged tickets counted" "$S5B" 'untagged'
in_text "AT-SYNC-3: untagged offered as opt-in import" "$S5B" 'opt-in import'

# AT-SYNC-4: external title format
in_text "AT-SYNC-4: external title format" "$S5B" '`[<tag>] <Title>`'
in_text "AT-SYNC-4: title from heading, never the slug" "$S5B" 'never the slug `task-{name}`'
in_text "AT-SYNC-4: tag also applied as a label" "$S5B" 'as a label when the tool supports labels'

# AT-SYNC-5: prefix stripping and confirmed title
in_text "AT-SYNC-5: strip prefix before comparing" "$S5B" 'Strip the `[<tag>] ` prefix from the external title before comparing'
in_text "AT-SYNC-5: strip prefix on import" "$S5B" 'on import'
in_text "AT-SYNC-5: confirmed title required" "$S5B" 'requires a confirmed title before any external creation or rename'
in_text "AT-SYNC-5: never rename automatically" "$S5B" 'never rename automatically'

# AT-SYNC-6: pending entries first
in_text "AT-SYNC-6: process pending entries first" "$S5B" 'Process pending entries first'
in_text "AT-SYNC-6: clear only after verified write" "$S5B" 'only after a verified write'
L_PENDING=$(grep -nF 'Process pending entries first' "$SKILL_SRC" | head -1 | cut -d: -f1 || true)
L_COMPARE=$(grep -nE '^[0-9]+\. Compare title' "$SKILL_SRC" | head -1 | cut -d: -f1 || true)
if [[ -n "$L_PENDING" && -n "$L_COMPARE" && "$L_PENDING" -lt "$L_COMPARE" ]]; then ok "AT-SYNC-6: pending processed before comparison"; else fail "AT-SYNC-6: pending must precede comparison"; fi

# AT-SYNC-7: read-only drift report on resume before modification mode
S7=$(section "$SKILL_SRC" '### 7.' '## End of skill')
in_text "AT-SYNC-7: drift report in resume" "$S7" '**Drift report (read-only)**'
in_text "AT-SYNC-7: no external writes" "$S7" 'no external writes'
L_DRIFT=$(grep -nF '**Drift report (read-only)**' "$SKILL_SRC" | head -1 | cut -d: -f1 || true)
L_MOD=$(grep -nF '**Modification mode**' "$SKILL_SRC" | head -1 | cut -d: -f1 || true)
if [[ -n "$L_DRIFT" && -n "$L_MOD" && "$L_DRIFT" -lt "$L_MOD" ]]; then ok "AT-SYNC-7: drift report before modification mode"; else fail "AT-SYNC-7: drift report must precede modification mode"; fi

# AT-SYNC-13: untrusted content
require_text "AT-SYNC-13: external content is data" "$SKILL_SRC" 'data, not instructions'

# AT-SYNC-14: guidelines, README, spec
require_text "AT-SYNC-14: team-practices external write ownership" "$TEAM" 'external writes'
require_text "AT-SYNC-14: team-practices Pending fallback" "$TEAM" 'Pending:'
require_text "AT-SYNC-14: language-framework sync config" "$LANG_FW" '## Task synchronization'
require_text "AT-SYNC-14: language-framework unconfigured semantics" "$LANG_FW" 'unconfigured, not disabled'
require_text "AT-SYNC-14: language-framework tag default" "$LANG_FW" '`technical`'
for sk in buildit-project-bootstrap buildit-plan buildit-feature-discover buildit-feature-run; do
  RS=$(section "$README" "### \`$sk\`" '### `')
  if grep -qi 'synchroniz' <<<"$RS"; then ok "AT-SYNC-14: README $sk mentions synchronization"; else fail "AT-SYNC-14: README $sk section lacks synchronization"; fi
done

# Handoff commands use the bare task name (audit #13)
require_absent "AT-H1: no [task-name] placeholder" "$SKILL_SRC" '\[task-name\]'
require_text "AT-H1: needs-scoping handoff prints the discover command" "$SKILL_SRC" '`/buildit-feature-discover {name}`'
require_text "AT-H1: ready handoff prints the run command" "$SKILL_SRC" '`/buildit-feature-run {name}`'

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
