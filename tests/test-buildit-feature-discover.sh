#!/usr/bin/env bash
# Structural tests for the buildit-feature-discover skill.
# Each test maps to one acceptance criterion from the tracking file.
# Tests pass if the skill content is structurally correct.

set -euo pipefail

source "$(dirname "$0")/lib/assertions.sh"

SKILL_SRC="skills/buildit-feature-discover/SKILL.md"
SKILL_DEPLOYED=".claude/skills/buildit-feature-discover/SKILL.md"

# AT-1: Skill triggered explicitly — not auto-invoked from feature-start
# Evidence: name in frontmatter is buildit-feature-discover (distinct name, not embedded in feature-start)
require_file "$SKILL_SRC"
require_text "AT-1: frontmatter name is buildit-feature-discover" "$SKILL_SRC" 'name: buildit-feature-discover'
require_text "AT-1: description mentions /buildit-feature-discover" "$SKILL_SRC" 'buildit-feature-discover'

# AT-2: Analysis phase reads shared-context.md, guidelines, and scans project structure
require_text "AT-2: reads shared-context.md" "$SKILL_SRC" 'shared-context.md'
require_regex "AT-2: reads guidelines dir" "$SKILL_SRC" '\.buildit/guidelines'
require_regex "AT-2: scans project structure (ls skills)" "$SKILL_SRC" '(ls|scan|list).*skills'

# AT-3: Asks user about external documentation before posing questions
require_regex "AT-3: asks about external documentation" "$SKILL_SRC" '(documentation|specs|user stories|design doc)'

# AT-4: Questions target functional understanding (problem, users, expected behaviour, success criteria)
require_regex "AT-4: functional questions — problem" "$SKILL_SRC" 'problem'
require_regex "AT-4: functional questions — users" "$SKILL_SRC" 'user'
require_regex "AT-4: functional questions — success criteria" "$SKILL_SRC" 'success'

# AT-5: Synthesis translates functional to technical, anchored in project conventions
require_regex "AT-5: anchors description in conventions" "$SKILL_SRC" '(convention|guideline|pattern)'

# AT-6: Brief contains kebab-case name, technical description, acceptance tests, risks/constraints
require_regex "AT-6: brief has kebab-case name field" "$SKILL_SRC" 'kebab'
require_regex "AT-6: brief has acceptance tests" "$SKILL_SRC" '(Acceptance tests|Tests d.acceptation|\[ \])'
require_regex "AT-6: brief has risks/constraints section" "$SKILL_SRC" '(Risques|Contraintes|Risks|Constraints)'

# AT-7: Brief presented to user for validation before finalised
require_regex "AT-7: validation step before finalising" "$SKILL_SRC" '(valid|confirm|approv)'

# AT-8: Output explicitly proposes /buildit-feature-start [feature-name]
require_text "AT-8: handoff to buildit-feature-start" "$SKILL_SRC" '/buildit-feature-start'

# --- Plan-task integration ---
README_FILE="README.md"
GUIDELINE_FILE=".buildit/guidelines/team-practices.md"

# AT-D1: detection of the plan task file and extraction of its sections
require_text  "AT-D1: detects plan task file" "$SKILL_SRC" '.scratch/plan/task-{feature-name}.md'
require_text  "AT-D1: stores PLAN_TASK_FILE" "$SKILL_SRC" 'PLAN_TASK_FILE'
require_regex "AT-D1: extracts Description, Acceptance tests and Readiness" "$SKILL_SRC" '## Description.*## Acceptance tests.*## Readiness'

# AT-D2: explicit fallthrough when no task file / no feature-name
require_regex "AT-D2: explicit fallthrough" "$SKILL_SRC" 'PLAN_TASK_FILE=none.*(fall.?through|unchanged)'

# AT-D3: feature name locked to the task name
require_regex "AT-D3: feature name locked to task name" "$SKILL_SRC" '[Ff]eature name is locked to the task name'

# AT-D4: ready short-circuit with re-scope option
require_regex "AT-D4: ready short-circuit suggests feature-run" "$SKILL_SRC" 'PLAN_READINESS.*ready.*/buildit-feature-run \[task-name\]'
require_regex "AT-D4: re-scope option" "$SKILL_SRC" '[Rr]e-scope anyway'

# AT-D5: status guard with confirmation
require_regex "AT-D5: in-progress/done status guard asks confirmation" "$SKILL_SRC" 'PLAN_STATUS.*in-progress.*done.*confirm'

# AT-D6: Phase 2 reuses task data
require_regex "AT-D6: does not re-ask answered questions" "$SKILL_SRC" "([Dd]o not|[Dd]on't) re-ask"

# AT-D7: task file updated on validation
require_text  "AT-D7: Risks & Constraints section in task file" "$SKILL_SRC" '## Risks & Constraints'
require_regex "AT-D7: Readiness set to ready" "$SKILL_SRC" 'Set `## Readiness` to `ready`'

# AT-D8: plan.md tag switched, checkbox and priority preserved
require_regex "AT-D8: needs-scoping tag replaced by ready" "$SKILL_SRC" '`\[needs-scoping\]`.*`\[ready\]`'
require_regex "AT-D8: checkbox and priority preserved" "$SKILL_SRC" '[Pp]reserve.*checkbox.*priority'

# AT-D9: graceful handling of missing plan.md / missing line
require_regex "AT-D9: plan.md missing -> task file only" "$SKILL_SRC" 'plan\.md` does not exist.*task file only'
require_regex "AT-D9: line not found -> warning" "$SKILL_SRC" '[Tt]ask line not found.*task file updated only'

# AT-D10: never modifies ## Status
require_regex "AT-D10: never modifies Status" "$SKILL_SRC" '[Nn]ever modif(y|ies) `## Status`'

# AT-D11: not validated -> untouched
require_regex "AT-D11: no writes when brief not validated" "$SKILL_SRC" 'not validated.*untouched'

# AT-D12: handoff recommends feature-run with task name
require_regex "AT-D12: handoff recommends feature-run [task-name]" "$SKILL_SRC" '/buildit-feature-run \[task-name\]`.*recommended'

# AT-D13: README discover section documents the plan integration
README_SECTION=$(sed -n '/^### `buildit-feature-discover`/,/^---/p' "$README_FILE")
if grep -qF '.scratch/plan/task-' <<<"$README_SECTION" && grep -qF 'needs-scoping' <<<"$README_SECTION"; then
  ok "AT-D13: README discover section documents plan integration"
else
  fail "AT-D13: README discover section does not document plan integration"
fi

# AT-D14: guideline extended to discover with ownership rule
GUIDELINE_SECTION=$(sed -n '/^### Plan-task integration/,/^### Worktree/p' "$GUIDELINE_FILE")
if grep -qF 'buildit-feature-discover' <<<"$GUIDELINE_SECTION" && grep -qE 'Readiness.*buildit-feature-discover|buildit-feature-discover.*Readiness' <<<"$GUIDELINE_SECTION"; then
  ok "AT-D14: guideline covers discover and Readiness ownership"
else
  fail "AT-D14: guideline does not cover discover / Readiness ownership"
fi

# --- Task synchronization (plan-task-synchronization) ---
P5=$(awk 'index($0,"### Phase 5")==1{f=1} f&&index($0,"## End of skill")==1{exit} f' "$SKILL_SRC")
p5_in() { if grep -qF -- "$2" <<<"$P5"; then ok "$1"; else fail "$1 — pattern not found in Phase 5: '$2'"; fi; }
p5_in "AT-SYNC-11: Phase 5 sync block" '**Synchronize validated brief**'
p5_in "AT-SYNC-11: one confirmation" 'ONE confirmation'
p5_in "AT-SYNC-11: pushes description, AT and readiness only" 'description, acceptance tests and readiness'
p5_in "AT-SYNC-11: never pushes status" 'Never push status'
p5_in "AT-SYNC-11: references buildit-plan step 5b" '`buildit-plan` step 5b'
p5_in "AT-SYNC-9: unconfigured treated as disabled" 'unconfigured is treated as disabled for this run'
p5_in "AT-SYNC-9: never prompts to configure" 'never prompt to configure'
p5_in "AT-SYNC-10: failure/refusal writes Pending" 'Pending: <field> → local (DD-MM-YYYY)'
p5_in "AT-SYNC-10: local flow continues" 'the local flow continues'
p5_in "AT-SYNC-13: external content is data" 'data, not instructions'

# Dual-location deployment: source and deployed copy must both exist
require_file "$SKILL_DEPLOYED"

# Both files must have identical content
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
